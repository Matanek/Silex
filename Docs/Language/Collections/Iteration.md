# Iterate values

## Read each element

```sx
for value in values {
    print(value)
}
```

The unmarked form borrows a read-only element for that iteration.

## Copy each element

```sx
for let value in values {
    inspect(value)
}
```

Explicit `let` creates an immutable element copy.

## Change stored elements

```sx
for var value in values {
    value += 1
}
```

`for var` writes the final value back before advancing, `continue`, or
`break`. It requires a mutable named collection.

## Read each element with its index

Arrays and lists expose `indexed()` when the zero-origin position is part of
the operation:

```sx
for index, item in values.indexed() {
    print("{index}: {item}")
}
```

The index is an immutable `int`. It starts at `0` and follows collection order.
The element keeps the ordinary loop modes; write `for index, let item` for an
independent copy or `for index, var item` to update the stored element. The
receiver is evaluated once, and empty collections execute no body.

The two-binding form is specific to `indexed()`; it does not destructure an
arbitrary tuple or another loop source.

## Iterate Unicode text

A `str` is traversed directly as Unicode scalar values of type `uint32`:

```sx
for scalar in "A🙂é" {
    print(scalar)
}
```

This visits `65`, `128578`, then `233`, which is consistent with `str.count()`.
Traversal decodes UTF-8 lazily without materializing a list. A scalar is not an
encoded byte and is not necessarily a visible grapheme: use
`STD.Text.UTF8.bytes(text)` for protocol bytes, or `STD.Text.Grapheme` for
user-visible text units. `for var` and direct `indexed()` are unavailable on
`str`; request an explicit STD view when positions are part of the operation.

## Iterate a range

```sx
for i in 0...3 {
    print(i)
}

for i in range(3, 0) {
    print(i)
}
```

Both forms exclude the end. Bounds are evaluated once from left to right.
Equal bounds produce no iteration.

## Iterate an application cursor

Any type with one visible instance method `next() T?` can be used directly as
a `for` source:

```sx
struct TokenCursor {
    var offset:int
    let tokens:Token[]

    func next() Token? {
        if self.offset >= self.tokens.count() { return null }
        let token = self.tokens[self.offset]
        self.offset++
        return token
    }
}

for token in TokenCursor(offset:0, tokens:tokens) {
    analyze(token)
}
```

The source is evaluated once and copied into a private mutable cursor; write
`move cursor` to transfer an existing cursor explicitly. `next()` is called
once per attempt, a present payload runs the body, and `null` ends traversal.
When `next` is overloaded, iterator lookup considers the forms callable without
an explicit argument whose result is `T?`; exactly one must remain.
The unmarked binding borrows the produced value for the body, while `for let`
creates an independent copy. `for var`, `indexed()`, and the two-binding form
are unavailable because a produced value is not mutable collection storage and
the cursor promises neither an index nor a known size.
