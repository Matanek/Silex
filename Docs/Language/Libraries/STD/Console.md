# STD.Console

`STD.Console` exposes text output, optional interactive-terminal control, and
canonical line input.

```sx
use STD.Console as Console

Console.write("Name: ")
if name = Console.read_line() {
    Console.write_line("Hello " + name)
}
```

`write(text:str)` and `write_line(text:str)` target standard output; `write_error`
and `write_error_line` target standard error. Each `write_line` form appends one
line ending, including for an empty string. `flush()` flushes both streams.
Write and flush failures are runtime errors; redirected output is not one.

`read_line() str?` flushes standard output, then reads the next canonical line
from standard input. It returns `""` for an empty line and `null` only at end of
input. It removes LF and CRLF terminators, retains internal null bytes, and
returns one final unterminated line before the next call returns `null`. Reading
works through a terminal, file, or pipe. Invalid UTF-8 is a runtime error; it
never returns a partial string.

`wait_for_enter()` also flushes standard output, then consumes input until the
next LF or end of input. It discards the preceding characters and does not
create a string. Both operations remain in canonical terminal mode: no raw
mode or individual-key reading is enabled.

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
