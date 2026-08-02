# Syntax quick reference

Use this page to find a spelling. Follow the linked topic for behavior and
constraints.

| Intent | Write |
| --- | --- |
| Immutable variable | `let name:type = value` |
| Mutable variable | `var name:type = value` |
| Function | `func name(value:type) ReturnType { ... }` |
| Structure | `struct Name { ... }` |
| Class | `class Name { ... }` |
| Protocol | `protocol Name { ... }` |
| Extension | `extend Name { ... }` |
| Enum variant | `caseName(Type)` inside `enum` |
| Empty enum value | `Enum.caseName` |
| Enum value with payload | `Enum.caseName(value)` |
| Constructor | `init(value:type) { ... }` |
| Import | `use Module.Path` |
| C function binding | `let name = C.function<func(...) Return>(...)` |
| Alias | `use Existing.Type as LocalName` |
| Public declaration | `public ...` |
| Package-internal declaration | `internal ...` |
| File-local declaration | `local ...` |
| Optional | `Type?` |
| Named tuple | `(width:int, height:int)` |
| Positional tuple | `(int, int)` |
| Borrowed access tuple pattern | `(@Velocity, &Transform)` |
| Tuple destructuring | `let (first, second) = value` |
| Fixed array | `Type[3]` |
| Dynamic list | `Type[]` |
| Shared view | `@Type[..]` |
| Mutable view | `&Type[..]` |
| Read parameter | `value:@Type` |
| Mutable parameter | `value:&Type` |
| Detached copy | `copy value` |
| Transfer | `move value` |
| Checked conversion | `value as Type` |
| Recover success | `try operation()` |
| Critical section | `mutex { ... }` |
| Cascade method | `value..update()` |
| Cascade field assignment | `value..field = replacement` |

The type suffixes `?`, `[]`, and `[N]` apply from left to right, so `Type?[]`
and `Type[]?` are distinct types.

## Statements

```sx
if condition {
} elif other {
} else {
}

while condition {
    break
    continue
}

for value in collection {
}

for value in start...end {
}

mutex {
    update_shared_state()
}

return value
print(value)
assert(condition)
assert(condition, "message")
panic("message")
```

## Operators

From strongest to weakest binding:

```text
as
-  !  try  copy  move
*  /  %
+  -
<<  >>
&
^
<  <=  >  >=
==  !=
&&
||
..method(...)  ..field = value
```

Cascade `..` binds more weakly than the ordinary expression operators. A
single `.` following a cascade method segment resumes ordinary member access
on the resulting receiver. The range token `...` is separate from `..`.

Statements end at a line break, before `}`, or at `;`. Statements on the same
line need `;`.

A `C.function` binding is the only `let` currently accepted at module level.
See [Interop](../Interop.md) for its exact supported signature and lifetime
rules.
