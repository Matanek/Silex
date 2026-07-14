# Modules

A module is a logical namespace. Files assigned to the same module share their
structures and functions. A file does not contain a `module` declaration.

When compiling an entry file without a manifest, a directory defines a local
module: `Math/` provides `Math`, and `Math/Geometry/` provides `Math.Geometry`.
Only `.sx` files directly inside a directory contribute to that module.

The distributed library is installed with Silex. Its `std` and `Silex`
namespaces are reserved: `std/Random/` provides `std.Random`, while
`Silex/Window/` provides `Silex.Window`. Other distributed modules follow the
same path rule: `SDL3/` provides `SDL3`. Distributed modules work from a single
entry file and from a JSON manifest; do not list reserved modules in a
manifest. If a local module and a distributed module provide the same imported
name, compilation fails instead of choosing one implicitly.

```sx
import Math
import NK.Rendering as Rendering
import std.Random
use Math.Vec3

func create() NK.Window.Session {
    let direction:Vec3
    return Rendering.create_session()
}
```

`import` names a module and makes it available through its full name or alias.
`use` names one declaration and introduces its name into the current file; it
can establish the dependency without a preceding `import`. Declarations are
private by default. `pub` exposes a structure or function, while `pub use`
re-exports an existing declaration under the current module namespace.

Duplicate providers, missing modules, dependency cycles, ambiguous aliases, and
access to private declarations are compile-time errors. Dependencies are never
implicitly transitive. A project manifest can define this module layout
explicitly; see [Installation and command-line use](../Installation.md).

## Native module runtime

A distributed module may contain one `native.json` beside its direct `.sx`
sources. Its `common` configuration is combined with the configuration selected
by the requested target triple in `targets`. A missing target entry is an
error. Native sources are listed explicitly under `c`, `cpp`, `objective_c`,
or `objective_cpp`; relative source and include paths must remain inside the
module. Zig compiles C sources with its C driver and C++ sources with its C++
driver, then links their objects with the generated program.

The manifest may also list include directories, string defines, system-library
names, and Apple frameworks. It cannot provide arbitrary compiler flags,
commands, absolute paths, archives, or prebuilt native binaries. A runtime is
compiled once when its module is imported, including through another module.
Its files do not introduce Silex declarations beyond the module's `.sx` API.
