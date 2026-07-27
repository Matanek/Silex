# Define protocols

Declare the methods a type must provide:

```sx
protocol Drawable {
    func draw()
}

struct Sprite:Drawable {
    func draw() {
        print("sprite")
    }
}
```

Conformance is nominal: the type must list the protocol. A method with the
right shape is not enough by itself.

## Store a conforming value

```sx
var drawable:Drawable = Sprite()
drawable.draw()
```

A protocol value exposes only its requirements. A structure is copied into
the dynamic value; a class keeps its shared identity. Calls through a protocol
value are treated as mutating, so a direct receiver uses `var`.

## Constrain generic code

```sx
func render<T:Drawable>(value:T) {
    value.draw()
}

render(Sprite())
```

The compiler specializes `render` for the concrete type. The protocol does
not introduce an erased container at this call site. Each type parameter
accepts at most one protocol constraint.

A class may list one base class first, then protocols. Structures list only
protocols. A derived class inherits valid conformances from its base.
