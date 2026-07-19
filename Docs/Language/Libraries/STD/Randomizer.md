# STD.Randomizer

`STD.Randomizer` is a pseudo-random generator for games, simulations, and
tests. It is not cryptographically secure.

Select the `Randomizer` source unit and its public homonymous class directly:

```sx
use STD.Randomizer as Randomizer

var random = Randomizer.create(42)
```

`create(seed)` builds an independent reproducible instance, while `create()`
chooses its initial seed from the host.

```sx
let raw = random.get_int()
let die = random.get_int(1, 7)
let ratio = random.get_float()
let temperature = random.get_float(-10.0, 40.0)
let enabled = random.get_bool()
```

## Values and bounds

`get_int()` returns an `int` from `1` through `9223372036854775807`.
`get_int(minimum, maximum)` returns an unbiased `int` in
`[minimum, maximum)` and requires `minimum < maximum` with a positive `int`
width.

`get_float()` returns a `float` in `[0.0, 1.0)`. Its bounded overload returns a
`float` in `[minimum, maximum)` and requires finite, ordered bounds.

`get_bool()` returns either boolean value. Every call advances its instance.

## State and reproducibility

Copying, passing, or returning a `Randomizer` preserves the same class
instance, so all of its references advance one shared state. Two separate
instances created with the same seed and sequence of calls return the same
sequence of values.

The deterministic transition is implemented in Silex. Only the seed used by
`create()` comes from the private native runtime configured by
`STD/@Module.json`.

[Back to STD](README.md)
