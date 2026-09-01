# Composition and runtime effects

The composer turns the activated modules into one closed portable program.
Runtime effects remain typed operations until the interpreter or a native
backend gives them a concrete implementation.

## Build the closed program

The composer resolves all calls and assigns deterministic `FunctionId`
values before native lowering. The backend receives one portable IR program
and knows nothing about manifests, package paths, or source visibility.

The reference interpreter checks integer arithmetic and is the semantic
oracle for native backends. Differential tests compare its results and
exact observable output, exit status, and runtime diagnostics with generated
native executables on verified hosts.

## Lower output and strings

Text interpolation lowers through one typed value-to-`str` IR operation and
ordinary immutable concatenation. It shares its canonical formatting with
`print` without exposing a formatter or allocation surface.

`print`, `assert`, and `panic` lower as typed effects. Output channels,
platform descriptors, source-location formatting, and the macOS execution
boundary remain privileged compiler details and never enter the source API.

Native strings use an internal descriptor containing an explicit byte length.
Literals and dynamically concatenated values share that representation and
can cross Silex calls without adopting a C ABI, a terminating zero, or a
linker-visible symbol. Dynamic storage is process-lived in this first runtime
model; allocation remains invisible to source code.

Decimal float formatting is a self-contained ARM64 runtime payload built with
the Zig bootstrap and bundled into the compiler. Native emission copies it
only when a program prints a float, patches a direct internal call, and never
resolves a C library or user symbol.

## Select entry points and tests

`main` is the only source name with entry-point semantics. It remains local
to its physical source: the composer retains it only when that exact file is
the explicit entry and excludes every other `main` before semantic analysis
and portable IR construction. `silex run` may discover that exact file from a
directory before composition; this does not make neighboring `main`
declarations visible or change the composer's explicit-entry contract. `main`
is never a public module declaration. Other function names are chosen freely
by the user.

Test blocks are source-local root declarations activated only by `silex test`
for each exact physical source selected directly or through directory
discovery. Their entries and lexical helper functions are removed before
ordinary semantic analysis and portable IR construction; they never enter a
module interface or ordinary executable. On a macos-arm64 host, test
compilation lowers each selected source once and emits an isolated native
process entry for every block, including the active system boundaries.
