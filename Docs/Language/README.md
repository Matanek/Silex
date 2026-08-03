# Silex language

Start with a program that does one thing:

```sx
func main() {
    print("Hello, Silex!")
}
```

The guide is grouped by the part of the language you are using.

## Getting started

- [Run a first program](Getting-started/First-program.md)
- [Declare and change variables](Getting-started/Variables.md)
- [Use built-in types](Getting-started/Built-in-types.md)
- [Calculate and compare values](Getting-started/Operators.md)
- [Branch and repeat](Getting-started/Control-flow.md)
- [Build strings](Getting-started/Strings.md)
- [Embed text files](Getting-started/Embedded-text.md)
- [Print and stop a program](Getting-started/Output.md)
- [Test one source](Getting-started/Tests.md)

## Functions

- [Write and call functions](Functions/Functions.md)
- [Return recoverable failures with Result](Functions/Result.md)

Generic functions are documented with ordinary functions, where their call
syntax and overload behavior matter.

## Modules

- [Import modules](Modules/Modules.md)
- [Use source packages](Modules/Packages.md)
- [Expose or hide declarations](Modules/Visibility.md)
- [Build a low-level macOS binding](Interop.md)

## Data types

- [Create value types with structures](Data-types/Structures.md)
- [Create shared identities with classes](Data-types/Classes.md)
- [Define protocols](Data-types/Protocols.md)
- [Extend an existing type](Data-types/Extensions.md)
- [Represent absence with optionals](Data-types/Optionals.md)
- [Represent choices with enums](Data-types/Enums.md)
- [Group structural values with tuples](Data-types/Tuples.md)

Generic structures, classes, and enums are documented in their respective
pages. The same pages explain `drop` where those types can declare it.

## Collections

- [Use arrays and lists](Collections/Arrays-and-lists.md)
- [Iterate values](Collections/Iteration.md)
- [Borrow collection views](Collections/Views.md)

## Ownership

- [Copy or move values](Ownership/Copy-and-move.md)
- [Borrow values with references](Ownership/References.md)

## Reference

- [Syntax quick reference](Reference/Syntax.md)
- [Current limits](Reference/Current-limits.md)

## Find a cross-cutting feature

- Generic code: [functions](Functions/Functions.md#make-a-function-generic),
  [structures](Data-types/Structures.md#create-a-generic-structure),
  [classes](Data-types/Classes.md#create-a-generic-class), and
  [enums](Data-types/Enums.md#create-a-generic-enum).
- Deterministic cleanup: [`drop` in structures](Data-types/Structures.md#run-cleanup-with-drop)
  and [`drop` in classes](Data-types/Classes.md#run-cleanup-with-drop).

These pages describe the source forms implemented by the current native
compiler. They do not define a stable ABI or expose compiler internals.
