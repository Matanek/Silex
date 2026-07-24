# Queue

`STD.Collections.Queue` provides a generic first-in, first-out value container.

```sx
use STD.Collections.Queue as Queue

var messages = Queue<str>()
messages.enqueue("first")
messages.enqueue("second")
let first = messages.dequeue()
```

`Queue<T>` requires recursively copyable elements. Copying a queue creates an
independent value. `enqueue` is O(1), while `dequeue` and the two `peek`
operations are O(1) amortized; a transfer between the private rear and front
storages can take O(n). `clear` is O(n).

`Queue(minimum_capacity)` and `reserve(minimum_capacity)` reject negative
capacities. `dequeue` returns `null` when empty. `peek` returns `&T` on the
oldest element and panics with `Queue.peek requires a value` when empty. A
`let` result infers `@T` for observation; a `var` result keeps `&T` for
mutation.
`iterator()` creates an O(n) owned snapshot in FIFO order.
