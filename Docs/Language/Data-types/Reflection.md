# Reflect a value

Use the compiler-provided `reflect` function to obtain source-level metadata
without changing or consuming a value:

```sx
let metadata = reflect(value)
print(metadata.type)
```

`type` is the canonical static type spelling. `name` is the canonical source
declaration represented by the expression: a nominal type, enum variant,
selected member, or named function. An unnamed computed scalar exposes only
`type`; asking for `name` is diagnosed at compile time. For an enum, `name`
contains the active variant:

```sx
enum State {
    waiting
    ready
}

var state = State.waiting
assert(reflect(state).type == "State")
assert(reflect(state).name == "State.waiting")

state = State.ready
assert(reflect(state).name == "State.ready")
```

Names from packages and named modules contain their complete canonical path,
such as `GFX.Animation.Easing.constant`. The implementation-only name of the
entry module, commonly `Main`, is omitted. Local aliases never change that
identity.

A selected member keeps the path of its declaration while `type` describes the
selected value:

```sx
struct Foo { let name:str = "Foo name" }

assert(reflect(Foo().name).name == "Foo.name")
assert(reflect(Foo().name).type == "str")
```

## Inspect enum variants

Enum reflection provides every declared variant name in source order. A
variant carrying payload values still contributes only its name:

```sx
enum Message {
    empty
    text(str)
}

let metadata = reflect(Message.empty)
assert(metadata.variants[0] == "empty")
assert(metadata.variants[1] == "text")
```

## Inspect structures and classes

Structure and class reflection provides the declared fields and instance
methods visible at the call site:

```sx
struct Point {
    let x:float
    let y:float

    func translated(x:float, y:float) Point {
        return Point(x:self.x + x, y:self.y + y)
    }
}

let metadata = reflect(Point(x:1.0, y:2.0))
assert(metadata.fields.count() == 2)
assert(metadata.fields[0] == "x")
assert(metadata.fields[1] == "y")
assert(metadata.methods.count() == 1)
assert(metadata.methods[0] == "translated")
```

Private, protected, package, module, and local visibility continue to apply.
Reflection never reveals a member that ordinary source at the same call site
cannot access. Static members are not part of reflection on an instance.

## Inspect functions

Function reflection exposes the canonical signature, parameter types, and
return type. Borrowed modes remain part of their type spelling:

```sx
func predicate(value:int) bool { return value > 0 }
let metadata = reflect(predicate)

assert(metadata.type == "func(int)bool")
assert(metadata.name == "predicate")
assert(metadata.parameters[0] == "int")
assert(metadata.return_type == "bool")
```

`reflect` evaluates its argument exactly once and does not transfer it. The
compiler emits only the ordinary strings and lists requested by the reflected
category; it does not expose memory addresses, field offsets, machine symbols,
or a stable runtime ABI.
