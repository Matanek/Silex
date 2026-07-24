# Set

`STD.Collections.Set` provides a generic hash set backed by
`STD.Collections.Dictionary`.

```sx
use STD.Collections.Set

var selected = Set<int>()
selected.insert(7)
selected.insert(7)

var reserved = Set<str>(128)
```

`Set<T>` requires recursively copyable elements. `bool`, `int`, `uint`, and
`str` select the overloaded callbacks in `STD.Collections.Hashing`
automatically. A business type supplies both callbacks explicitly, for example
`Set<Token>(hash_token, equal_token)` or
`Set<Token>(hash_token, equal_token, 128)`. Equal values must have equal,
stable hashes, and equality must be an equivalence relation. Explicit
callbacks bypass unavailable defaults without requiring another protocol.

`insert` returns `true` only for a new equivalence class. A duplicate keeps the
first representative rather than replacing it. `remove` reports whether it
removed a value; `take` returns the representative that was actually stored.
`clear` keeps capacity available for reuse.

Copying a set copies its logical state, so later mutations are independent.
Function callbacks retain their ordinary captures. Their presence requires a
direct `var` binding and makes a set non-comparable, but not noncopyable.

`contains`, `insert`, `remove`, and `take` are O(1) on average under a
reasonably distributed hash and O(n) in the worst case. Growth is amortized,
and `reserve(k)` prevents further growth until at least `k` entries fit.
Capacity is an entry capacity, not a bucket count. No iteration order is
defined. `iterator()` creates an O(n) owned snapshot in that unspecified
order. Negative capacities passed to the constructor or `reserve` panic.
