"""Execute private runtime contracts using the exact adapter-emitted helpers."""
import json
from pathlib import Path
import re


def verify_counts(output, corpus, call):
    fixture = (corpus / "LlvmEvaluation/RuntimeCounts.ll").read_text()
    for mode in ["O0", "O3"]:
        metadata = json.loads((output / ("ClassFinalizers-" + mode + ".json")).read_text())
        emitted = (Path(metadata["artifact_directory"]) / "raw.ll").read_text()
        for kind in ["class", "collection"]:
            label = "RuntimeCounts-" + kind + "-" + mode
            folder = output / label
            folder.mkdir(exist_ok=True)
            entry = ("define i32 @main(i32 %argc, ptr %argv) {\nentry:\n"
                     "  %result = call i32 @test_" + kind + "_counts()\n"
                     "  ret i32 %result\n}")
            source, replacements = re.subn(r"define i32 @main\([^\n]*\) \{.*?^}", entry,
                                            emitted, count=1, flags=re.M | re.S)
            assert replacements == 1
            (folder / "raw.ll").write_text(source + "\n" + fixture)
            for stage in metadata["stages"][1:]:
                argv = [str(folder / Path(arg).name) if "/staging-" in arg else arg
                        for arg in stage["argv"]]
                result = call(label + "-" + stage["stage"], argv)
                assert result["returncode"] == 0, result
            result = call(label + "-run", [folder / "program"])
            assert (result["returncode"], result["stdout"], result["stderr"]) == (0, "", ""), result
            print(label, "PASS", flush=True)
