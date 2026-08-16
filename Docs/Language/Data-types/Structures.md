# Create value types with structures

```sx
struct Position {
    var x:int
    var y:int = 10
}

let origin = Position()
var cursor = Position(x:2, y:3)
cursor.x = 4
```

Without a custom constructor, fields are named and may appear in any order.
An omitted field uses its declared default, then its type's intrinsic value.

## Copy a structure

```sx
var first = Position(x:1, y:2)
var second = first

second.x = 10
print(first.x) // 1
```

Structures are nominal values. Ordinary assignment copies their fields. A
class field still refers to the same class instance. Use
[`copy`](../Ownership/Copy-and-move.md) when the whole reachable graph must be
detached.

## Add a constructor

```sx
struct Position {
    let x:int
    let y:int

    init(value:int) {
        self.x = value
        self.y = value
    }
}

let point = Position(5)
```

Declaring any `init` closes the named field initializer. Every `let` field
without a default must be initialized once on every normal path.

## Add methods

```sx
struct Counter {
    var value:int

    func increment(amount:int = 1) {
        self.value += amount
    }

    func current() int {
        return self.value
    }
}

var counter = Counter()
counter.increment()
print(counter.current())
```

Silex infers whether a method mutates `self`. A mutating call requires a `var`
receiver.

## Add static members

```sx
struct Position {
    static let origin_x:int = 0
    static let tile_width:int = 32
    static let half_tile:float = Position.tile_width as float * 0.5

    static func origin() Position {
        return Position()
    }
}

let origin = Position.origin()
```

Static members are selected through the complete type name, never an instance.

A static field initializer is evaluated completely at compile time. It may use
intrinsic literals, operators, numeric conversions, immutable static fields,
and functions that the compiler proves compile-time evaluable:

```sx
struct Layout {
    static let width:int = 960
    static let margin:float = 8.0
    static let half_width:float = Layout.extent(Layout.width, Layout.margin)

    static func extent(size:int, margin:float) float {
        let half:float = size as float * 0.5
        return half - margin
    }
}
```

Compile-time functions operate only on intrinsic scalar values, immutable
locals, and other compile-time calls. Initializers cannot read `static var`,
perform effects, allocate runtime resources, or form dependency cycles. This
keeps static initialization deterministic and gives it no runtime cost.

## Nest a type

```sx
public struct Catalog {
    public struct Entry {
        public let value:int
    }
}

let entry = Catalog.Entry(value:42)
```

A nested type does not capture an owner instance.

## Create a generic structure

```sx
struct Pair<T> {
    let first:T
    let second:T
}

let pair = Pair<int>(first:1, second:2)
```

Every use supplies the complete type argument list. `Pair<int>` and
`Pair<str>` are distinct concrete types.

A method of a non-generic structure may declare its own type parameters:

```sx
struct Catalog {
    func identity<T>(value:T) T {
        return value
    }
}
```

## Run cleanup with drop

```sx
struct File {
    let descriptor:int

    drop {
        print("close ", self.descriptor)
    }
}
```

`drop` runs at the deterministic end of every completed, untransferred value.
It does not make the structure non-copyable:

```sx
var first = File(descriptor:1)
var second = first
```

`first` and `second` are two live values, so each runs its own `drop` exactly
once. A structure runs its block before its fields, which are destroyed in
reverse declaration order.

`return`, `break`, `continue`, and `try` propagation clean every scope they
leave. Fatal termination does not promise cleanup.
