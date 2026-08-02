# Use arrays and lists

## Fixed arrays

```sx
var axes:int[3] = [10, 20, 30]
let empty:int[0] = []

axes[-1] = 40
print(axes.count())
print(axes.is_empty())
```

The length belongs to the type. Negative indexes count from the end. An
out-of-bounds index terminates with a bounds diagnostic.

## Dynamic lists

```sx
var scores:int[] = []
let inferred = [10, 20, 30]

scores = inferred
scores[-1] = 40
```

An empty literal needs an expected type. A non-empty literal infers its element
type from the first value.

## Change a collection

```sx
values.swap(0, 2)
values.reverse()
let previous = values.replace(1, 42)

items.append(item)
items.prepend(item)
items.insert(1, item)
let removed = items.take(0)
items.clear()
```

Arrays and lists support `swap`, `reverse`, and `replace`. Lists also support
`append`, `prepend`, `insert`, `take`, `take_first`, `take_last`, and `clear`.
Every mutating operation requires a `var` receiver.

Fields of stored structures can be changed directly through an index. The
mutation rebuilds the value path inside the collection while preserving the
collection's value semantics:

```sx
vertices[index].position = vertices[index].position.add(offset)
vertices[index].color.a = 0.5
```

Every traversed field must be mutable, and the collection must be reachable
through a mutable binding or mutable reference.

## Copy a slice

```sx
let middle = values[1:4]
```

Both bounds are required. The start is included, the end excluded, and
negative bounds are relative to `count()`. The result is an independent list.

For borrowed slices, see [Views](Views.md).

When elements declare `drop`, every collection copy owns independent element
values. `clear()` destroys them from the last index to the first.
