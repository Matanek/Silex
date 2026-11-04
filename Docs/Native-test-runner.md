# Native test execution and temporary ownership

The native test runner compiles and lowers the selected cases of one source
into a shared machine program. That program and its source information stay
alive for the file. Emission and linkage scratch belongs to one synchronous
execution, even when several cases share that program.

`NativeTestRunner.executeAt` creates an independent scratch arena, runs emission,
linkage and the child process, then transfers captured stdout/stderr into the
result allocator before releasing scratch. The caller still owns those result
buffers and the executable path. Cache hits, exit status, diagnostics and
retention of signal artifacts preserve their existing contracts. A non-inlined
boundary keeps this scratch owner separate from the CLI dispatcher.

Sharing a program does not require retaining every emitted object and link
argument buffer until its source finishes. The emission body, helpers and
lowering are unchanged by this lifetime boundary; it adds no generated-code
optimization or language feature. The same boundary serves all native targets.
LLVM test execution already has its own per-case arena and is unaffected.

## Correctness gate

`zig build test-case-lifetime-cli` runs the fixture under
`Toolchain/Fixtures/TestCases` as a file and as a directory. Each run must print
native output before, during and after an intentional assertion failure,
continue to the final case and return the exact two-pass/one-failure summary.
The verifier also checks the failure diagnostic and exit code. Both `check`
and `test` depend on this gate. The deliberately failing fixture is outside
the ordinary all-green `Tests` corpus.

## Bounded memory evidence

[The retained resource record](Native-test-runner-memory.json) identifies the
source, compiler hashes, modes, guards and observed RSS of the 26-case public
GFX.UI menu workload on macOS 26.6.2 ARM64. Run source commands from the workspace
root with an explicit entry:

```sh
silex test Packages/GFX.UI/Tests/Consumer/Tests/Menus.sx
```

The baseline reaches the 4 GiB guard before completing. The corrected runner
finishes all 26 cases with 3,586 MiB maximum observed group RSS under the same
limit. Its compiler passes the complete check/test gates and the new output
and continuation verifier. These observations qualify this resource-constrained
workload; they do not establish a general memory bound or a speedup for every
host, source or backend. No timing ratio is inferred from an interrupted run.
