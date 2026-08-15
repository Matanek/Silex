# Represent absence with optionals

Append `?` to a value type:

```sx
let count:int?
let title:str? = "Silex"
var position:Position? = null
```

The value is either `null` or one `T`. A `T` promotes to `T?`; extraction is
never implicit. `null` needs an expected optional type.

Type suffixes compose from left to right. `Position?[]` is a list whose
elements are optional positions, while `Position[]?` is an optional list.
Likewise, `int?[3]` is a fixed array of three optional integers.

Optional suffixes may repeat directly. `T??` means `(T?)?`: `null` initializes
the absent outer layer, promoting `T?` adds one present outer layer, and
promoting `T` makes every layer present. Conditional binding and postfix `!`
remove one layer at a time, so `value!!` is explicit when two layers must be
forced.

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

A mutating safe call requires an optional `var` place.

## Assign through an optional path

```sx
profile?.position?.x = 10
statistics?.accepted += 1
state?.values[index] = value
```

A safe assignment requires a `var` root. It evaluates the path from left to
right and stops without effect at the first absent receiver. Indices and the
right-hand value are evaluated only after every preceding safe segment is
present. Ordinary assignment, compound assignment, `++`, and `--` share this
short-circuit behavior. The statement itself produces no value.

## Force a present value

```sx
let configuration = load_configuration()!
print(configuration.name)
```

Postfix `!` evaluates its operand once and removes exactly one optional layer.
It produces the ordinary payload when present. An absent value stops execution
with a source-localized `forced optional extraction failed` runtime error.
Prefix `!value` remains boolean negation, while `value!` is the explicit
optional assertion.

## Choose a fallback

```sx
let display_name = declaration.alias ?? declaration.name
let port = configured_port() ?? default_port()
```

`??` evaluates its optional left operand once. A present payload is returned
without evaluating the right operand; an absence evaluates the fallback. A
fallback of type `T` produces `T`, while `T? ?? T?` remains optional. The
operator associates to the right and binds less strongly than logical and
arithmetic operators.
