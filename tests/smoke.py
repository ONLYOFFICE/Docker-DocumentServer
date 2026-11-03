#!/usr/bin/env python3
"""Exercise the public conversion API against a running compose environment."""

import argparse
import base64
import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
from zipfile import ZIP_DEFLATED, ZipFile


def jwt(payload, secret):
    def encode(value):
        return base64.urlsafe_b64encode(value).rstrip(b"=")

    header = encode(b'{"alg":"HS256","typ":"JWT"}')
    body = encode(json.dumps({**payload, "exp": int(time.time()) + 300}).encode())
    message = header + b"." + body
    signature = encode(hmac.new(secret.encode(), message, hashlib.sha256).digest())
    return (message + b"." + signature).decode()


def document(marker):
    output = io.BytesIO()
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", '''<?xml version="1.0"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''')
        archive.writestr("_rels/.rels", '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''')
        archive.writestr("word/document.xml", f'''<?xml version="1.0"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body><w:p><w:r><w:t>{marker}</w:t></w:r></w:p><w:sectPr/></w:body>
</w:document>''')
    return output.getvalue()


class Conversion:
    def __init__(self, url, secret, ca_file=None):
        self.url = url.rstrip("/")
        self.secret = secret
        self.context = ssl.create_default_context(cafile=ca_file)

    def assert_untrusted_ca(self, ca_file):
        # Load the unrelated CA outside the exception handler: an unreadable or
        # malformed fixture must fail, not count as certificate rejection.
        untrusted_context = ssl.create_default_context(cafile=ca_file)
        health_url = self.url + "/healthcheck"
        with urlopen(health_url, context=self.context, timeout=5) as response:
            if response.read(16).strip() != b"true":
                raise RuntimeError("HTTPS healthcheck failed with the trusted CA")
        try:
            with urlopen(health_url, context=untrusted_context, timeout=5):
                pass
        except URLError as error:
            if not isinstance(error.reason, ssl.SSLCertVerificationError):
                raise
            print("HTTPS trusted CA accepted and unrelated CA rejected.", flush=True)
            return
        raise RuntimeError("HTTPS accepted the server certificate with an unrelated CA")

    def request(self, params, secret=None, signed=True):
        body = dict(params)
        if signed:
            body["token"] = jwt(params, self.secret if secret is None else secret)
        request = Request(self.url + "/converter", json.dumps(body).encode(), {
            "Content-Type": "application/json", "Accept": "application/json",
        })
        with urlopen(request, context=self.context, timeout=15) as response:
            return json.load(response)

    def assert_authentication(self, params):
        for label, options in [("missing", {"signed": False}), ("invalid", {"secret": "wrong-secret"})]:
            result = self.request({**params, "key": uuid4().hex}, **options)
            if result.get("error") != -8:
                raise RuntimeError(f"Converter did not reject {label} JWT: {result}")
        print("Missing and invalid JWT rejected.", flush=True)

    def convert(self, params):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            result = self.request(params)
            if result.get("error"):
                raise RuntimeError(f"Conversion failed: {result}")
            if result.get("endConvert") is True and result.get("fileUrl"):
                return result["fileUrl"]
            time.sleep(2)
        raise RuntimeError("Conversion did not finish within 180 seconds")

    def check_pdf(self, url, marker):
        with urlopen(url, context=self.context, timeout=15) as response:
            content = response.read(10 * 1024 * 1024 + 1)
        if not content.startswith(b"%PDF-") or len(content) > 10 * 1024 * 1024:
            raise RuntimeError("Conversion result is not a valid-sized PDF")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "result.pdf"
            path.write_bytes(content)
            result = subprocess.run(
                ["pdftotext", str(path), "-"], check=True, capture_output=True,
                encoding="utf-8", timeout=15,
            )
        if marker not in " ".join(result.stdout.split()):
            raise RuntimeError("Converted PDF does not contain the source document text")
        return hashlib.sha256(content).hexdigest()

    def smoke(self):
        marker = "ONLYOFFICE " + uuid4().hex[:12]
        content = document(marker)
        path = "/" + uuid4().hex + ".docx"
        downloads = []

        class Source(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path != path:
                    self.send_error(404)
                    return
                downloads.append(self.path)
                self.send_response(200)
                self.send_header("Content-Type", "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(("0.0.0.0", 0), Source)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            params = {
                "async": True, "filetype": "docx", "outputtype": "pdf",
                "key": uuid4().hex,
                "url": f"http://host.docker.internal:{server.server_port}{path}",
            }
            self.assert_authentication(params)
            result_url = self.convert(params)
            digest = self.check_pdf(result_url, marker)
            if not downloads:
                raise RuntimeError("Document Server never downloaded the source DOCX")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
        print("DOCX downloaded and converted to PDF with the expected text.", flush=True)
        return {"params": params, "url": result_url, "marker": marker, "sha256": digest}

    def check_saved(self, state, require_cached_conversion=False):
        # The source HTTP server has already stopped, so a lost result cannot be
        # silently regenerated from the fixture after the container restart.
        def check(url):
            if self.check_pdf(url, state["marker"]) != state["sha256"]:
                raise RuntimeError("The saved conversion result changed after restart")

        check(state["url"])
        print("Saved PDF survived the container restart.", flush=True)
        # CE uses an in-memory task database. Only the editions with a persistent
        # database must also retain the API's cached conversion state.
        if require_cached_conversion:
            check(self.convert(state["params"]))
            print("Cached conversion survived the container restart.", flush=True)


def check_metrics(url, prefix):
    target = f"stats.timers.{prefix}coauth.convertservice.count"
    query = urlencode({"target": target, "from": "-5min", "format": "json", "noCache": "1"})
    deadline = time.monotonic() + 120
    last_result = "no data"
    while time.monotonic() < deadline:
        try:
            with urlopen(url.rstrip("/") + "/render?" + query, timeout=5) as response:
                series = json.load(response)
            if not isinstance(series, list) or not all(isinstance(item, dict) for item in series):
                raise ValueError(f"Graphite render response is not a list of series objects: {series!r}")
            for item in series:
                if item.get("target") == target and any(
                    isinstance(value, (int, float)) and value > 0
                    for value, _timestamp in item.get("datapoints", [])
                ):
                    print("Graphite received a metric from the conversion request.", flush=True)
                    return
            last_result = str(series)
        except (URLError, TimeoutError, ValueError) as error:
            last_result = str(error)
        time.sleep(5)
    # Discover a mismatched prefix/namespace without accepting another series as
    # success. A failed diagnostics request must preserve the original failure.
    try:
        with urlopen(url.rstrip("/") + "/metrics/index.json", timeout=5) as response:
            names = json.load(response)
        if not isinstance(names, list):
            raise ValueError("metric index is not a list")
        available = [name for name in names if isinstance(name, str)
                     and (prefix in name or "coauth.convertservice" in name)][:20]
        last_result += f"; available conversion metrics: {available}"
    except (URLError, TimeoutError, ValueError) as error:
        last_result += f"; metric index unavailable: {error}"
    raise RuntimeError(f"Graphite did not receive {target} within 120 seconds: {last_result}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--ca-file")
    parser.add_argument("--untrusted-ca-file")
    parser.add_argument("--graphite-url")
    parser.add_argument("--metrics-prefix", default="ds.")
    parser.add_argument("--require-cached-conversion", action="store_true")
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--save-state", type=Path)
    state.add_argument("--resume-state", type=Path)
    args = parser.parse_args()
    if args.untrusted_ca_file and (not args.ca_file or not args.url.startswith("https://")):
        parser.error("--untrusted-ca-file requires an HTTPS URL and --ca-file")
    client = Conversion(args.url, os.environ["SMOKE_JWT_SECRET"], args.ca_file)
    if args.untrusted_ca_file:
        client.assert_untrusted_ca(args.untrusted_ca_file)
    if args.resume_state:
        client.check_saved(json.loads(args.resume_state.read_text(encoding="utf-8")), args.require_cached_conversion)
    result = client.smoke()
    if args.save_state:
        args.save_state.write_text(json.dumps(result), encoding="utf-8")
    if args.graphite_url:
        check_metrics(args.graphite_url, args.metrics_prefix)


if __name__ == "__main__":
    main()
