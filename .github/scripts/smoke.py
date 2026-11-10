#!/usr/bin/env python3
"""Smoke tests for a running ONLYOFFICE Docs container (secure-rebuild).

The same checks run unchanged against every version and edition in
.github/secure-rebuild.json. They rely only on the public contract of Docs:
/healthcheck, the CommandService and ConvertService API, api.js, and the
bundled example (open, save, download). There is no skip: every check either
passes or fails.

Order of checks:
  1. container: example service, supervisor programs
  2. API: editor static files, CommandService, JWT enforcement
  3. ConvertService: content of every result is verified (marker text)
  4. browser (headless Chrome): type into a docx, the save must reach the
     example storage; xlsx, pptx and pdf editors must render a new file
  5. container restart: services come back, the saved document survives,
     the converter works

The container must be started with:
  -e JWT_SECRET=$SMOKE_JWT_SECRET -e ALLOW_PRIVATE_IP_ADDRESS=true
  -e SECURE_LINK_SECRET=<any> --add-host host.docker.internal:host-gateway

Requirements on the runner: python3, docker CLI, pdftotext (poppler-utils),
selenium (pip) and Google Chrome.

Env:
  SMOKE_JWT_SECRET  JWT secret of the container                  (required)
  DS_URL            Docs URL from the runner           (default http://localhost)
  DS_CONTAINER      container name                     (default documentserver)
  SMOKE_FILES_HOST  host name of the runner seen from the container
                                                       (default host.docker.internal)
  SMOKE_ONLY        regex, run only the checks whose name matches
  SMOKE_ARTIFACTS   directory for browser screenshots (empty = no screenshots)
"""
import base64
import hashlib
import hmac
import io
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import threading
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zipfile import ZIP_DEFLATED, ZipFile

DS_URL = os.environ.get("DS_URL", "http://localhost").rstrip("/")
CONTAINER = os.environ.get("DS_CONTAINER", "documentserver")
JWT_SECRET = os.environ.get("SMOKE_JWT_SECRET", "")
FILES_HOST = os.environ.get("SMOKE_FILES_HOST", "host.docker.internal")
SMOKE_ONLY = os.environ.get("SMOKE_ONLY", "")
ARTIFACTS = os.environ.get("SMOKE_ARTIFACTS", "")

CONVERT_TIMEOUT = 180   # seconds per conversion
SAVE_TIMEOUT = 180      # seconds for an edited document to reach the storage
START_TIMEOUT = 300     # seconds for the container to answer the healthcheck

# A unique marker per run: found in a result, it proves the result was produced
# from our source by this run and not taken from a cache or a template.
# Always compared case-insensitively (has_marker): the editor autocorrects the
# first letter of a sentence to upper case.
MARKER = "smoke" + uuid.uuid4().hex[:12]


def has_marker(text):
    return MARKER.lower() in text.lower()

CONVERT_ERRORS = {
    -1: "unknown error", -2: "conversion timeout", -3: "conversion error",
    -4: "could not download the source file", -5: "wrong password",
    -6: "queue/database error", -7: "invalid request parameters",
    -8: "invalid or missing token", -9: "cannot detect the file format",
    -10: "file size/limits exceeded",
}
COMMAND_ERRORS = {
    1: "unknown document key", 2: "callback url error", 3: "internal server error",
    4: "no changes", 5: "unknown command", 6: "invalid token", 7: "token expired",
}

STATE = {}  # data passed between checks (e.g. the name of the saved document)
CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def need(key, producer):
    assert key in STATE, f"depends on '{producer}', which did not pass"
    return STATE[key]


# ------------------------------------------------------------------ helpers

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt(payload, secret):
    header = b64url(b'{"alg":"HS256","typ":"JWT"}')
    body = b64url(json.dumps(payload).encode())
    signature = hmac.new(secret.encode(), f"{header}.{body}".encode(), hashlib.sha256).digest()
    return f"{header}.{body}.{b64url(signature)}"


def http(method, path, payload=None, token="valid", timeout=60):
    """token: "valid" | "none" | "wrong" (signed with another secret)."""
    url = path if path.startswith("http") else DS_URL + path
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Accept", "application/json")
    request.add_header("User-Agent", "docs-smoke-test")
    if data is not None:
        request.add_header("Content-Type", "application/json")
        if token != "none":
            secret = JWT_SECRET if token == "valid" else JWT_SECRET + "-wrong"
            # A token in the header carries the request body as "payload"
            request.add_header("Authorization", "Bearer " + jwt({"payload": payload}, secret))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(), response.geturl()
    except urllib.error.HTTPError as error:
        return error.code, error.read(), url


def get(path, timeout=60):
    return http("GET", path, timeout=timeout)


def docker(*args, timeout=120):
    return subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout)


def wait_until(condition, timeout, interval, what):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            result = condition()
            if result:
                return result
        except Exception as error:  # noqa: BLE001 - keep polling, report the last error
            last = error
        time.sleep(interval)
    raise AssertionError(f"{what}: not done in {timeout}s" + (f" (last error: {last})" if last else ""))


def xml_text(archive_bytes, prefix):
    """Text of all XML parts under prefix in an OOXML/ODF archive, tags stripped."""
    with ZipFile(io.BytesIO(archive_bytes)) as archive:
        parts = [archive.read(name).decode("utf-8", "replace")
                 for name in archive.namelist() if name.startswith(prefix) and name.endswith(".xml")]
    assert parts, f"archive has no XML parts under {prefix!r}"
    return re.sub(r"<[^>]+>", "", "".join(parts))


def pdf_text(content):
    assert content.startswith(b"%PDF-"), f"not a PDF: starts with {content[:8]!r}"
    with tempfile.NamedTemporaryFile(suffix=".pdf") as file:
        file.write(content)
        file.flush()
        result = subprocess.run(["pdftotext", file.name, "-"], check=True,
                                capture_output=True, text=True, timeout=30)
    return " ".join(result.stdout.split())


def assert_marker(text, where):
    assert has_marker(text), f"{where} does not contain the marker {MARKER!r}: {text[:300]!r}"


def png_size(content):
    assert content.startswith(b"\x89PNG\r\n\x1a\n"), f"not a PNG: starts with {content[:8]!r}"
    return struct.unpack(">II", content[16:24])


# ------------------------------------------------------------------ fixtures

CT = "http://schemas.openxmlformats.org/package/2006/content-types"
RELS = "http://schemas.openxmlformats.org/package/2006/relationships"
DOC_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def zip_bytes(parts):
    output = io.BytesIO()
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for name, text in parts.items():
            archive.writestr(name, text)
    return output.getvalue()


def make_docx():
    return zip_bytes({
        "[Content_Types].xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="{CT}">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
        "_rels/.rels": f'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="{RELS}">
<Relationship Id="rId1" Type="{DOC_REL}/officeDocument" Target="word/document.xml"/>
</Relationships>''',
        "word/document.xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body><w:p><w:r><w:t>{MARKER}</w:t></w:r></w:p><w:sectPr/></w:body>
</w:document>''',
    })


def make_xlsx():
    main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    return zip_bytes({
        "[Content_Types].xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="{CT}">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''',
        "_rels/.rels": f'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="{RELS}">
<Relationship Id="rId1" Type="{DOC_REL}/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
        "xl/workbook.xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="{main}" xmlns:r="{DOC_REL}">
<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>''',
        "xl/_rels/workbook.xml.rels": f'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="{RELS}">
<Relationship Id="rId1" Type="{DOC_REL}/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="{DOC_REL}/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId3" Type="{DOC_REL}/styles" Target="styles.xml"/>
</Relationships>''',
        "xl/worksheets/sheet1.xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="{main}">
<cols><col min="1" max="1" width="40" customWidth="1"/></cols>
<sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row></sheetData>
</worksheet>''',
        "xl/sharedStrings.xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="{main}" count="1" uniqueCount="1"><si><t>{MARKER}</t></si></sst>''',
        "xl/styles.xml": f'''<?xml version="1.0" encoding="UTF-8"?>
<styleSheet xmlns="{main}">
<fonts count="1"><font><sz val="11"/><name val="Arial"/></font></fonts>
<fills count="1"><fill><patternFill patternType="none"/></fill></fills>
<borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf/></cellStyleXfs>
<cellXfs count="1"><xf xfId="0"/></cellXfs>
</styleSheet>''',
    })


class FileServer:
    """Serves source files to Docs from the runner (Docs downloads them by URL)."""

    def __init__(self):
        files = self.files = {}

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                content = files.get(self.path)
                if content is None:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)

            def log_message(self, *_args):
                pass

        self.server = ThreadingHTTPServer(("0.0.0.0", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def add(self, name, content):
        path = f"/{uuid.uuid4().hex}/{name}"
        self.files[path] = content
        return f"http://{FILES_HOST}:{self.server.server_port}{path}"


_server = None
_sources = {}


def serve(name, content):
    """Publishes content for Docs; returns the URL Docs downloads it from."""
    global _server
    if _server is None:
        _server = FileServer()
    return _server.add(name, content)


def source(ext):
    """URL of the generated source file of type ext; every file contains MARKER."""
    if ext not in _sources:
        content = {
            "docx": make_docx,
            "xlsx": make_xlsx,
            "csv": lambda: f"{MARKER},1\nsecond,2\n".encode(),
            "txt": lambda: f"{MARKER}\n".encode(),
        }[ext]()
        _sources[ext] = serve(f"smoke.{ext}", content)
    return _sources[ext]


# ------------------------------------------------------------------ API wrappers

def command(payload, token="valid"):
    status, body, _ = http("POST", "/command", payload, token=token)
    assert status == 200, f"/command: HTTP {status}: {body[:300]!r}"
    return json.loads(body)


def convert(url, filetype, outputtype, async_=False, token="valid", **extra):
    """Returns the ConvertService answer; for a successful conversion also the result bytes."""
    payload = {"async": async_, "filetype": filetype, "outputtype": outputtype,
               "key": uuid.uuid4().hex, "title": f"smoke.{filetype}", "url": url, **extra}
    deadline = time.monotonic() + CONVERT_TIMEOUT
    polls = 0
    while True:
        status, body, _ = http("POST", "/converter", payload, token=token, timeout=CONVERT_TIMEOUT)
        assert status == 200, f"/converter: HTTP {status}: {body[:300]!r}"
        data = json.loads(body)
        if "error" in data or token != "valid":
            return data, None
        if data.get("endConvert"):
            break
        assert async_, f"sync conversion returned endConvert=false: {data}"
        assert time.monotonic() < deadline, f"conversion not finished in {CONVERT_TIMEOUT}s: {data}"
        polls += 1
        time.sleep(1)
    status, content, _ = get(data["fileUrl"], timeout=120)
    assert status == 200, f"download of the result: HTTP {status}"
    assert len(content) > 100, f"result is suspiciously small: {len(content)} bytes"
    data["polls"] = polls
    return data, content


def converted(src, filetype, outputtype, **extra):
    data, content = convert(src, filetype, outputtype, **extra)
    assert "error" not in data, \
        f"ConvertService error {data['error']} ({CONVERT_ERRORS.get(data['error'], 'see API docs')})"
    print(f"    {filetype} -> {data.get('fileType') or outputtype}: {len(content)} bytes")
    return data, content


def example_download(file_name):
    status, body, _ = get("/example/download?fileName=" + urllib.parse.quote(file_name), timeout=60)
    assert status == 200 and body, f"example download of {file_name!r}: HTTP {status}"
    return body


def example_new_file(ext):
    """Asks the example to create a new file; returns its name from the redirect URL."""
    status, _, final_url = get(f"/example/editor?fileExt={ext}")
    assert status == 200, f"example editor for {ext}: HTTP {status}"
    names = urllib.parse.parse_qs(urllib.parse.urlparse(final_url).query).get("fileName")
    assert names, f"example did not redirect to a file: {final_url}"
    return names[0]


# ------------------------------------------------------------------ 1. container

FONTS_SPAWN_GRACE = 30   # seconds to watch for the font generator to appear
FONTS_TIMEOUT = 600      # seconds for the font generator to finish


def fonts_generating():
    # [s] keeps the pattern from matching the grep command line itself
    return docker("exec", CONTAINER, "sh", "-c",
                  "grep -qs 'generate-allfont[s]' /proc/[0-9]*/cmdline").returncode == 0


def wait_for_font_generation(grace=FONTS_SPAWN_GRACE, timeout=FONTS_TIMEOUT, interval=2):
    """Waits for the font generator the entrypoint runs in the background; at its end it restarts
    docservice, dropping open editors. Done when the generator was seen and is gone, or when it
    did not appear within `grace` seconds: the entrypoint spawns it right after nginx starts (the
    healthcheck can be green a moment before), so a missing process alone is not "finished"."""
    started = time.monotonic()
    seen = False
    while time.monotonic() - started < timeout:
        if fonts_generating():
            seen = True
        elif seen:
            return f"generator finished after {time.monotonic() - started:.0f}s"
        elif time.monotonic() - started >= grace:
            return f"generator did not run within {grace}s"
        time.sleep(interval)
    raise AssertionError(f"font generation (documentserver-generate-allfonts) not finished in {timeout}s")


@check
def healthcheck():
    """Ready = the healthcheck is green and the font generation of this start is over."""
    wait_until(lambda: get("/healthcheck", timeout=10)[:2] == (200, b"true"),
               START_TIMEOUT, 5, "healthcheck answering true")
    print(f"    fonts: {wait_for_font_generation()}")
    wait_until(lambda: get("/healthcheck", timeout=10)[:2] == (200, b"true"),
               START_TIMEOUT, 5, "healthcheck after the font generation")


@check
def example_service():
    """The example is off by default in the image; the browser checks need it."""
    result = docker("exec", CONTAINER, "supervisorctl", "start", "ds:example")
    output = result.stdout + result.stderr
    assert result.returncode == 0 or "already started" in output, f"supervisorctl: {output.strip()}"
    wait_until(lambda: get("/example/", timeout=10)[0] == 200, 120, 3, "example answering 200")


@check
def supervisor_programs():
    result = docker("exec", CONTAINER, "supervisorctl", "status")
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    assert lines, f"no supervisorctl output: {result.stderr.strip()}"
    states = {line.split()[0]: line.split()[1] for line in lines if len(line.split()) > 1}
    for name, program_state in states.items():
        print(f"    {name}: {program_state}")
    problems = [f"{name} is {states.get(name, 'missing')}"
                for name in ("ds:docservice", "ds:converter", "ds:example")
                if states.get(name) != "RUNNING"]
    problems += [f"{name} is {program_state}" for name, program_state in states.items()
                 if program_state in ("FATAL", "BACKOFF", "EXITED", "UNKNOWN")]
    assert not problems, "; ".join(problems)


# ------------------------------------------------------------------ 2. API

@check
def editor_static_files():
    """What the browser loads: a broken image can give a blank editor with a green healthcheck."""
    expected = {
        "/web-apps/apps/api/documents/api.js": (b"DocsAPI", 1_000),
        "/web-apps/apps/documenteditor/main/index.html": (b"<html", 500),
        "/web-apps/apps/spreadsheeteditor/main/index.html": (b"<html", 500),
        "/web-apps/apps/presentationeditor/main/index.html": (b"<html", 500),
        "/sdkjs/word/sdk-all-min.js": (None, 100_000),
        "/sdkjs/cell/sdk-all-min.js": (None, 100_000),
        "/sdkjs/slide/sdk-all-min.js": (None, 100_000),
        "/sdkjs/common/AllFonts.js": (None, 1_000),
    }
    problems = []
    for path, (marker, min_size) in expected.items():
        status, body, _ = get(path)
        if status != 200:
            problems.append(f"{path}: HTTP {status}")
        elif len(body) < min_size:
            problems.append(f"{path}: only {len(body)} bytes")
        elif marker and marker.lower() not in body[:20_000].lower():
            problems.append(f"{path}: no {marker!r} in the content")
    assert not problems, "; ".join(problems)


@check
def command_unknown_document():
    """Goes through the editor state (Redis, DB) and must answer 'unknown key'."""
    data = command({"c": "info", "key": "smoke-" + uuid.uuid4().hex})
    assert data.get("error") == 1, f"expected error 1 (unknown key), got {data}"


@check
def jwt_command_rejected():
    for token in ("none", "wrong"):
        data = command({"c": "version"}, token=token)
        assert data.get("error") == 6, f"CommandService with token={token}: expected error 6, got {data}"


@check
def jwt_converter_rejected():
    for token in ("none", "wrong"):
        data, _ = convert(source("docx"), "docx", "pdf", token=token)
        assert data.get("error") == -8, f"ConvertService with token={token}: expected error -8, got {data}"


# ------------------------------------------------------------------ 3. ConvertService

@check
def convert_docx_to_pdf():
    _, content = converted(source("docx"), "docx", "pdf")
    assert_marker(pdf_text(content), "PDF")


@check
def convert_docx_to_odt():
    _, content = converted(source("docx"), "docx", "odt")
    assert_marker(xml_text(content, "content.xml"), "ODT")


@check
def convert_docx_to_png_thumbnail():
    _, content = converted(source("docx"), "docx", "png",
                           thumbnail={"aspect": 0, "first": True, "width": 320, "height": 240})
    size = png_size(content)
    assert size == (320, 240), f"thumbnail is {size[0]}x{size[1]}, expected 320x240"


@check
def convert_xlsx_to_pdf():
    _, content = converted(source("xlsx"), "xlsx", "pdf")
    assert_marker(pdf_text(content), "PDF")


@check
def convert_csv_to_xlsx():
    _, content = converted(source("csv"), "csv", "xlsx", codePage=65001, delimiter=4)
    assert_marker(xml_text(content, "xl/"), "XLSX")


@check
def convert_txt_to_docx():
    _, content = converted(source("txt"), "txt", "docx", codePage=65001)
    assert_marker(xml_text(content, "word/"), "DOCX")


@check
def convert_pptx_to_pdf_and_png():
    """The source is a new presentation from the example: a real file, not a hand-made one."""
    pptx = serve("smoke.pptx", example_download(example_new_file("pptx")))
    _, content = converted(pptx, "pptx", "pdf")
    assert content.startswith(b"%PDF-"), f"not a PDF: {content[:8]!r}"
    _, content = converted(pptx, "pptx", "png",
                           thumbnail={"aspect": 0, "first": True, "width": 320, "height": 240})
    assert png_size(content) == (320, 240), "pptx thumbnail has a wrong size"


@check
def convert_async_with_polling():
    data, content = converted(source("docx"), "docx", "pdf", async_=True)
    assert_marker(pdf_text(content), "PDF")
    print(f"    finished after {data['polls']} status poll(s)")


# ------------------------------------------------------------------ 4. browser

LOADED_JS = """
var sdk = document.getElementById('editor_sdk');
var masks = [].filter.call(document.querySelectorAll('.loadmask, .asc-loadmask'),
                           function (m) { return m.offsetParent !== null; });
return document.readyState === 'complete' && !!sdk && !!sdk.querySelector('canvas') && masks.length === 0;
"""


def make_driver():
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
    except ImportError as error:
        raise AssertionError("selenium is not installed (pip install selenium)") from error
    options = Options()
    for argument in ("--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--window-size=1920,1080"):
        options.add_argument(argument)
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    options.set_capability("unhandledPromptBehavior", "accept")
    return webdriver.Chrome(options=options)


def dump_page(driver):
    try:
        print(f"    URL: {driver.current_url}")
        for entry in driver.get_log("browser")[-30:]:
            print(f"    [{entry.get('level')}] {entry.get('message')}")
    except Exception as error:  # noqa: BLE001 - diagnostics must not hide the failure
        print(f"    could not collect browser diagnostics: {error}")


def screenshot(driver, name):
    if not ARTIFACTS:
        return
    os.makedirs(ARTIFACTS, exist_ok=True)
    path = os.path.join(ARTIFACTS, f"{name}.png")
    try:
        driver.save_screenshot(path)
        print(f"    screenshot: {path}")
    except Exception as error:  # noqa: BLE001 - diagnostics must not hide the failure
        print(f"    could not save a screenshot: {error}")


VISIBLE_DIALOGS_JS = """
return [].filter.call(document.querySelectorAll('.asc-window'), function (w) { return w.offsetParent !== null; })
         .map(function (w) { return w.innerText.replace(/\\s+/g, ' ').slice(0, 200); });
"""


def dismiss_dialogs(driver):
    """Closes notices that may cover the editor (e.g. trial or license messages)."""
    from selenium.webdriver.common.by import By
    for _ in range(5):
        buttons = [b for b in driver.find_elements(By.CSS_SELECTOR, "button.dlg-btn[result='ok']") if b.is_displayed()]
        if not buttons:
            break
        text = driver.execute_script(
            "var w = arguments[0].closest('.asc-window'); return w ? w.innerText : '';", buttons[-1])
        print(f"    dismissed dialog: {' '.join((text or '').split())[:200]!r}")
        driver.execute_script("arguments[0].click();", buttons[-1])
        time.sleep(1)
    for text in driver.execute_script(VISIBLE_DIALOGS_JS) or []:
        print(f"    dialog still open: {text!r}")


def open_editor(driver, ext, attempts=3, timeout=60):
    """Opens a new file of ext through the example; returns the file name.
    A stuck editor never recovers on its own, so it is reloaded between attempts."""
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.support.ui import WebDriverWait

    driver.get(f"{DS_URL}/example/editor?fileExt={ext}")
    names = urllib.parse.parse_qs(urllib.parse.urlparse(driver.current_url).query).get("fileName")
    assert names, f"example did not redirect to a file: {driver.current_url}"
    for attempt in range(1, attempts + 1):
        if attempt > 1:
            print(f"    editor not loaded, reload (attempt {attempt})")
            driver.switch_to.default_content()
            driver.refresh()
        WebDriverWait(driver, 60).until(EC.frame_to_be_available_and_switch_to_it((By.TAG_NAME, "iframe")))
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                if driver.execute_script(LOADED_JS):
                    time.sleep(2)
                    dismiss_dialogs(driver)
                    print(f"    {ext} editor loaded: {names[0]}")
                    return names[0]
            except Exception:  # noqa: BLE001 - the frame may be reloading
                pass
            time.sleep(1)
    raise AssertionError(f"{ext} editor did not load in {attempts} attempts of {timeout}s")


def saved_docx_has_marker(name):
    return has_marker(xml_text(example_download(name), "word/"))


@check
def editor_docx_edit_and_save():
    """Types the marker, closes the editor; Docs must save the document to the example storage."""
    driver = make_driver()
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.keys import Keys

    try:
        name = open_editor(driver, "docx")
        driver.find_element(By.ID, "editor_sdk").click()
        time.sleep(10)
        ActionChains(driver).send_keys(MARKER).perform()
        time.sleep(3)
        ActionChains(driver).key_down(Keys.CONTROL).send_keys("s").key_up(Keys.CONTROL).perform()
        time.sleep(5)
        screenshot(driver, "docx-after-typing")
        for text in driver.execute_script(VISIBLE_DIALOGS_JS) or []:
            print(f"    dialog open after typing: {text!r}")

        # Leave the editor the way a user does, so it can flush and disconnect cleanly
        driver.get("about:blank")
        time.sleep(3)
    except Exception:
        dump_page(driver)
        raise
    finally:
        driver.quit()  # the last editor leaves: Docs assembles the file and calls the example back
    try:
        wait_until(lambda: saved_docx_has_marker(name), SAVE_TIMEOUT, 5, f"saved {name} containing the typed text")
    except AssertionError:
        print_container_logs()
        raise
    STATE["saved_docx"] = name


def print_container_logs():
    """The save goes docservice -> callback to the example -> example storage: show both sides."""
    for path in ("/var/log/onlyoffice/documentserver-example/out.log",
                 "/var/log/onlyoffice/documentserver/docservice/out.log"):
        result = docker("exec", CONTAINER, "tail", "-n", "60", path)
        print(f"    === {path} ===")
        for line in (result.stdout or result.stderr).splitlines():
            print(f"    {line}")


def open_only(ext):
    driver = make_driver()
    try:
        open_editor(driver, ext)
    except Exception:
        dump_page(driver)
        raise
    finally:
        driver.quit()


@check
def editor_xlsx_opens():
    open_only("xlsx")


@check
def editor_pptx_opens():
    open_only("pptx")


@check
def editor_pdf_opens():
    open_only("pdf")


# ------------------------------------------------------------------ 5. restart

@check
def container_restart():
    """Restart re-runs the entrypoint on the patched OS: everything must come back."""
    name = need("saved_docx", "editor_docx_edit_and_save")
    result = docker("restart", "-t", "60", CONTAINER, timeout=180)
    assert result.returncode == 0, f"docker restart: {result.stderr.strip()}"
    healthcheck()
    example_service()
    supervisor_programs()
    assert saved_docx_has_marker(name), f"{name} lost the typed text after the restart"
    print(f"    {name} survived the restart")
    _, content = converted(source("docx"), "docx", "pdf")
    assert_marker(pdf_text(content), "PDF after the restart")


# ------------------------------------------------------------------ runner

def main():
    if not JWT_SECRET:
        print("SMOKE_JWT_SECRET is not set", file=sys.stderr)
        return 2
    selected = [fn for fn in CHECKS if not SMOKE_ONLY or re.search(SMOKE_ONLY, fn.__name__)]
    print(f"Docs: {DS_URL}, container: {CONTAINER}, marker: {MARKER}\n", flush=True)
    results = []
    for fn in selected:
        started = time.monotonic()
        print(f"--- {fn.__name__}", flush=True)
        try:
            fn()
            outcome = "PASS"
        except Exception:  # noqa: BLE001 - report every failure and keep going
            outcome = "FAIL"
            traceback.print_exc()
        took = time.monotonic() - started
        results.append((fn.__name__, outcome, took))
        print(f"{outcome} {fn.__name__} ({took:.1f}s)\n", flush=True)

    failed = [name for name, outcome, _ in results if outcome == "FAIL"]
    print(f"{len(results) - len(failed)} passed, {len(failed)} failed")
    for name in failed:
        print(f"  FAIL {name}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as file:
            file.write(f"### Smoke tests ({os.environ.get('SMOKE_TITLE', CONTAINER)})\n"
                       "| check | result | time |\n|---|---|---|\n")
            for name, outcome, took in results:
                icon = "✅" if outcome == "PASS" else "❌"
                file.write(f"| `{name}` | {icon} {outcome} | {took:.1f}s |\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
