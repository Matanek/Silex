# STD.Time

`STD.Time` contains monotonic time utilities. Select only the class needed by
the source file:

```sx
use STD.Time.Stopwatch as Stopwatch
use STD.Time.Clock as Clock
```

- [Stopwatch](Stopwatch.md) measures a real duration and can be stopped,
  resumed, reset, or restarted.
- [Clock](Clock.md) advances a scaled logical timeline through explicit
  `tick()` calls and can be paused.

Both classes and their duration calculations are implemented in Silex under
`STD/Time/`. Their shared private native runtime supplies only a monotonic
timestamp in microseconds.

[Back to STD](../README.md)
