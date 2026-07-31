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

The final module segment becomes the local name. `as` chooses another name:

```sx
use Math.Vec3 as Vector

let position = Vector(x:2, y:10, z:5)
```

## Use a principal type

When a public top-level type has the same name as its module's last segment,
the module name is also the type name:

```sx
// Math/Vec3.sx
public struct Vec3 {
    public var x:float
    public var y:float
    public var z:float
}
```

```sx
use Math

let position:Math.Vec3 = Math.Vec3(x:2, y:10, z:5)
```

You do not write `Math.Vec3.Vec3()`.

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
`local` declarations, while `internal` declarations remain available to the
package. Private specialized declarations are accessible only through their
contextual qualifier; public declarations still contribute to the composed
module interface.

This composition never crosses a package boundary. Packages with qualified
names may share a namespace prefix, but they cannot contribute fragments to
the same exact module.

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
public use Geometry.Types.Vector as Vector
public use Geometry.Operations.length as length
```

A public reexport needs an explicit alias. It exposes a declaration, not an
entire module tree.
