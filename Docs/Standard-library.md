# Standard library

Silex distributes its standard-library sources with the compiler. `std` is its
reserved root module; directories below it provide submodules that are compiled
with the program when explicitly imported or used. They are versioned with
Silex itself; projects do not list them in a JSON manifest.

```sx
import std

use std.Random as Random
use std.Random.Generator as Generator

func main() {
    var random:Generator = Random.system()
    let value = random.get_int()
    print(value > 0)
}
```

## Random

`std.Random.create(seed)` returns a deterministic `Generator`. Equal seeds
produce equal sequences. `std.Random.system()` returns a generator initialized
from the platform runtime. `get_int()`, `get_float()`, and `get_bool()` produce
typed values, while the overloads with minimum and maximum arguments produce a
value in the requested half-open interval. Every call advances only that
generator's state.

The deterministic transition is implemented in Silex. Only the system seed is
provided by the private native runtime linked automatically when `std.Random`
is loaded.
