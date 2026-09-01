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
