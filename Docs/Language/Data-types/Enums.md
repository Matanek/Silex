# Represent choices with enums

Declare a closed set of variants:

```sx
enum Connection {
    waiting
    connected(str)
    closed(str)
}

let pending = Connection.waiting()
let active = Connection.connected("server")
```

Construction always uses parentheses, including a variant without payload.

## Read a value with match

```sx
func describe(connection:Connection) str {
    return match connection {
        waiting => "waiting"
        connected(name) => name
        closed(reason) => reason
    }
}
```

Every variant appears exactly once. The subject is evaluated once and is not
consumed. Every branch produces exactly the same type.

Use `else` to deliberately absorb remaining variants:

```sx
let vertical = match direction {
    north => true
    south => true
    else => false
}
```

## Run statements in match branches

```sx
match connection {
    waiting => { print("waiting") }
    connected(name) => { print(name) }
    closed(reason) => { print(reason) }
}
```

Block and expression branches cannot be mixed.

## Attach raw values

```sx
enum Direction:int {
    north = 1
    south = -2
}

let code:int = Direction.north().raw_value
```

A raw enum uses either `int` or `str`. Every variant supplies one unique
literal. Raw enums and their raw types do not convert implicitly.

## Create a generic enum

```sx
enum Outcome<T,E> {
    success(T)
    failure(E)
}

let outcome = Outcome<int,str>.success(42)
```

Every use writes the complete type argument list. Variant construction and
`match` do not infer it.

## Compare enum values

`==` first compares the active variant, then recursively compares every value
associated with that variant. Different variants are unequal. `!=` is the
inverse of `==`.

```sx
Connection.connected("server") == Connection.connected("server")
Connection.waiting() != Connection.closed("timeout")
```

The associated values must themselves be comparable. Structures compare their
fields, while classes compare shared identity. Raw enums also compare their
variant; their `raw_value` remains an explicit representation rather than an
implicit equality conversion.

Enum values copy their active payloads compositionally. When a payload declares
`drop`, each copied enum owns an independent payload value and destroys only
the active variant.
