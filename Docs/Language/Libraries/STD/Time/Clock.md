# STD.Time.Clock

`STD.Time.Clock` drives a logical loop. It advances through `tick()` and has no
`start()` or `stop()` operation.

```sx
use STD.Time.Clock as Clock

var clock = Clock()
let first_delta = clock.tick()
let next_delta = clock.tick()
```

The first `tick()` initializes the monotonic origin and returns zero. Every
active tick after it returns the scaled interval since the preceding tick and
adds that value to the logical total. A paused tick returns zero.

## Operations

- `tick()` advances logical time and returns the latest scaled interval in
  seconds.
- `pause()` suspends logical time.
- `resume()` continues logical time without including suspended time.
- `is_paused()` reports whether the clock is paused.
- `set_time_scale(scale)` changes the multiplier applied to subsequent active
  time.
- `get_time_scale()` returns the current multiplier.
- `get_total_seconds()` returns the accumulated logical duration in seconds.
- `get_total_milliseconds()` returns that duration in milliseconds.
- `reset()` clears the timeline and exits the paused state.

Pausing or changing the scale preserves any partial interval. The next active
tick therefore loses no active time and excludes all suspended time.

`reset()` clears the total and partial interval, exits the paused state, and
makes the next tick return zero. Reset does not change the configured time
scale.

[Back to STD.Time](README.md)
