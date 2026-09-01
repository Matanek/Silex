# Command-line compilation

The source-compiling commands select an execution or output intention without
changing Silex semantics.

## Run, interpret, and compile

The command `silex run [source.sx|directory]
[-d|--debug|-r|--release] [-n|--nocache]` expresses the intent to execute on
the host. An explicit source remains authoritative. A directory selects its
only direct `.sx` source that declares a root `main`; omitting the operand uses
the current directory. Discovery is non-recursive and gives no preference to
`Main.sx`. Zero candidates and multiple candidates are deterministic errors,
with the ambiguous paths listed so the user can select one explicitly.

Directory discovery resolves to one physical source before project discovery,
cache lookup or compilation. Every later stage therefore retains the existing
explicit-entry contract, including artifact identity, diagnostics, asset
provenance and the source directory used as the child process's working
directory.

`run` emits a private native executable under `.silex/run/`, inherits the
terminal streams, waits for the program and returns its exit code. Release is
the default and applies semantics-preserving optimization; `--debug` disables
those optimizations for backend diagnosis without weakening language safety in
Release. When the child terminates through a signal, the CLI reports its
symbolic name and meaning, source, mode, retained executable, no-cache Debug
reproduction and host debugger command. It identifies native fault owners as
generated code, embedded runtime or package boundary candidates without
selecting one before diagnosis. On `macos-arm64`, every Debug image also
exports address-ordered source symbols carrying the Silex function, physical
`.sx` path, line and column; LLDB therefore resolves native crash frames back
to source even though Release keeps those symbols out of the performance
image.

`silex interpret <source.sx> [-n|--nocache] [--emit-ir]` explicitly selects
the reference interpreter. It is intended for semantic validation and cannot
execute most platform boundaries. `silex compile <source.sx>
[--target <target>] [-d|--debug|-r|--release] [-n|--nocache]
-o|--output <executable>` emits at a caller-selected path without running it.

## Report interactive progress

In an interactive terminal, native compilation reports intention-level
progress through analysis, target preparation, executable construction,
platform linkage, output publication, and launch. The progress channel is
disabled when standard error is not a terminal, preserving quiet successful
execution for scripts and CI. An ANSI-capable terminal clears successful
progress when the operation completes but retains it when compilation fails.

## Trace compiler phases for benchmarks

Compiler benchmarks can set the private `SILEX_COMPILATION_TRACE` environment
variable to an output JSON path. `run` and `compile` then write one structured
report for their native compilation stage. Normal invocations do not allocate a
trace payload, create a report, or print timing data.

The report identifies the command, source, target, mode, compiler version,
current compiler worker count, cache result, success state, total elapsed time,
phase durations, and structural metrics. The native compilation pipeline is
currently serial, so the reported worker count is one. Frontend subphases cover
package resolution, module discovery and
loading, composition, specialization, interface construction, and semantic
analysis. Native phases cover cache validation, program closure, optimization,
lowering, register allocation, emission, linking, output, and cache
publication. The structural metrics report both the complete portable function
count and the reachable portable function count presented to every native
backend.

`frontend_total` contains its frontend subphases, so phase values are not all
additive. Every duration uses a monotonic clock. The compiler report deliberately
does not claim process CPU or peak RSS; the owning benchmark records those from
the process boundary and preserves every raw sample. The JSON schema is private
toolchain data and may evolve with the compiler rather than becoming a public
CLI or IR contract.
