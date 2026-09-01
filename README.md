# Silex native compiler experiment

Silex is a native language and compiler experiment.

```sx
func answer() int {
    return 40 + 2
}

func main() {
    print(answer())
}
```

Read the
[public language documentation](https://github.com/Matanek/Silex-Documentation/blob/main/EN/Language/README.md)
to learn the implemented source forms. Compiler contributors can consult the
[compiler architecture](Docs/README.md) for the current compilation path
and its limits.

## Install

The standalone compiler supports macOS on Apple Silicon, Linux x64, and
Windows x64 without requiring Zig or Git on the developer's machine:

```sh
curl -fsSL https://raw.githubusercontent.com/Matanek/Silex/main/install.sh | sh
silex --version
```

On Windows x64, run from PowerShell:

```powershell
irm https://raw.githubusercontent.com/Matanek/Silex/main/install.ps1 | iex
silex --version
```

See the
[installation guide](https://github.com/Matanek/Silex-Documentation/blob/main/EN/Tools/Installation.md)
for checksum verification and custom destinations. Source builds are covered
below in this repository.

Update an installed compiler to the latest verified release with:

```sh
silex update
```

## Build and test

```sh
cd Toolchain
zig build check
zig build test
```

## Run a program

```sh
cd Toolchain
zig build run -- run /path/to/Main.sx
```

Pass an application directory to discover its only direct `.sx` file with a
top-level `main`, or omit the path from inside that directory:

```sh
silex run /path/to/Application
cd /path/to/Application
silex run
```

Discovery is non-recursive and does not prefer the basename `Main.sx`. Pass a
source file explicitly when a directory contains several entry points.

Run the one-time toolchain setup before compiling applications that use native
package boundaries or HLSL:

```sh
silex setup
```

This installs verified, host-specific copies of Shadercross and the private Zig
linker under `~/.silex/toolchain/`. They are implementation details of the
Silex toolchain, not package dependencies. The user does not need a system Zig
installation.

`run` builds a private native executable under `.silex/run/`, executes it with
the current terminal streams and returns its exit code. Release is the default;
pass `--debug` to disable optimization while diagnosing the native backend. Add
`--emit-ir` to inspect the portable typed IR before native lowering:

In an interactive terminal, `compile` and `run` announce the active work:
source and shader analysis, target preparation, executable construction,
platform linkage, output publication, and application launch. Redirected and
CI executions remain quiet on success so their machine-readable output does
not change. On an ANSI-capable terminal, successful progress is erased when
the build finishes; failed progress remains visible above its diagnostic.

If the native process terminates through an operating-system signal, `run`
names and explains the signal, reports the source and build mode, and preserves
the exact executable path. Native faults such as `SIGSEGV` additionally print
a no-cache Debug reproduction command and the host debugger command for that
artifact. The fault may belong to generated code, the embedded runtime, or a
package boundary; the diagnostic does not guess which layer is responsible.

```sh
zig build run -- run /path/to/Main.sx --emit-ir
```

Select the reference interpreter explicitly when validating portable
semantics without a native executable:

```sh
zig build run -- interpret /path/to/Main.sx --emit-ir
```

The interpreter intentionally supports only the few platform boundaries it can
model without reproducing an operating-system runtime. Use `run` for ordinary
programs that depend on STD interop.

## Compile a native program

```sh
cd Toolchain
zig build run -- compile /path/to/Main.sx -d -o /path/to/program
/path/to/program
```

Release is the default and selects the optimized native pipeline. Debug favors
compilation speed and direct backend diagnosis. Every frequent option has a
short and a descriptive form:

```sh
silex compile Main.sx -d -o Application
silex compile Main.sx --debug --output Application
silex compile Main.sx -r -o Application
silex compile Main.sx --release --output Application
```

The commands use a content-addressed compilation cache rooted in
`<current-directory>/.silex/cache`. The root depends on the directory from
which `silex` is invoked, not on the source file's parent. Disable reusable
cache reads and writes for one invocation with `-n` or `--nocache`:

```sh
silex run Sandbox/Main.sx --nocache
silex compile Sandbox/Main.sx -r -n -o Application
```

For `run`, `--nocache` forces a rebuild but the executable still belongs under
`.silex/run/`; cache policy does not change the command's output location.

The cache persists per-module ASTs, the complete native input assembled from
packages and boundaries, and linked Mach-O, ELF or PE executables. Entries are
keyed by exact source and boundary-archive contents, target and compilation
mode. They are validated before use and published atomically, so an unchanged
GPU application can skip Shadercross, native emission and external linkage.
Removing `.silex/cache` is always safe.

Run the reproducible Apple Silicon comparison against an equivalent C++23
workload compiled by `clang++ -O2`:

```sh
zig build benchmark-native
```

The report checks observable output first, then records compiler versions,
binary sizes, compilation times, and execution times under
`.zig-cache/benchmark-native/`.

The native path emits the selected platform's machine instructions and Mach-O,
ELF, or PE executable container. It invokes no C/C++ generator, external
assembler, or linker.

List the exact targets recognized by the current compiler with:

```sh
silex targets
```

The host target is annotated in the output. Runtime code obtains its selected
platform and architecture through the independently versioned `STD.System`
API rather than embedding this compiler-owned list.

## Repository layout

```text
Docs/
  README.md      compiler architecture index
  *.md           implementation contracts organized by subsystem
Toolchain/      autonomous Zig bootstrap project
  Runtime/      target runtime sources bundled at build time
  Sources/      compiler implementation
```

The bootstrap also exposes a minimal editor server with `silex lsp`. The native
backend, ABI, and generated bytes remain experimental.

## License

Silex is licensed under the Apache License 2.0 with LLVM Exceptions
(`Apache-2.0 WITH LLVM-exception`). See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Programs written in Silex are not subject to this license merely because they
are compiled with the Silex toolchain or contain compiler-provided runtime
portions.
