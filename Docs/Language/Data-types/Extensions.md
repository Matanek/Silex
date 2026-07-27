# Extend an existing type

Add methods without changing a type's fields or identity:

```sx
extend Counter {
    func increment(amount:int = 1) {
        self.value += amount
    }

    static func zero() Counter {
        return Counter(value:0)
    }
}
```

An extension cannot add fields, constructors, `drop`, overrides, or protected
members.

Importing an extension module activates its public methods. Merely placing the
file next to the target does not.

A qualified reference may load a child module on demand. For example, after
`use STD.Math`, referring to `Math.Vec3` loads that child and activates the
extensions it declares. Unused children are not loaded eagerly merely because
their parent namespace is available.

## Add a conformance

```sx
extend Sprite:Drawable {
    func draw() {
        print("sprite")
    }
}
```

The conformance is available in files that activate the extension provider
through `use`, directly or transitively.

Extensions may target an existing non-generic structure or class. An extension
method on such a type may itself be generic.
