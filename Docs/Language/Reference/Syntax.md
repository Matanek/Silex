# Syntax quick reference

Use this page to find a spelling. Follow the linked topic for behavior and
constraints.

| Intent | Write |
| --- | --- |
| Immutable variable | `let name:type = value` |
| Mutable variable | `var name:type = value` |
| String | `"text"` |
| Block string | `"` followed by indented lines and a closing `"` on its own line |
| String interpolation | `"value: $(expression)"` |
| Function | `func name(value:type) ReturnType { ... }` |
| Named call | `name(value:expression)` |
| Mixed call | `name(expression, other:expression)` |
| Structure | `struct Name { ... }` |
| Class | `class Name { ... }` |
| Compiler-provided class contract | `intrinsic class Name { ... }` |
| Protocol | `protocol Name { ... }` |
| Extension | `extend Name { ... }` |
| Umbrella contribution | `contribute GFX.Catalog { public use GFX.Child.Type }` |
| Enum variant | `caseName(Type)` inside `enum` |
| Empty enum value | `Enum.caseName` |
| Enum value with payload | `Enum.caseName(value)` |
| Ignored match payload | `caseName(_)` |
| Guarded match branch | `caseName(value) if condition => result` |
| Safe assignment | `optional?.field = value` |
| Forced optional extraction | `optional!` |
| Optional fallback | `optional ?? fallback` |
| Constructor | `init(value:type) { ... }` |
| Canonical import | `use STD.UUID` |
| Current-package import | `use Package.UUID` |
| Current-directory import | `use Module.UUID` |
| Current-package qualified path | `Package.UUID.Value` |
| Current-directory qualified path | `Module.UUID.Value` |
| C function binding | `let name = C.function<func(...) Return>(...)` |
| C function-address call | `C.call<func(...) Return>(address, ...)` |
| Alias | `use Existing.Type as LocalName` |
| Public declaration | `public ...` |
| Package-visible declaration | `package ...` |
| Explicit module-visible declaration | `module ...` |
| File-local declaration | `local ...` |
| Optional | `Type?` |
| Nested optional | `Type??` |
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
| Bound instance method | `receiver.method` |
| Value reflection | `reflect(value)` |
| Cascade field assignment | `value..field = replacement` |

`match` remains a control-flow keyword in expression position, but it is
contextual after `func`, `.`, `?.`, or `..`. It can therefore name and select a
method naturally: `func match(...)` and `pattern.match(text)`.

`in` remains the iteration keyword, but it is contextual as an enum variant
name, in a `match` branch, and after `.` or `?.`: `Easing.in`.

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

for index, value in collection.indexed() {
}

for value in start...end {
}

mutex {
    update_shared_state()
}

{
    let temporary = prepare()
    consume(temporary)
}

return value
print(value)
assert(condition)
assert(condition, "message")
panic("message")
```

A bare block is an anonymous lexical scope, not an expression. It runs once,
has no trailing semicolon, hides its locals after `}`, and cleans them before
normal or transferred control leaves the block. `break` and `continue` still
target the nearest enclosing loop.

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
