# Expose or hide declarations

A declaration at module level is `module` by default. It is available from
every file owned by the same principal module, including child implementation
modules and the selected portable, `Platform`, and `Target` fragments. For
example, declarations in `STD.Regex.Engine` and `STD.Regex.Syntax` share the
`STD.Regex` module boundary when `STD.Regex` has a principal `@module.sx` or
`@Module.sx` file:

```sx
func helper() {}

public func start() {
    helper()
}
```

Use `public` for declarations that package consumers may name, `package` for
implementation shared by the modules of exactly one package, and `local` for a
declaration restricted to its source file:

```sx
public struct Position {
    var x:int
}

package struct DecodeState {}
package func decode() {}

local struct ParserState {}
local func advance() {}
```

The explicit `module` modifier is accepted when a boundary needs emphasis, but
omitting it is the ordinary style:

```sx
module class ExplicitHelper {}
class Helper {}
```

Packages sharing a namespace prefix do not share `package` visibility. A
`local` declaration never crosses its exact source-file boundary. Files owned
by a principal module share `module` declarations without merging lexical
scopes or import paths. Platform and target declarations still use their
contextual qualifications. Without a principal module, two sibling module
paths remain distinct visibility boundaries.

`private` and `protected` are relative to a type, so the compiler rejects them
at module level. `private` is available to the declaring nested-type family;
`protected` is reserved for class members and is also available to descendants.

## Members inherit their type

A field, constructor, method, static member, or nested type without a
modifier inherits the visibility of its containing type. Classes and
structures follow the same rule:

```sx
public class Session {
    private let token:str

    init(token:str) {
        self.token = token
    }

    func text() str {
        return self.token
    }

    package func debug() {}
}

class Compiler {
    init() {}
    func run() {}
}
```

`Session.init` and `Session.text` are public by inheritance. `Compiler` and its
members are module-visible. The containing type always caps its members: an
explicit modifier may preserve or restrict the inherited visibility, never
enlarge it. For example, `public func` inside a module-visible class is a
compile-time error rather than a silently capped declaration.

An override or protocol implementation keeps the visibility of its concrete
type. Calling through an already accessible base type or protocol keeps the
visibility of that contract; implementations do not need to republish it.

`use` introduces a name in the consuming file and `public use` explicitly
reexports it. Other visibility modifiers do not apply to `use`.
