# Copy or move values

## Make an ordinary copy

```sx
var first = Position(x:1, y:2)
var second = first
```

Structures, enums, optionals, arrays, and lists copy their values
compositionally. Class references inside them remain shared.

```sx
var foo1 = Foo(value:10, instance:State(value:5))
var foo2 = foo1

foo2.instance.value = 8
print(foo1.instance.value) // 8
```

## Detach the reachable graph

```sx
var foo3 = copy foo1

foo3.instance.value = 12
print(foo1.instance.value) // 8
```

`copy` recursively recreates reached class instances. Repeated references stay
repeated inside the clone, and cycles remain cycles. Constructors are not
called.

The compiler snapshots one coherent logical instant of the graph. Concurrent
Silex mutation is ordered before or after that snapshot; the detached value
cannot mix two source states.

## Transfer a value

```sx
var original = Position(x:1, y:2)
let transferred = move original

original = Position()
```

`move` consumes a complete local or ordinary parameter. The source cannot be
read again until a consumed `var` receives a complete replacement. A consumed
`let` cannot be reinitialized.

The consumed source no longer runs `drop`; the transferred value owns the
remaining cleanup.

Fields, indexed elements, `self`, and temporary expressions are not explicit
move sources.
