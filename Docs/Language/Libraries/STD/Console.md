# STD.Console

`STD.Console` exposes text output and optional interactive-terminal control.

```sx
use STD.Console as Console

Console.write("Loading")
Console.write_line(" complete")
Console.flush()
```

`write(text:str)` and `write_line(text:str)` target standard output; `write_error`
and `write_error_line` target standard error. Each `write_line` form appends one
line ending, including for an empty string. `flush()` flushes both streams.
Write and flush failures are runtime errors; redirected output is not one.

`is_interactive()` reports whether standard output is a terminal.
`get_dimensions() Dimensions?` returns positive visible dimensions or `null`.
`clear_screen()`, `clear_line()`, `move_cursor(column:int, row:int)`,
`show_cursor()`, `hide_cursor()`, `set_foreground(color:Color)`,
`set_background(color:Color)`, `enable_style(style:TextStyle)`, and
`reset_style()` control that terminal. Coordinates are absolute and zero-based;
negative coordinates are runtime errors. Repeated styles accumulate, while
`reset_style()` restores both colors and styles.

When standard output is redirected, every display-control operation emits no
bytes. A terminal without a supported capability may ignore that operation.
Standard error never receives display-control bytes implicitly.

[Back to STD](README.md)
