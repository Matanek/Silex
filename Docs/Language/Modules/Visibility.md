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

Members of a public structure are public by default. Explicit `public` is
accepted when it makes the API easier to scan.
