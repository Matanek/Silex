# Stack

`STD.Collections.Stack` provides a generic last-in, first-out value container.

```sx
use STD.Collections.Stack as Stack

var history = Stack<str>()
history.push("first")
history.push("second")
let latest = history.pop()
```

`Stack<T>` requires recursively copyable elements. Copies own independent
storage. `push` is O(1) amortized; `pop`, `peek`, `count`, and `is_empty` are
O(1). `clear` removes values from top to base in O(n).

`Stack(minimum_capacity)` and `reserve(minimum_capacity)` reject negative
capacities. `pop` returns `null` when empty. `peek` returns `&T` on the top and
panics with `Stack.peek requires a value` when empty. A `let` result infers
`@T` for observation; a `var` result keeps `&T` for mutation.
`iterator()` creates an O(n) owned snapshot from the next `pop` toward the
base.
