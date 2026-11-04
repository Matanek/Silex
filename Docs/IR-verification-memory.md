# Bounded temporary storage for IR verification

Optimizer verification borrows the program and returns no owned IR. Each checked
pass therefore owns an independent temporary arena, released before the next
pass. `verify_each_pass` and the set of verified passes keep their policy.

`Ir.validate` uses the same metadata and function formatting checks as
`Ir.writeText`, then reuses scratch between functions. It avoids retaining a
complete textual program when the caller only needs validation. Explicit IR
output still uses `writeText` and preserves its deterministic format. CFG
verification likewise reuses its facts between independent functions. No check
is removed, and the transformation passes and native encoders are unchanged.

## Correctness and resource gates

`zig build test-ir-verification -Dtest-optimize=Debug` covers the verifier's
existing invalid-program diagnostics, deterministic IR text, Debug preparation,
borrowed-IR preservation across repeated checks, and two resource regressions.
Each resource regression validates 8,192 functions with 32 KiB of caller scratch,
one for textual checks and one for CFG facts. This tests storage reuse without
a timing assertion. The complete compiler gates remain required for consumers.

[The local resource record](IR-verification-memory.json) pins the code commit,
compiler hash, guards and the complete UIAccessibility Debug workload on macOS
26.6.2 ARM64. With no worker override, that CLI reaches the 4 GiB guard before
completion. With `SILEX_COMPILATION_WORKERS=1`, the same compiler and source inputs
complete compilation and the exact headless CPU check at 2,760 MiB maximum
observed group RSS. Both configurations have one recorded attempt; cache warmth
was not controlled. No timing ratio or general memory bound follows.

From the workspace root, reproduce the qualified configuration with:

```sh
SILEX_COMPILATION_WORKERS=1 silex compile Silex-Examples/Sources/UIAccessibility/Main.sx --debug --output /tmp/ui-accessibility-debug
/tmp/ui-accessibility-debug --cpu-check
```

The check returns two lines of `UIAccessibility CPU : OK`, exit code 0 and empty
stderr, before any window opens. The compiler passes `check` (50/50 steps,
1,764 internal tests) and `test` (42/42 steps, 1,229 internal tests), with 293
Silex scenarios in 115 files at each gate. These totals overlap. Native test
output, intentional failure and continuation retain their separate
[execution-lifetime gate](Native-test-runner.md). No foreign OS execution is
inferred from the compiler or cross-build results.

## Diagnosing resource failures

A progress line can precede several internal phases. A stack sample locates
active work; it does not identify the owner of memory retained by earlier work.
Separate execution location, retained allocator capacity and the tested compiler
configuration. Interrupted probes need observations written durably before the
stop. The relevant ownership question is which information must survive the
operation: validation facts and discarded text do not belong to the generated
program's lifetime.
