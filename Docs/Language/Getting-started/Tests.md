# Test sources

Place related assertions in one test block:

```sx
test "known hash values" {
    assert(md5("hello") == "5d41402abc4b2a76b9719d911017c592")
    assert(sha1("hello") == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
}
```

Run every block in the source:

```sh
silex test Source.sx
```

Pass a directory to discover test blocks recursively:

```sh
silex test Sandbox/STD
```

Only `.sx` files containing a root `test {}` block are selected. Files run in
lexicographic path order, so the report is deterministic. Platform and target
source trees that do not apply to the current host are ignored. A directory
without tests succeeds with a zero-test report.

The block is one test scenario and may contain any number of statements and
assertions. Its first failed assertion stops that block, but the following test
blocks still run. The command exits unsuccessfully when at least one block
fails.

On a `macos-arm64` host, the command composes the active `Module/`,
`Platform/MacOS/`, and `Target/macos-arm64/` fragments and lowers each selected
source once. Every block then runs in its own native process. System APIs are
therefore available, while an assertion failure, panic, or signal remains
isolated from the following scenarios. Native test executables are internal
artifacts under `.silex/test/`. They are reused while the exact source and its
dependencies remain unchanged; `--nocache` forces their regeneration.

Other hosts retain reference-interpreter execution until their native test
runner is connected.

A native test terminated by a signal reports the symbolic signal name, its
meaning, the exact test and source, the retained failing executable, a no-cache
reproduction command and the host debugger command. On `macos-arm64`, Debug
images carry Silex function, `.sx` path, line and column source symbols for
LLDB. A memory, instruction or arithmetic fault is explicitly classified as a
native failure that may belong to generated code, the embedded runtime or a
package boundary; following test blocks still execute.

Test blocks are declarations at the root of a source file. They cannot be
nested in a function, type, extension, or another test. The description is
optional. An anonymous block is reported by its source line:

```sx
test {
    assert(parse("42") == 42)
    assert(parse("0") == 0)
}
```

## Add helpers local to one test

Functions declared inside a test are visible throughout that block and nowhere
else:

```sx
test "UUID round trip" {
    func round_trip(version:UUID.Version) {
        var source = UUID(version)
        var decoded = UUID.parse(source.to_str())

        assert(decoded.to_bytes() == source.to_bytes())
        assert(decoded.to_str() == source.to_str())
    }

    round_trip(UUID.Version.v4)
    round_trip(UUID.Version.v7)
}
```

Local test functions do not capture variables from the test body. Pass values
through parameters instead.

`assert(condition)` uses an implicit failure message. Add a second argument
when the scenario benefits from more context:

```sx
assert(value == 42, "expected the computed answer")
```

Test blocks are parsed but otherwise absent from `run`, `interpret`, and
`compile`: they are not analyzed, exported, added to portable IR, or emitted in
an ordinary executable. For each selected source, `silex test` activates only
the blocks in that exact physical file, not tests in its dependencies.
