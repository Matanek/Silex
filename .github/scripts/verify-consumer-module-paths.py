#!/usr/bin/env python3
"""Exercise sibling imports when a public consumer lives under its dependency."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    compiler = Path(sys.argv[1]).resolve(strict=True)
    workspace = Path(__file__).resolve().parents[2].parent
    os.chdir(workspace)
    with tempfile.TemporaryDirectory(prefix="silex-module-path-", dir=workspace) as temporary:
        library = Path(temporary) / "Library"
        consumer = library / "Tests/Consumer"
        (library / "Module").mkdir(parents=True)
        (consumer / "Tests").mkdir(parents=True)
        (library / "Package.json").write_text(json.dumps({
            "name": "ModulePathProbe", "version": "1.0.0",
            "requires": {"silex": ">=0.48.0"},
        }))
        (library / "Module/Answer.sx").write_text("public func value() int { return 22 }\n")
        (consumer / "Package.json").write_text(json.dumps({
            "sources": "Tests", "dependencies": {"ModulePathProbe": "=1.0.0"},
        }))
        (consumer / "Tests/Helper.sx").write_text("public func answer() int { return 20 }\n")
        entry = consumer / "Tests/Main.sx"
        entry.write_text(
            "use Module.Helper.answer as answer\n"
            "use ModulePathProbe.Answer\n"
            'test "nested consumer keeps sibling imports" { assert(answer() + Answer.value() == 42) }\n'
        )

        def run(arguments):
            result = subprocess.run([str(compiler), *arguments], capture_output=True,
                                    text=True, timeout=120)
            if result.returncode != 0:
                raise RuntimeError(f"{arguments}: {result.returncode}\n{result.stdout}{result.stderr}")
            return result.stdout

        run(["link", str(library), "--workspace", str(consumer)])
        for label, source in (("absolute", str(entry)), ("relative", os.path.relpath(entry))):
            output = run(["test", source, "--nocache"])
            assert "1 passed; 0 failed" in output.splitlines(), output
            print(f"PASS nested consumer imports through {label} entry", flush=True)


if __name__ == "__main__":
    main()
