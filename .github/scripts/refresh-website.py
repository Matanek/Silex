#!/usr/bin/env python3
"""Dispatch and await the website deployment; never report a rejected hook as green."""

import json
import os
import re
import subprocess
import sys
import time

REPOSITORY = "Matanek/Silex-Website"


def api(path, *arguments):
    result = subprocess.run(
        ["gh", "api", "-H", "X-GitHub-Api-Version: 2026-03-10", path, *arguments],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def refresh(version, request=api, sleep=time.sleep, clock=time.monotonic):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected a released MAJOR.MINOR.PATCH version")
    response = request(
        f"repos/{REPOSITORY}/actions/workflows/deploy.yml/dispatches",
        "--method", "POST", "-f", "ref=main", "-f", f"inputs[silex_version]={version}",
    )
    run_id = response.get("workflow_run_id")
    if not isinstance(run_id, int) or run_id <= 0:
        raise RuntimeError("GitHub did not return a deployment run ID")
    url = f"https://github.com/{REPOSITORY}/actions/runs/{run_id}"
    print(f"Website deployment: {url}", flush=True)
    deadline = clock() + 15 * 60
    while clock() < deadline:
        run = request(f"repos/{REPOSITORY}/actions/runs/{run_id}")
        if run["status"] == "completed":
            if run["conclusion"] != "success":
                raise RuntimeError(f"Website deployment {run['conclusion']}: {url}")
            print(f"Website deployment verified for Silex {version}: {url}")
            return
        sleep(10)
    raise RuntimeError(f"Website deployment timed out: {url}")


def main():
    if not os.environ.get("GH_TOKEN"):
        raise RuntimeError("WEBSITE_DISPATCH_TOKEN is missing")
    if len(sys.argv) != 2:
        raise ValueError("Usage: refresh-website.py MAJOR.MINOR.PATCH")
    refresh(sys.argv[1])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        # Do not print subprocess environments or credentials.
        print(f"::error::Website refresh failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        print(
            "The compiler release, if already published, remains immutable. "
            "Retry website-refresh.yml after fixing deployment or token access. "
            "The dedicated token needs Actions: write on Matanek/Silex-Website; "
            "no Contents: write permission is required.",
            file=sys.stderr,
        )
        sys.exit(1)
