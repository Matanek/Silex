#!/usr/bin/env python3
"""Bound a native CI command and retain live logs, process state and artifacts."""
import argparse
import glob
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time


def preserve(patterns, directory):
    records = []
    directory.mkdir(parents=True, exist_ok=True)
    for pattern in patterns:
        for name in glob.glob(pattern):
            path = Path(name)
            if not path.is_file():
                continue
            try:
                size = path.stat().st_size
                record = {"path": str(path), "bytes": size}
                if size <= 64 * 1024 * 1024:
                    destination = directory / (path.name + "." + str(size))
                    if not destination.exists():
                        temporary = destination.with_name(destination.name + ".copying")
                        try:
                            shutil.copyfile(path, temporary)
                            temporary.replace(destination)
                        finally:
                            temporary.unlink(missing_ok=True)
                    record["copy"] = str(destination)
                records.append(record)
            except OSError as error:
                records.append({"path": str(path), "error": str(error)})
    return records


def processes(pid, powershell):
    if os.name != "nt":
        return {"root_pid": pid, "platform": sys.platform}
    powershell = powershell or str(Path(os.environ["SystemRoot"]) /
                                  "System32/WindowsPowerShell/v1.0/powershell.exe")
    script = r"""
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $items = @(Get-CimInstance Win32_Process)
    $ids = @{@PID@ = $true}
    do {
        $changed = $false
        foreach ($item in $items) {
            if ($ids.ContainsKey([int]$item.ParentProcessId) -and
                -not $ids.ContainsKey([int]$item.ProcessId)) {
                $ids[[int]$item.ProcessId] = $true
                $changed = $true
            }
        }
    } while ($changed)
    @($items | Where-Object { $ids.ContainsKey([int]$_.ProcessId) } |
        Select-Object ProcessId,ParentProcessId,Name,CommandLine,
            UserModeTime,KernelModeTime,WorkingSetSize) |
        ConvertTo-Json -Compress -Depth 4
    """.replace("@PID@", str(pid))
    try:
        result = subprocess.run([powershell, "-NoProfile", "-NonInteractive", "-Command", script],
                                capture_output=True, encoding="utf-8", errors="replace", timeout=10)
        if result.returncode:
            return {"error": result.stderr[-2000:]}
        return json.loads(result.stdout) if result.stdout.strip() else []
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        return {"error": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--artifact-glob", action="append", default=[])
    parser.add_argument("--powershell")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or args.timeout <= 0:
        parser.error("a command and a positive timeout are required")
    args.output.mkdir(parents=True, exist_ok=True)
    log = args.output / "command.log"
    started = time.monotonic()
    print(json.dumps({"begin": args.label, "argv": command,
                      "cwd": str(Path.cwd()), "timeout_seconds": args.timeout}), flush=True)
    timed_out = False
    snapshots = []
    with log.open("wb", buffering=0) as stream, log.open("rb") as reader:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=os.name != "nt")
        next_report = started + 15
        try:
            while True:
                chunk = reader.read()
                if chunk:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                code = process.poll()
                if code is not None:
                    break
                now = time.monotonic()
                if now >= next_report or now - started >= args.timeout:
                    snapshot = {"pending": args.label, "seconds": round(now - started, 3),
                                "processes": processes(process.pid, args.powershell),
                                "artifacts": preserve(args.artifact_glob, args.output / "artifacts")}
                    snapshots.append(snapshot)
                    (args.output / "snapshots.json").write_text(json.dumps(snapshots, indent=2))
                    print(json.dumps(snapshot), flush=True)
                    next_report = time.monotonic() + 15
                if now - started >= args.timeout:
                    timed_out = True
                    break
                time.sleep(.1)
        finally:
            if process.poll() is None:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
            chunk = reader.read()
            if chunk:
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
    report = {"end": args.label, "child_exit_code": process.returncode,
              "timed_out": timed_out, "seconds": round(time.monotonic() - started, 3),
              "artifacts": preserve(args.artifact_glob, args.output / "artifacts")}
    (args.output / "result.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)
    return 124 if timed_out else process.returncode


if __name__ == "__main__":
    sys.exit(main())
