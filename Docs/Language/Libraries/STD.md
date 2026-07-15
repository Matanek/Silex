# STD

Silex distributes the source of `STD` with the compiler. `STD` is a reserved
root module: its submodules are compiled with the program when explicitly
imported or used. They are versioned with Silex itself, so projects must not
list `STD` in `Module.json` dependencies.

```sx
import STD

use STD.Random as Random
use STD.Random.Generator as Generator

func main() {
    var random:Generator = Random.system()
    print(random.get_int() > 0)
}
```

## STD.Random

`STD.Random` provides a deterministic generator for games, simulations, and
tests. It is not cryptographically secure. `create(seed)` builds a reproducible
generator, while `system()` chooses an initial seed from the host.

```sx
var random = STD.Random.create(42)

let raw = random.get_int()
let die = random.get_int(1, 7)
let ratio = random.get_float()
let temperature = random.get_float(-10.0, 40.0)
let enabled = random.get_bool()
```

`get_int()` returns an `int` from `1` through `9223372036854775807`.
`get_int(minimum, maximum)` returns an unbiased `int` in
`[minimum, maximum)` and requires `minimum < maximum` with a positive `int`
width. `get_float()` returns a `float` in `[0.0, 1.0)`; its bounded overload
returns a `float` in `[minimum, maximum)` and requires finite, ordered bounds.
`get_bool()` returns either boolean value. Every call advances only its own
generator. Two generators with the same seed and sequence of calls return the
same sequence of values.

The deterministic transition is implemented in Silex. Only the seed used by
`system()` comes from the private native runtime inherited from
`STD/Module.json`.

## STD.Time

### Stopwatch

`STD.Time.Stopwatch` measures a real duration for benchmarks and other bounded
operations. It is initially stopped with a zero elapsed duration. `start()`
starts or resumes without clearing, `stop()` freezes the accumulated duration,
`reset()` clears and stops, and `restart()` clears and starts. Calling
`start()` while running or `stop()` while stopped has no effect.

`get_elapsed_seconds()` and `get_elapsed_milliseconds()` remain readable while
the stopwatch is running or stopped.

### Clock

`STD.Time.Clock` drives a logical loop and has no `start()` or `stop()`. The
first `tick()` initializes its monotonic origin and returns zero. Every active
tick after it returns the scaled interval since the preceding tick and adds
that value to the logical total. A paused tick returns zero.

Pausing or changing the scale preserves any partial interval so that the next
active tick loses no active time and excludes all suspended time. `reset()`
clears the total and partial interval, exits the paused state, and makes the
next tick return zero. Reset does not change the configured time scale.

Both types and their duration calculations are implemented in Silex under
`STD/Time/`. Their shared private native runtime only supplies a monotonic
timestamp in microseconds.
