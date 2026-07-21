# File

`STD.File` provides owned, noncopyable binary files. `open(path, options)`
selects read, write, or read/write access independently from creation policy;
invalid read/append combinations return `System.ErrorKind.invalid_input`.
`create_new` never replaces, `truncate_existing` never creates, and
`create_or_truncate` does both explicitly.

`File.read` and `File.write` implement `STD.IO.Reader` and `STD.IO.Writer` and
may transfer only part of the supplied view. `flush`, `seek`, `position`,
`length`, and `set_length` operate on byte positions. Append handles direct
every write to the then-current end even after a seek. `close(move file)`
reports close failures while still consuming the owner; `discard_file(file)`
and automatic scope destruction close silently and exactly once.

`read_all(path, maximum_bytes)` applies the same bounded semantics as
`IO.read_to_end`. `write_all(path, bytes)` creates or truncates, writes every
byte, flushes, then closes while preserving the first operational error. No
encoding or newline conversion is implicit.

POSIX creation uses mode `0666` filtered by the process umask. Windows creates
normal files and shares read, write, and delete access. Native sources are
distributed and compiled for the selected target; final symbolic links and
reparse points are followed by ordinary open semantics.
