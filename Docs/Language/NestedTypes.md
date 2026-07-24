# Nested types

A `struct`, `class`, or `static class` may declare another `struct`, `class`,
or `static class`. The declaration belongs to the type namespace of its owner
and is selected with `.`:

```sx
public class Foo {
    private class Bar {}
    internal struct Too {}
    public class Yoo {}
    protected class Omg {}
}

var value = Foo.Yoo()
```

Nesting may continue to any depth. A nested type is a type and static member;
it does not capture an instance of its owner. Code that needs an outer instance
passes or stores that value explicitly. A value never exposes nested types as
instance members.

Inside one nesting family, a nested type may be written with its short name.
Outside that family, its complete path is required. Nested types are not
inherited: a descendant names an accessible type through the class that
declared it, such as `Base.Token`, never `Child.Token`.

## Visibility

A nested declaration uses the same visibility words as members. In a class it
is private by default; in a struct it is public by default. `internal` confines
the name to the source file. `protected` is available only for a nested
ordinary class and permits access from the declaring nesting family and from
descendant classes. A nested struct or static class cannot be `protected`.

The owner's visibility is always an upper bound. A public nested class inside
a private owner does not become externally nameable. Every type in the same
nesting family can access the private declarations and private members of the
others. This access includes outer-to-inner, inner-to-outer, and siblings, but
does not give an extension private access.

A public operation may return a non-public nested type. The caller can keep the
inferred value and call its public instance members, but cannot name or
construct the hidden type. A public field, constructor, function, or method
cannot expose such a type as an input.

One owner cannot declare a nested type and a static field or static method with
the same name. Silex rejects the collision instead of choosing one meaning for
`Owner.Name`.

## Generics

A nested type may use every type parameter of its owners and declare its own.
The complete specialization lists arguments in owner-to-child order:

```sx
class Box<T> {
    public class Entry<U> {
        let key:T
        let value:U

        public init(key:T, value:U) {
            self.key = key
            self.value = value
        }
    }
}

var entry:Box<int>.Entry<str> = Box<int>.Entry<str>(1, "one")
```

`Box<int>.Entry<str>` and `Box<float>.Entry<str>` are distinct concrete types.
The qualified path is accepted in annotations, construction, class bases,
aliases, protocol conformances and extension targets. As elsewhere in Silex,
an `extend` target itself remains non-generic; a concrete generic
specialization cannot be extended.
