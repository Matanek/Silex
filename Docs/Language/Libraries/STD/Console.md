# STD.Console

`STD.Console` exposes text output, optional interactive-terminal control,
canonical line input, and immediate keyboard sessions.

```sx
use STD.Console

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
mode or individual-key reading is enabled. They are runtime errors while an
interactive `Session` is open.

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

## Interactive sessions

`Session.create()` requires both standard input and standard output to be
interactive. It captures their POSIX `termios` or Windows Console modes and
activates immediate, non-echoed input. Only one session may be open in a
process. In this mode, `Ctrl+C` is returned as a key event rather than sent as
an interruption signal.

```sx
use STD.Console

var session = Console.Session.create()
session.enter_alternate_screen()

var running = true
while running {
    let event = session.read_key()
    match event.key {
        character(text) => Console.write(text)
        escape => { running = false }
        else => {}
    }
}
```

`read_key()` blocks until a complete `KeyEvent` is available.
`poll_key(timeout_milliseconds:int) KeyEvent?` waits at most the requested
duration; zero is non-blocking and a negative duration is a runtime error. A
poll that expires preserves a partial escape sequence for the following call.

`poll_keys(maximum_count:int, timeout_milliseconds:int) Queue<KeyEvent>` waits
only for its first event, then performs non-blocking polls until the queue
reaches the positive maximum or no event is immediately available. The next
`dequeue` is the first event observed. The result owns its events and remains
valid after another poll or after the session closes. For `k` returned events,
construction takes O(k) time and storage; it never pre-reads beyond the
requested maximum. A non-positive maximum panics with
`Console.Session.poll_keys requires a positive maximum count`, while timeout
validation is identical to `poll_key`.

`Key` distinguishes Unicode `character(str)`, Enter, Escape, Tab, Backspace,
Delete, the four arrows, Home, End, Page Up, Page Down, `function(int)` from F1
through F24, and `unknown(str)`. A character contains exactly one UTF-8 scalar.
Unknown terminal bytes remain reversible as uppercase hexadecimal pairs
separated by spaces. The `shift`, `control`, and `alt` fields are set only when
the platform event or byte sequence identifies them. On POSIX, a printable
uppercase character alone cannot distinguish Shift from Caps Lock.

CR, LF, and a contiguous CRLF form one Enter event. ASCII control codes from
`Ctrl+A` through `Ctrl+Z` become the corresponding lowercase character with
`control:true` unless they have a named key. An Escape prefix on a character
sets `alt:true`. An isolated Escape waits internally for 25 milliseconds so it
can be distinguished from the start of a terminal sequence.

`enter_alternate_screen()` and `leave_alternate_screen()` are idempotent.
`close()` is also idempotent, and `is_open()` becomes false after it. Every
other session method is a runtime error after closing. `Session` has a `drop`
block and is therefore a uniquely owned, non-copyable resource; ordinary
`move` transfers it.

Closing or dropping a session leaves its alternate screen if necessary,
resets text style, makes the cursor visible, and restores the captured native
modes. The same restoration runs during normal Silex exits that execute
`drop`. It cannot be guaranteed after forced process termination, a native
crash, or power loss. ANSI style and cursor state inherited before the session
cannot generally be queried on POSIX, so only the reset and visible final
state are guaranteed there.

[Back to STD](README.md)
