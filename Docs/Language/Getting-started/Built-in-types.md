# Use built-in types

Let Silex infer the type:

```sx
let count = 42
let ratio = 0.5
let ready = true
let title = "Silex"
```

Or write it explicitly:

```sx
let byte:uint8 = 255
let distance:int64 = 42
let precise:float64 = 0.5
let title:str = "Silex"
```

## Built-in types

| Kind | Types |
| --- | --- |
| Signed integer | `int8`, `int16`, `int32`, `int64`, `int` |
| Unsigned integer | `uint8`, `uint16`, `uint32`, `uint64`, `uint` |
| Floating point | `float32`, `float64`, `float` |
| Other values | `bool`, `str` |

`int` is `int64`, `uint` is `uint64`, and `float` is `float32`.

## Intrinsic values

An explicit type may omit its initializer:

```sx
let count:int       // 0
let ratio:float     // 0.0
let ready:bool      // false
let title:str       // ""
let item:Item?      // null
```

Classes have no intrinsic instance. Use a constructor or an optional:

```sx
var player = Player()
var selected:Player? // null
```

## Literals

```sx
let decimal = 1_000
let binary = 0b1010
let octal = 0o12
let hexadecimal = 0xFF
let exponent = 1.5e2
let escaped = "line one\nline two"
let scalar = "\u{1F642}"
```

## Convert a number

```sx
let small:uint8 = value as uint8
```

`as` checks the value at runtime. It fails if the target cannot represent it
without loss.

## Alias a type

```sx
use int as Count
use Geometry.Vector as Vector

let total:Count = 3
```

An alias adds a local name. It does not create a new type.
