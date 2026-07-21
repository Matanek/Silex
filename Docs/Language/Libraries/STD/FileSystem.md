# FileSystem

`STD.FileSystem` discovers and mutates the filesystem without introducing an
implicit recursive traversal. `metadata` follows the final symbolic link while
`symbolic_link_metadata` describes that link itself. File sizes are byte counts;
directories, links, and other entries report zero.

`canonicalize` requires an existing path, resolves links, and returns an
absolute UTF-8 path using `/`. `list` returns relative one-component names,
omits `.` and `..`, rejects native names that are not valid UTF-8, and sorts by
UTF-8 bytes for deterministic traversal.

`create_directory` rejects every existing destination. `create_directories` is
idempotent when every existing component is a directory. `remove_file` removes
a file or the final link itself; `remove_directory` accepts only an empty final
directory and never follows a final link. `rename` rejects an existing
destination on every supported platform.

`copy_file` follows the source's final link but rejects directories. With
`replace:false`, any destination is an `already_exists` error. With
`replace:true`, a destination link is replaced rather than followed.
`set_readonly` follows the final link and changes only the portable readonly
property. Owners, ACLs, timestamps, recursive operations, globs, watchers, and
link creation are outside this API.

Every failure is returned as `STD.System.Error`. The native sources are
distributed and compiled for macOS ARM64, Linux x86-64, or Windows x86-64 with
the rest of the selected `STD` modules.
