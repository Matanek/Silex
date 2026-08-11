# Write and call functions

```sx
func add(left:int, right:int) int {
    return left + right
}

func main() {
    print(add(20, 22))
}
```

Omit the return type for `void`:

```sx
func greet(name:str) {
    print("Hello, ", name)
}
```

Calls may be positional or use the parameter names as labels:

```sx
func draw(sprite:Sprite, at:Vec2, opacity:float = 1.0) {
}

draw(hero, position)
draw(at:position, sprite:hero)
draw(hero, opacity:0.8, at:position)
```

Named arguments may appear in any order. A positional prefix may come first,
but no positional argument may follow a named one. Each parameter is supplied
at most once. After labels are associated, argument expressions are evaluated
and passed in declaration order. Calls through function values and callbacks
remain positional.

## Pass functions as callbacks

A function type spells out its parameter modes and return type:

```sx
func any<T>(values:T[], predicate:func(@T) bool) bool {
    for value in values {
        if predicate(value) {
            return true
        }
    }
    return false
}

func positive(value:@int) bool { return value > 0 }

let found = any<int>([-1, 2], positive)
```

Use `func(T)` when the callback returns `void`, and `func(T) Result` for a
value result. Callback parameters retain the ordinary Silex modes: value,
read reference `@`, or mutable reference `&`. Overloaded function names are
resolved from the expected callback signature.

Use an anonymous function when the callback is local to the call:

```sx
let found = any<int>([-1, 2], func(value:@int) bool {
    return value > 0
})
```

Omit the return type when the anonymous function returns `void`:

```sx
func visit(value:int, callback:func(int)) { callback(value) }

visit(42, func(value:int) { print(value) })
```

An anonymous function captures only the outer bindings that it uses. A
captured `var` remains shared: changing it in the anonymous function changes
the variable in the surrounding function, and copies of the function value
refer to the same binding. A captured `let` remains immutable. Nested
anonymous functions may capture a binding from any enclosing lexical level;
intermediate functions carry that context automatically.

```sx
var count = 0
var increment = func() { count += 1 }
var same_increment = increment

increment()
same_increment()
print(count) // 2
```

Captures are lexical borrows; they do not copy the captured value or extend
its lifetime. A capturing function therefore cannot be returned from the
scope that owns its captures. It can be passed to a synchronous callback and
called while that scope is active.

Function values can be stored in structure fields and called like ordinary
functions. They are language values; this does not expose a machine address or
a platform calling convention.

## Default arguments

```sx
func greet(message:str = "Hello", repetitions:int = 1) {
    print(message)
}

greet()
greet("Bonjour")
greet("Salut", 2)
```

Defaults form one trailing suffix in the declaration. A named call may omit any
defaulted parameter while supplying a later one, such as
`greet(repetitions:2)`. Each omitted expression is evaluated at the call site.

## Overloads

```sx
func describe(value:int) str { return "integer" }
func describe(value:str) str { return "string" }
```

Parameter types distinguish overloads. Return types and parameter names do
not. Two declarations cannot expose the same callable prefix through defaults.
Corresponding parameters in an overload family must nevertheless use the same
names, so labels never become an overload-selection mechanism.

For a public callable, parameter names are part of its source-level interface:
renaming one can break named callers even though it does not change overload
identity.

Resolution prefers the overload requiring the least costly implicit
conversions. When an integer argument can be converted to either floating
precision, `float` (`float32`) is preferred over `float64`; a value already
typed `float64` selects the `float64` overload. This applies equally to
positional and named calls.

## Return every path

```sx
func sign(value:int) str {
    if value < 0 {
        return "negative"
    }
    return "positive"
}
```

A non-`void` function must return or terminate on every reachable path.

## Make a function generic

```sx
func identity<T>(value:T) T {
    return value
}

let inferred = identity(42)
let explicit = identity<str>("Silex")
```

Supply every type argument or let Silex infer all of them from ordinary
arguments. The expected return type does not participate in inference.
Type arguments may themselves be generic specializations, including when a
named callback uses the same concrete type:

```sx
func passing(entry:@Entry<str, int>) bool {
    return entry.value >= 10
}

let explicit = count_where<Entry<str, int>>(entries, passing)
let inferred = count_where(entries, passing)
```

Constrain a type parameter with a [protocol](../Data-types/Protocols.md):

```sx
func render<T:Drawable>(value:T) {
    value.draw()
}
```

An applicable concrete overload takes priority over generic inference.
