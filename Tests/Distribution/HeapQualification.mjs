import assert from "node:assert/strict";
import { test } from "node:test";
import { checked, median } from "../../Toolchain/Tools/QualifyHeap.mjs";

test("summaries preserve input order and describe all samples", () => {
    const values = [7, 1, 5, 3];
    assert.equal(median(values), 4);
    assert.deepEqual(values, [7, 1, 5, 3]);
    assert.equal(median([8, 3, 1]), 3);
    assert.throws(() => median([]));
});

test("a crash, timeout or failure cannot enter the timing series", () => {
    for (const result of [
        { status: null, signal: "SIGSEGV", stderr: "" },
        { status: null, error: new Error("timeout") },
        { status: 1, stdout: "256000\n", stderr: "assertion failed" },
    ]) assert.throws(() => checked(result, "fixture"));
    assert.equal(checked({ status: 0, stdout: "256000\r\n" }, "fixture"), "256000\n");
});
