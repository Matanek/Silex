# Import modules

A source file contributes to one module derived from its path:

```text
Math/Vec3.sx       -> Math.Vec3
Math.Geometry.sx   -> Math.Geometry
```

Import what the file needs:

```sx
use Math.Vec3
use Math.Operations.add as add
```

Two contextual roots make imports owned by the current package explicit. Given
this application:

```text
Package.json                         (`"sources": "Sources"`)
Sources/Demo/Main.sx
Sources/Demo/Interpolation.sx
```

all three imports below select the single canonical module
`Demo.Interpolation`:

```sx
use Demo.Interpolation.interpolate as canonical_interpolate
use Package.Demo.Interpolation.interpolate as package_interpolate
use Module.Interpolation.interpolate as module_interpolate
```

`Package.` starts at the current package namespace. In an unnamed application,
that is the logical path relative to the manifest's `sources` directory.
Without a manifest, it is the implicit source root selected from the entry
`.sx`; that root remains stable for every module loaded by the run.
`Module.` starts at the physical directory namespace of the source file that
contains the `use`. Neither root can cross into a dependency. A path without
either root keeps its historical meaning: it is already canonical and may name
the current package or a directly accessible dependency.

Inside a named package, `Package.` omits that package's own name. For example,
these imports written inside STD all select the canonical module `STD.UUID`:

```sx
use STD.UUID
use Package.UUID
use Module.UUID // when UUID.sx is beside the importing source
```

Module paths never contain the physical `.sx` extension. The contextual roots
are valid everywhere a qualified module path is valid, including imports,
types and expressions:

```sx
let first:Module.UUID.Value = Module.UUID.create()
let second:Package.UUID.Value = Package.UUID.create()
```

They are not additional module identities, so reaching one provider through
several spellings still compiles it once.

The final module segment becomes the local name. `as` chooses another name:

```sx
use Math.Vec3 as Vector

let position = Vector(x:2, y:10, z:5)
```

`use` is a naming convenience, not a prerequisite for loading a module. A
fully qualified path loads the longest accessible module prefix on demand:

```sx
let position = STD.Math.Vec3(x:2, y:10, z:5)
let device = GFX.GPU.Device()
```

The leading package must be directly accessible from the consuming package.
Qualified access does not bypass package dependencies, target selection or
declaration visibility. It also introduces no local alias, so two packages may
both contain an `ECS` module without colliding.

## Use a principal type

When a public top-level type has the same name as its module's last segment,
the module name is also the type name:

```sx
// STD/Math/Vec3.sx
public struct Vec3 {
    public var x:float
    public var y:float
    public var z:float
}
```

```sx
use STD.Math

let position:Math.Vec3 = Math.Vec3(x:2, y:10, z:5)
```

You do not write `Math.Vec3.Vec3()`.

This principal-type rule also applies to fully qualified paths. If
`STD.Math.Vec3` contains a public `Vec3`, `STD.Math.Vec3()` constructs it
directly.

## Split one module across source atoms

A source file whose name starts with `@` contributes directly to the logical
module represented by its folder. The filename organizes that module
physically; it never creates a module, namespace or import path. `@Module.sx`
is the conventional atom for a module's main declarations or facade, but it
has no distinct semantics:

```text
GFX/Module/@Module.sx                 -> GFX
GFX/Module/GPU/@Module.sx             -> GFX.GPU
GFX/Module/GPU/@Device.sx             -> GFX.GPU (another atom)
GFX/Module/GPU/Device.sx              -> GFX.GPU.Device
Sandbox/MonModule/@Module.sx           -> MonModule (loose project)
```

Importing or qualifying `GFX.GPU` composes both `@Module.sx` and `@Device.sx`.
Neither `GFX.GPU.@Module` nor `GFX.GPU.@Device` is a source path, and language
servers do not offer those physical names as modules. A public `Device`
declaration inside either atom is an ordinary member of `GFX.GPU`.

The atomized module also owns the implementation modules below its folder for
visibility purposes. Consequently, an unqualified declaration in
`GFX/Module/GPU/Device.sx` is available to the other files under `GFX.GPU`,
while remaining unavailable to `GFX.Scene` and to package consumers. The child
paths remain distinct import paths; this ownership does not merge files or
change their module names.

Atoms do not merge lexical scopes. Each one keeps its own `use` declarations
and `local` declarations, while ordinary module-visible declarations are
available across atoms. Diagnostics, tests, definition navigation and asset
paths retain the exact physical source file.

Without a `Package.json`, compiling or editing an atom directly uses the
parent of its folder as the implicit project root. This preserves the folder's
module identity while keeping quick experiments and scripts free of project
configuration. For `Sandbox/Test/@Module.sx`, `Package.` therefore lists direct
children of `Sandbox`, while `Package.Test.` reaches children such as `Display`
inside `Test`.

Every atom follows ordinary declaration and visibility rules. Importing or
qualifying its logical module loads all of its atoms:

```sx
use GFX
use GFX.GPU

let device = GPU.Device()
```

A flat module file and source atoms cannot provide the same logical module
inside one source root. For example, `GPU.sx` and `GPU/@Device.sx` together are
rejected as duplicate representations. A folder may contain any number of
distinct `@Name.sx` atoms; duplicate declarations are rejected instead of
being ordered or overridden. Portable, platform and exact-target roots may
still contribute their corresponding fragments to one logical module under
the existing composition rules.

## Compose package-local module fragments

A named package may use the same relative source path in its portable root and
in the platform or exact-target root selected for the compilation:

```text
Module/Randomizer.sx
Platform/MacOS/Module/Randomizer.sx
Target/macos-arm64/Module/Randomizer.sx
```

These files are fragments of the same logical module, but they do not merge
their lexical scopes. Portable code names a declaration from the selected
platform or exact-target fragment explicitly:

```sx
let handle:Platform.Handle = Platform.open()
let layout:Target.Layout = Target.layout()
```

`Platform` and `Target` are contextual qualifiers derived from the package,
logical module name, and selected compilation target. They require no `use`
declaration and are not exported namespaces. Each file keeps its own `use` and
`local` declarations, while `package` declarations remain available to the
package. Private specialized declarations are accessible only through their
contextual qualifier; public declarations still contribute to the composed
module interface.

This composition normally never crosses a package boundary. Packages with
qualified names may share a namespace prefix, but they cannot contribute
fragments to the same exact module unless the parent package grants exact
`merge: true` permission for the child package's principal module. That narrow
merge composes only public declarations, retains declaration ownership and
rejects every public name collision. Platform and target fragments, deeper
modules and package-private scopes continue to belong to their original
package.

## Combine a module with its child namespace

A module file and modules below the same path form one qualified namespace:

```text
STD/Module/Math.sx       -> STD.Math
STD/Module/Math.Vec3.sx  -> STD.Math.Vec3
```

STD uses dotted filenames so the complete namespace remains visible in one
directory. Other packages may equivalently use `Math/Vec3.sx`; both paths
provide `Math.Vec3`.

One import exposes both parts on demand:

```sx
use STD.Math

let angle = Math.cos(0.0)
let position = Math.Vec3(x:1.0, y:2.0, z:3.0)
```

A public declaration or public reexport explicitly named in `Math.sx` takes
precedence over a child module with the same name. Private declarations do not
hide public child modules from callers.

## Reexport a declaration

```sx
public use Geometry.Types.Vector
public use Geometry.Operations.length
public use Geometry.Operations.distance as measure
```

A public reexport uses the declaration's current name by default. Add `as`
only when the public API intentionally chooses another name. A reexport exposes
one declaration, not an entire module tree.

When a module contains a public declaration with the same name as its final
segment, the repeated declaration name may be omitted:

```sx
// Rendering.Renderer.sx declares `public class Renderer`.
public use Rendering.Renderer
```

This is equivalent to `public use Rendering.Renderer.Renderer`. It reexports
only the homonymous `Renderer` declaration, not the `Rendering.Renderer` module
tree.

## Contribute to a package umbrella

A qualified child package can add its own public declarations to an umbrella
catalog explicitly opened by its parent. Contributions belong in a portable
atom of the child package's principal module. The conventional location is
`Module/@Module.sx`:

```sx
contribute GFX.Components {
    public use GFX.Physics.RigidBody2D.RigidBody2D
}

contribute GFX.Resources {
    public use GFX.Physics.World2D.World2D
}
```

The block accepts only `public use` declarations naming declarations owned by
the contributing package. It cannot contain functions, types, fields,
extensions, executable statements or type aliases. Composition therefore adds
only façade names; it never injects implementation into the parent module.

The parent must list the exact umbrella modules in its authenticated
`Package.json`, and the child must already be authorized by `extensions`.
Contributions are considered only for packages present in the resolved graph.
An alias that collides with an umbrella declaration, another contribution or a
child namespace is rejected rather than ordered or overridden.
