# STD.Time.Stopwatch

`STD.Time.Stopwatch` measures a real duration for benchmarks and other bounded
operations.

```sx
use STD.Time.Stopwatch as Stopwatch

var stopwatch = Stopwatch()
stopwatch.start()
// measured operation
stopwatch.stop()
print(stopwatch.get_elapsed_milliseconds())
```

The stopwatch is initially stopped with a zero elapsed duration.

## Operations

- `start()` starts or resumes without clearing the accumulated duration.
- `stop()` freezes the accumulated duration.
- `reset()` clears the duration and stops the stopwatch.
- `restart()` clears the duration and starts the stopwatch.
- `is_running()` reports whether the stopwatch is currently running.
- `get_elapsed_seconds()` returns the elapsed duration in seconds.
- `get_elapsed_milliseconds()` returns the elapsed duration in milliseconds.

Calling `start()` while running or `stop()` while stopped has no effect.
`get_elapsed_seconds()` and `get_elapsed_milliseconds()` remain readable while
the stopwatch is running or stopped.

[Back to STD.Time](README.md)
