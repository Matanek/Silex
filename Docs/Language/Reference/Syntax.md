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
| Constructor | `init(value:type) { ... }` |
| Import | `use Module.Path` |
| Alias | `use Existing.Type as LocalName` |
| Public declaration | `public ...` |
| File-local declaration | `internal ...` |
| Optional | `Type?` |
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

return value
print(value)
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
```

Statements end at a line break, before `}`, or at `;`. Statements on the same
line need `;`.
