# Expose or hide declarations

Top-level declarations are private by default:

```sx
func helper() {}

public func start() {
    helper()
}
```

Use `public` for a declaration available through a module or package API:

```sx
public struct Position {
    public var x:int
}
```

Use `internal` for a declaration restricted to its exact source file:

```sx
internal struct ParserState {}
internal func advance() {}
```

Neighboring modules cannot name an `internal` declaration.
Fragments of one logical module are still distinct source files, so an
`internal` declaration is not visible from another fragment. An ordinary
private declaration in a specialized fragment is accessible from portable code
through `Platform.name` or `Target.name`, never as an unqualified name.

## Class members

Class members are private by default:

```sx
public class Session {
    private let token:str

    public func text() str {
        return self.token
    }
}
```

`protected` makes a member available to the class and its descendants.
`internal` keeps it in the source file. The containing type always caps member
visibility.

## Structure members

Structure members are public by default. Explicit `public` is accepted when it
makes the API easier to scan. Use `internal` to restrict a member to the exact
source file, or `private` to restrict it to the structure and its nested type
family:

```sx
public struct Iterator<T> {
    private var values:T?[]

    func isEmpty() bool {
        return self.values.count() == 0
    }
}
```

Fields, constructors, methods, static members, and nested types accept
`public`, `internal`, or `private`. Structures do not support `protected`,
which is reserved for class inheritance.
