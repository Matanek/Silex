# Declare and change variables

Use `let` for a variable whose value does not change:

```sx
let name = "Ada"
let score:int = 42
```

Use `var` when the variable or a reachable value may change:

```sx
var score = 1
score = 2
score += 3
score++
```

Numeric variables support `+=`, `-=`, `*=`, `/=`, `++`, and `--`.

## Change a field

The root and every field on the path must be mutable:

```sx
struct Position {
    var x:int
    var y:int
}

var position = Position(x:1, y:2)
position.x = 10
```

An intervening `let` makes the rest of that path read-only.

## Shared class values

A binding that can reach a class instance uses `var`:

```sx
var player = Player()
player.damage(10)
```

The variable shows that shared state may change even when the reference itself
is not replaced.

## Scope

Names live inside their lexical block. A local cannot reuse a visible
parameter or local name; separate sibling branches may reuse one.
