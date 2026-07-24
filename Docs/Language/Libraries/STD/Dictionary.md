# Dictionary

`STD.Collections.Dictionary` provides an encapsulated hash table with value
semantics. Standard `bool`, `int`, `uint`, and `str` keys select the common
hashing and equality overloads automatically:

```sx
use STD.Collections.Dictionary

var ports = Dictionary<str, int>()
ports.insert("http", 80)
ports.insert("https", 443)

var reserved = Dictionary<int, str>(128)
```

The file namespace publishes `Dictionary<Key, Value>` as its principal type
and `STD.Collections.Dictionary.Entry<Key, Value>` as a child declaration, with
constructors, `count`, `capacity`, `is_empty`, `contains_key`, `at`, `insert`,
`remove`, `take_entry`, `reserve`, and `clear`. Keys and values must
be recursively copyable. Copying a dictionary copies its logical state; later
mutations of either copy are independent. Stored function values keep their
captures according to the ordinary function-value rules.

`insert` returns the previous value when an equal key exists and otherwise
returns `null`. It preserves the stored key when replacing a value. `remove`
returns only the value, while `take_entry` returns the stored key and value.
`clear` keeps the allocated capacity available for reuse.

`at` returns `&Value`, the maximum access capability on the stored value, with
provenance on the dictionary. `let value = dictionary.at(key)` infers a shared
`@Value`; `var value = dictionary.at(key)` keeps the mutable `&Value`. It panics
with `Dictionary.at requires an existing key` when the key is absent. Use
`contains_key` when absence is expected. Structural mutation is rejected while
the borrowed result remains live.

The callbacks must obey the usual hash-table contract: equality is an
equivalence relation, equal keys have equal hashes, and a key's hash remains
stable while stored. Violating this contract can make an entry unreachable.
It does not permit an out-of-bounds access or duplicate destruction.

A key type without a standard overload supplies both callbacks explicitly.
The callback-first capacity form remains available for a custom strategy:

```sx
var tokens = Dictionary<Token, int>(hash_token, equal_token)
var reserved_tokens = Dictionary<Token, int>(hash_token, equal_token, 128)
```

The defaults are resolved only when omitted, so these explicit constructions
do not require `Token` to implement any additional protocol.

With reasonably distributed hashes, lookup, insertion, replacement, and
removal are O(1) on average and O(n) in the worst case. Growth is amortized;
`reserve(k)` ensures at least `k` entries fit before the next growth.
`capacity()` reports that entry capacity rather than the raw bucket count.
`iterator()` creates an O(n) owned snapshot of `Entry<Key, Value>` values.
Iteration order is not defined.

Negative capacities passed to the constructor or `reserve` panic. The associated
`STD.Collections.Hashing` publishes overloaded `hash` and `equal` callbacks,
alongside the explicit `hash_*` and `equal_*` names, for `bool`, `int`, `uint`,
and `str`. String hashing uses the UTF-8 bytes; equality is exactly `==`.
