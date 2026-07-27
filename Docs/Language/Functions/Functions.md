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
