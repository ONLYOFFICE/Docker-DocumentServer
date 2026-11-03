#!/usr/bin/env python3
"""Choose one complete published image build for all scenarios in a test run."""

import argparse
import json
import os
from pathlib import Path
import re
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BRANCH = re.compile(r"(?:hotfix|release)/v(\d+\.\d+\.\d+)")
# The producer exposes its package build input here, not in the branch or jobs.
# Edition/platform completeness is checked against successful jobs below.
BUILD_NUMBER = re.compile(r"\bBuild\s*#\s*(\d+)\b", re.IGNORECASE)
EDITION_NAMES = ("community", "enterprise", "developer")


def candidate(run, target_branch=""):
    branch = BRANCH.fullmatch(run.get("head_branch") or "")
    builds = BUILD_NUMBER.findall(run.get("display_title", ""))
    target = BRANCH.fullmatch(target_branch)
    if (not branch or len(builds) != 1 or branch[1] == "99.99.99" or
            run.get("path") != ".github/workflows/4testing-build.yml" or
            run.get("event") != "workflow_dispatch" or run.get("conclusion") != "success" or
            not re.fullmatch(r"[a-f0-9]{40}", run.get("head_sha", "")) or
            (target and branch[1] != target[1])):
        return None
    return {"run": run, "version": f"{branch[1]}-{builds[0]}",
            "numbers": tuple(map(int, branch[1].split("."))) + (int(builds[0]), run["id"])}


def api_pages(repository, path, field, params=None):
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
        raise ValueError("Invalid GitHub mirror repository")
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "Docker-DocumentServer-CI"}
    if os.environ.get("GITHUB_READ_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_READ_TOKEN"]
    page = 1
    while True:
        query = urlencode({**(params or {}), "per_page": 100, "page": page})
        request = Request(f"https://api.github.com/repos/{repository}/{path}?{query}", headers=headers)
        with urlopen(request, timeout=30) as response:
            data = json.load(response)
        yield from data[field]
        if len(data[field]) < 100:
            break
        page += 1


def select_build(repository, target_branch="", pages=api_pages, triggered_run=None):
    if triggered_run is not None:
        # workflow_run uses the default branch as its ref; select the producer's version.
        runs = [triggered_run]
        target_branch = ""
    else:
        runs = pages(repository, "actions/workflows/4testing-build.yml/runs", "workflow_runs",
                     {"event": "workflow_dispatch", "status": "success"})
    candidates = [entry for run in runs if (entry := candidate(run, target_branch))]
    for entry in sorted(candidates, key=lambda item: item["numbers"], reverse=True):
        jobs = list(pages(repository, f"actions/runs/{entry['run']['id']}/jobs", "jobs", {"filter": "latest"}))
        if all(any(job["name"] == f"Build documentserver-{edition}:amd64" and
                   job["conclusion"] == "success" for job in jobs) for edition in EDITION_NAMES):
            return entry
    if triggered_run is not None:
        return None
    raise RuntimeError(f"No complete successful release build found for {target_branch or 'the repository'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--target-branch", default="")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    triggered_run = None
    if os.environ.get("GITHUB_EVENT_NAME") == "workflow_run":
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
        triggered_run = event["workflow_run"]
    selected = select_build(args.repository, args.target_branch, triggered_run=triggered_run)
    if selected is None:
        with args.output.open("a", encoding="utf-8") as stream:
            stream.write("ready=false\n")
        message = "Skipping tests: the triggering build has no complete successful CE/EE/DE AMD64 image set."
        print(message)
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
                stream.write(message + "\n")
        return
    branch, version = selected["run"]["head_branch"], selected["version"]
    with args.output.open("a", encoding="utf-8") as stream:
        stream.write(f"ready=true\npackage_version={version}\n")
    print(f"Branch: {branch}\nPackage version: {version}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(f"| Branch | {branch} |\n|---|---|\n| Package version | {version} |\n")


if __name__ == "__main__":
    main()
