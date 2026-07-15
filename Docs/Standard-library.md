# Standard library

Silex distributes its standard-library sources with the compiler. `STD` is its
reserved root module; directories below it provide submodules that are compiled
with the program when explicitly imported or used. They are versioned with
Silex itself; projects do not list them in a JSON manifest.

```sx
import STD

use STD.Random as Random
use STD.Random.Generator as Generator

func main() {
    var random:Generator = Random.system()
    let value = random.get_int()
    print(value > 0)
}
```

## Random

`STD.Random.create(seed)` returns a deterministic `Generator`. Equal seeds
produce equal sequences. `STD.Random.system()` returns a generator initialized
from the platform runtime. `get_int()`, `get_float()`, and `get_bool()` produce
typed values, while the overloads with minimum and maximum arguments produce a
value in the requested half-open interval. Every call advances only that
generator's state.

The deterministic transition is implemented in Silex. Only the system seed is
provided by the private native runtime declared at the `STD` root and linked
automatically when `STD.Random` is loaded.
