# Type extensions

`extend` adds methods to an existing nominal structure or class without
changing the declaration, storage, initialization, or identity of that type.
The target may be local or imported:

```sx
import STD.Random as Random
use STD.Random.Generator as Generator

extend Generator {
    pub func get_uint() uint {
        return self.get_int() as uint
    }

    pub static func seeded(seed:int) Generator {
        return Random.create(seed)
    }
}
```

An extension method uses the ordinary method syntax. Instance methods declare
`self` implicitly through the target type and become mutating when they write
through `self` or call another mutating method. A `static func` is selected
through the complete type and has no receiver:

```sx
var generator = Generator.seeded(42)
let value = generator.get_uint()
```

Extension methods are resolved statically from the receiver's declared type.
They do not enter class virtual dispatch and are not inherited. Extending
`Entity` does not make the method a member of `Player`, and a value declared as
`Entity` cannot select an extension written for `Player`.

## Visibility and imports

Every source file in the declaring module can use its extension methods. A
method without `pub` remains private to that module. A `pub` extension method
also becomes a candidate in a source file that directly imports the declaring
module:

```sx
import MyLibrary.RandomExtensions as RandomExtensions

func sample(generator:Generator) uint {
    return generator.get_uint()
}
```

The import activates all public extensions declared by that module; there is
no separate `use` form for an extension method. Merely compiling a module,
depending on its package, or importing it transitively does not activate its
extensions. Each consuming source file names the extension module directly,
following the ordinary file-scoped `import` rules.

An extension has the access rights of an outside caller. Its body can use only
the target's `pub` members, never private or `sub` members, even when the
extension is declared in the module that owns the type.

## Coherence and limits

An extension cannot repeat the exact signature of a method declared by the
type. Two visible extensions cannot provide the same exact signature either;
the diagnostic names both extension modules instead of choosing according to
source or import order. Different signatures remain ordinary overloads.

Extensions add behavior only. They cannot declare fields, constructors,
`drop`, `override`, `sub` members, or protocol conformances. They cannot target
an enum, protocol, scalar, collection, generic type, or one specialization of
a generic type. Extension methods cannot currently declare their own type
parameters.
