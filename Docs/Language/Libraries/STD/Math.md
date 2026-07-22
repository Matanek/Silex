# STD.Math

`STD.Math` provides portable scalar mathematics and value types in `float`,
Silex's alias for `float32`.

```sx
use STD.Math

let diagonal = Math.sqrt(2.0)
let angle = Math.radians(90.0)
let bounded = Math.clamp(1.5, 0.0, 1.0)
let position = Math.Vec3(3.0, 4.0, 0.0)
let direction = position.normalized()
let transform = Math.Mat4.identity()
```

The parent import discovers the child files `Vec2`, `Vec3`, `Vec4`, `Quat`,
`Mat3`, and `Mat4` on demand. A type can instead be imported directly:

```sx
use STD.Math.Vec3 as Vec3
```

## Constants and angles

Silex has no module-level storage, so the scalar constants are functions:

```sx
Math.pi()
Math.half_pi()
Math.two_pi()
Math.epsilon()
```

`epsilon()` returns `0.000001`. `radians(degrees)` and `degrees(radians)`
convert angles using `pi()`.

## Bounds, interpolation and comparison

`min`, `max`, `clamp`, `saturate` and `abs` follow direct `float32`
arithmetic. `saturate(value)` is `clamp(value, 0.0, 1.0)`. `clamp` does not
reject reversed bounds.

`lerp(start, end, amount)` evaluates `start + (end - start) * amount`; `mix` is
an equivalent spelling. Neither function restricts `amount` to `[0, 1]`.

`nearly_equal(left, right)` compares the absolute difference with
`epsilon()`. Its three-argument overload accepts an explicit tolerance.

## Roots and trigonometry

The native scalar operations are:

```sx
Math.sqrt(value)
Math.sin(radians)
Math.cos(radians)
Math.tan(radians)
Math.asin(value)
Math.atan2(y, x)
```

They use the target's C++ mathematical library and preserve Silex `float32`
IEEE-754 behavior. Inputs outside a function's mathematical domain can return
a non-finite value; the module does not wrap them in `Result` or add a panic.
Results are portable within ordinary `float32` tolerances rather than promised
bit-for-bit across every target library.

## Vectors

`Math.Vec2`, `Math.Vec3`, and `Math.Vec4` are copied value types with public
`float` fields. They accept zero, repeated-value, and complete positional
construction. `Vec4` also accepts `(xyz:Vec3, w:float)`.

All three expose `zero`, `one`, `add`, `subtract`, component or scalar
`multiply` and `divide`, `negated`, `dot`, `length_squared`, `length`,
`distance`, `normalized`, `lerp`, `mix`, `minimum`, `maximum`, `clamped`, and
the two `nearly_equal` overloads. `Vec3` adds `cross`; `Vec4` adds `xyz`.
Factories provide the usual unit directions, including `Vec3.front()` as
`(0, 0, -1)` and `Vec3.back()` as `(0, 0, 1)`.

```sx
let normal = Math.Vec3(3.0, 4.0, 0.0).normalized()
let tangent = normal.cross(Math.Vec3.front())
let homogeneous = Math.Vec4(normal, 1.0)
```

Normalizing a vector whose length is at most `Math.epsilon()` returns the zero
vector. Named arithmetic is the stable API while Silex has no operator
overloading.

## Matrices

`Math.Mat3` stores columns `x`, `y`, and `z` as `Vec3`. `Math.Mat4` stores
columns `x`, `y`, `z`, and `w` as `Vec4`. Both use column-major construction
and provide identity, zero, diagonal, and complete column constructors.
`Mat4` additionally accepts a `Mat3`.

Both types expose `row`, `transposed`, `add`, `subtract`, scalar `multiply`,
vector `multiply`, matrix `multiply`, and `inverted`. `Mat3` also exposes
`determinant`. A singular inverse returns the identity when the absolute
determinant is at most `Math.epsilon()`; `row` panics for an out-of-range
index.

`Mat4` supplies `translation`, `scaling`, `rotation`, `transform`,
`perspective`, `orthographic`, and `look_at`. These factories use a right-handed
coordinate system, forward on negative Z, and the OpenGL normalized depth
range `[-1, 1]`.

```sx
let model = Math.Mat4.transform(
    Math.Vec3(4.0, 0.0, 0.0),
    Math.Mat3.identity(),
    Math.Vec3(2.0)
)
let view = Math.Mat4.look_at(Math.Vec3.back(), Math.Vec3.zero(), Math.Vec3.up())
let projection = Math.Mat4.perspective(Math.radians(60.0), 16.0 / 9.0, 0.1, 100.0)
```

## Quaternions

`Math.Quat` stores public `x`, `y`, `z`, and `w` fields. Its zero-argument
constructor and `identity()` produce `(0, 0, 0, 1)`; complete components or a
`Vec3` plus `w` can also construct it.

`angle_axis` creates a rotation. The instance operations are `add`, `subtract`,
quaternion or scalar `multiply`, `conjugated`, `dot`, `length_squared`,
`length`, `normalized`, `inverted`, `rotate`, and `to_mat3`. Normalizing or
inverting a quaternion at or below `Math.epsilon()` returns the identity.

```sx
let rotation = Math.Quat.angle_axis(Math.half_pi(), Math.Vec3.back())
let direction = rotation.rotate(Math.Vec3.right())
let matrix = rotation.to_mat3()
```

## Limits

The module does not currently provide `float64` overloads, logarithms,
exponentials, rounding operations, powers, swizzles, matrix decomposition, or
spherical quaternion interpolation. Invalid projection parameters and other
degenerate divisions follow IEEE-754. No raw matrix pointer is exposed.

[Back to STD](README.md)
