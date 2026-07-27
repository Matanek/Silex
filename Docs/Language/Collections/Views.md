# Borrow collection views

Create a shared view with `@`:

```sx
let middle = @values[1:4]
print(middle[0])
```

Create a mutable view with `&`:

```sx
var middle = &values[1:4]
middle[0] = 42
```

Both bounds are required. The start is included, the end excluded. Negative
bounds are relative to `count()`, then both bounds are clamped to the
collection.

## Accept a view

```sx
func sum(values:@int[..]) int {
    var total = 0
    for value in values {
        total += value
    }
    return total
}
```

## Return a view

```sx
func identity(values:@int[..]) @values:int[..] {
    return values
}
```

A view owns no storage or elements. It may be kept in a lexical binding or
transported through a provenance-qualified borrowed parameter or return.

Shared and mutable views support `count`, `is_empty`, indexing, subviews, and
iteration. Mutable views also support indexed writes, `for var`, and `swap`.
They cannot resize, reorder globally, remove, or transfer elements.

Views cannot be stored in optionals, structures, enums, collections, statics,
or captures. A slice without `@` or `&` remains an independent copied list.
