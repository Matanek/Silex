# Create and use classes

Declare the data and operations that belong to an object:

```sx
public class Player {
    private let name:str
    public var health:int = 100

    public init(name:str) {
        self.name = name
    }

    public func damage(amount:int) {
        self.health -= amount
    }

    public func description() str {
        return "$(self.name): $(self.health)"
    }
}

var player = Player("Ada")
player.damage(10)
print(player.description())
```

A class defines shared objects with automatic lifetime. Use `var` for a value
that can reach mutable class state.

## Construct an instance

Without a custom constructor, initialize visible fields by name:

```sx
class Position {
    public var x:int
    public var y:int
}

var position = Position(x:2, y:3)
```

Declare `init` when construction must establish an invariant:

```sx
class Counter {
    let minimum:int
    public var value:int

    public init(minimum:int) {
        self.minimum = minimum
        self.value = minimum
    }
}

var counter = Counter(10)
```

Declaring any `init` closes the named initializer. Every immutable field must
be initialized on every normal path before `self` escapes.

## Add instance methods

```sx
class Counter {
    public var value:int

    public func increment(amount:int = 1) {
        self.value += amount
    }

    public func current() int {
        return self.value
    }
}

var counter = Counter()
counter.increment()
print(counter.current())
```

Methods receive `self` implicitly. Arguments are positional and may use
trailing defaults like ordinary functions.

## Choose member visibility

Class fields, constructors, and methods are private by default:

```sx
public class Session {
    private let token:str
    internal var requests:int

    public init(token:str) {
        self.token = token
    }

    public func text() str {
        return self.token
    }
}
```

- `public` exposes a member through the class API.
- `protected` exposes it to the class and its descendants.
- `internal` restricts it to the exact source file.
- `private` states the default explicitly.

The class visibility always caps the visibility of its members.

## Add static members

```sx
class Player {
    public static let maximum_health:int = 100

    public static func default_health() int {
        return Player.maximum_health
    }
}

let health = Player.default_health()
```

Static members are selected through the complete type name. They are not
inherited or dynamically dispatched.

Use `static class` when the type contains no instances:

```sx
public static class Tasks {
    static var submitted:int

    public static func submit() {
        Tasks.submitted++
    }
}
```

A `static class` has no constructor, `self`, base class, protocol conformance,
or `drop`.

## Inherit from a class

```sx
class Entity {
    public let position:int

    public init(position:int) {
        self.position = position
    }
}

class Player:Entity {
    public let name:str

    public init(name:str, position:int):super(position) {
        self.name = name
    }
}
```

A class has at most one base class. The base is constructed before the child.
Omitting `:super(...)` is equivalent to `:super()`.

## Override a method

```sx
class Entity {
    public func update() {
        print("entity")
    }
}

class Player:Entity {
    override public func update() {
        super.update()
        print("player")
    }
}
```

Public and protected instance methods may be overridden. Overload selection
uses the receiver's visible type; the selected method dispatches on the
instance's real class. Constructors, private methods, static methods, and
extension methods are not virtual.

## Shared identity

A class value always designates an object. Passing or storing it preserves that
identity, and `==` compares identities. The detailed rules belong to
[copy and move](../Ownership/Copy-and-move.md) and
[references](../Ownership/References.md).

## Run cleanup with drop

```sx
class Connection {
    drop {
        print("closed")
    }
}
```

The block runs once when the last reachable root disappears; unreachable
cycles are finalized too. With inheritance, cleanup runs from the dynamic
class toward its bases. `drop` is not virtual, callable, or followed by an
explicit `super` call.

## Create a generic class

```sx
class Box<T> {
    let value:T

    public init(value:T) {
        self.value = value
    }
}

var box = Box<int>(42)
```

Every use supplies the complete type argument list. Each specialization keeps
ordinary class identity and owns separate static storage. Methods may use the
class parameters but cannot add another type parameter list.

Source code never manipulates an object address, retain count, allocation, or
manual release.
