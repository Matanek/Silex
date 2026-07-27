# Import modules

A source file provides one module from its path:

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

## Reexport a declaration

```sx
public use Geometry.Types.Vector as Vector
public use Geometry.Operations.length as length
```

A public reexport needs an explicit alias. It exposes a declaration, not an
entire module tree.
