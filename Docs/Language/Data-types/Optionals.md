# Represent absence with optionals

Append `?` to a value type:

```sx
let count:int?
let title:str? = "Silex"
var position:Position? = null
```

The value is either `null` or one `T`. A `T` promotes to `T?`; extraction is
never implicit. `null` needs an expected optional type.

## Prove that a local is present

```sx
if position != null {
    print(position.x)
}

if position == null {
    print("missing")
} else {
    print(position.x)
}
```

The proof belongs to that local and branch. Assigning a `var` invalidates the
proof for following statements.

## Bind the payload

```sx
if position = find_position() {
    print(position.x)
}

while var item = next_item() {
    item.advance()
}
```

The unmarked binding is an immutable local. Write `let` explicitly for the
same behavior or `var` for a mutable local copy. The source is evaluated once
per attempt.

## Access a member safely

```sx
let x:int? = profile?.position?.x
position?.translate(3)
```

Each optional step needs its own `?.`. Arguments of a safe method call are
evaluated only when the receiver is present.

A mutating safe call requires an optional `var` place. Safe assignment,
forced extraction, and `??` are not implemented.
