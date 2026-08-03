# Embed files

`embed_text` reads a UTF-8 file while Silex compiles the program and produces
an ordinary `str` stored in the executable:

```sx
let page = embed_text("Web/index.html")
```

The path is relative to the `.sx` source containing the call and must be a
string known at compile time. An immutable `let` bound directly to a literal is
also accepted. Silex records the file as a compilation-cache dependency, so a
content change rebuilds the executable.

The source file is not needed at runtime. `embed_text` accepts text only,
rejects invalid UTF-8, and currently limits one file to 16 MiB. Packages can
interpret the resulting string as HTML, a shader, configuration, or any other
textual format without requiring a package-specific compiler intrinsic.

Use `embed_bytes` when the file is binary or when its exact bytes matter:

```sx
let image:uint8[] = embed_bytes("Web/logo.png")
```

`embed_bytes` accepts arbitrary byte values, including zero and invalid UTF-8,
and returns an ordinary owned `uint8[]`. Each evaluation produces independent
list storage, so normal list mutations do not modify the executable image or
another evaluation. The same relative-path, compile-time, cache-dependency,
and 16 MiB rules apply to both functions.

`embed_text` and `embed_bytes` are reserved language functions and cannot be
redeclared or used as bindings or import aliases.
