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

Use `internal` for implementation shared by the modules of one package without
exposing it to package consumers:

```sx
internal struct DecodeState {}
internal func decode() {}
```

Use `local` for a declaration restricted to its exact source file:

```sx
local struct ParserState {}
local func advance() {}
```

The visibility order is `public`, `internal`, `private`, then `local`.
Neighboring modules in the same package can name an `internal` declaration but
not a private one. Fragments of one logical module remain distinct source
files, so a `local` declaration is unavailable from another fragment. An
ordinary private declaration in a specialized fragment is accessible from
portable code through `Platform.name` or `Target.name`, never as an unqualified
name. Packages sharing a namespace prefix never share internal visibility.

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
`internal` makes it available throughout the package, while `local` keeps it in
the source file. The containing type always caps member visibility.

## Structure members

Structure members are public by default. Explicit `public` is accepted when it
makes the API easier to scan. Use `internal` to share a member throughout the
package, `local` to restrict it to the exact source file, or `private` to
restrict it to the structure and its nested type family:

```sx
public struct Iterator<T> {
    private var values:T?[]

    func isEmpty() bool {
        return self.values.count() == 0
    }
}
```

Fields, constructors, methods, static members, and nested types accept
`public`, `internal`, `local`, or `private`. Structures do not support
`protected`, which is reserved for class inheritance.
