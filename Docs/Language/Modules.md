# Modules

A module is a logical node in a hierarchy. Files assigned to the same module
share their structures and functions, and directories below it provide its
submodules. A file does not contain a `module` declaration.

When compiling an entry file without a manifest, a directory defines a local
module: `Math/` provides `Math`, and `Math/Geometry/` provides `Math.Geometry`.
A directory remains a module when it contains no direct `.sx` source and only
groups submodules. Only `.sx` files directly inside a directory contribute
declarations to that module.

The distributed library is installed with Silex. Its root modules `std` and
`Silex` are reserved: `std/` provides `std`, `std/Random/` provides its
`std.Random` submodule, and `Silex/Window/` provides `Silex.Window`. Other
distributed modules follow the same path rule: `SDL3/` provides `SDL3`.
Distributed modules work from a single entry file and from a JSON manifest; do
not list reserved modules in a manifest. If a local module and a distributed
module provide the same imported name, compilation fails instead of choosing
one implicitly.

```sx
import Math
import NK.Rendering as Rendering
import std

use std.Random as Random
use std.Random.Generator as Generator
use Math.Vec3

func create() NK.Window.Session {
    let direction:Vec3
    let random:Generator = Random.create(42)
    return Rendering.create_session()
}
```

`import` names a module and makes it available through its full name or alias.
It does not recursively load every submodule. A non-public `use` can name
either one declaration or one submodule and introduce its name or alias into
the current file. It can establish that exact dependency without a preceding
`import`; the longest loaded prefix that names a module is selected. Thus
`use std.Random as Random` introduces a module, while
`use std.Random.Generator as Generator` introduces a structure. An import alias
can also qualify a submodule, as in `import std as Standard` followed by
`use Standard.Random as Random`.

Declarations are private by default. `pub` exposes a structure or function,
while `pub use` re-exports an existing declaration under the current module
name. Modules cannot currently be re-exported with `pub use`.

Duplicate providers, missing modules, dependency cycles, ambiguous aliases, and
access to private declarations are compile-time errors. Dependencies are never
implicitly transitive. A project manifest can define this module layout
explicitly; parent modules of its dotted module names are inferred even when
they have no sources of their own. See
[Installation and command-line use](../Installation.md).

## std.Random

`std.Random` provides a deterministic generator for games, simulations, and
tests. It is not cryptographically secure. `create(seed)` builds a reproducible
generator, while `system()` chooses an initial seed from the host.

```sx
var random = std.Random.create(42)

let raw = random.get_int()
let die = random.get_int(1, 7)
let ratio = random.get_float()
let temperature = random.get_float(-10.0, 40.0)
let enabled = random.get_bool()
```

`get_int()` returns an `int` from `1` through `9223372036854775807`.
`get_int(minimum, maximum)` returns an unbiased `int` in
`[minimum, maximum)` and requires `minimum < maximum` with a positive `int`
width. `get_float()` returns a `float` in `[0.0, 1.0)`; its bounded overload
returns a `float` in `[minimum, maximum)` and requires finite, ordered bounds.
`get_bool()` returns either boolean value. Every call advances only its own
generator. Two generators with the same seed and sequence of calls return the
same sequence of values.

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
