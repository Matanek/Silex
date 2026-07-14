# Standard library

Silex distributes its standard-library sources with the compiler. Modules use
the reserved `std` namespace and are compiled with the program that imports
them. They are versioned with Silex itself; projects do not list them in a JSON
manifest.

```sx
import std.Random

func main() {
    var random = std.Random.system()
    let value = random.next()
    print(value > 0)
}
```

## Random

`std.Random.create(seed)` returns a deterministic `Generator`. Equal seeds
produce equal sequences. `std.Random.system()` returns a generator initialized
from the platform runtime. In both cases, `generator.next()` returns a positive
random `int` and advances only that generator's state.

The generator delegates its state transition and system seed to private native
functions supplied by the standard-library runtime and linked automatically
when the module is imported.

The initial module deliberately does not provide bounded ranges, seeding, or
concurrency APIs. Those contracts will be added separately.
