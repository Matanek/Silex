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

Arguments are positional and evaluated from left to right.

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
TaskManager.submit(task, func(completed:Task) {
    print("completed")
})
```

Anonymous functions currently cannot capture values from their surrounding
function. Their parameters and declarations made inside their body remain
available normally. A capture produces a targeted diagnostic until closure
environments and their lifetime rules are implemented.

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

Defaults form one trailing suffix. You cannot skip an argument in the middle.
Each omitted expression is evaluated at the call site.

## Overloads

```sx
func describe(value:int) str { return "integer" }
func describe(value:str) str { return "string" }
```

Parameter types distinguish overloads. Return types and parameter names do
not. Two declarations cannot expose the same callable prefix through defaults.

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

Constrain a type parameter with a [protocol](../Data-types/Protocols.md):

```sx
func render<T:Drawable>(value:T) {
    value.draw()
}
```

An applicable concrete overload takes priority over generic inference.
