# Environment

`STD.Environment` reads and mutates the current process environment. `get`
distinguishes an absent name (`null`) from an empty value (`""`); `set` creates
or replaces and `remove` is idempotent. Returned strings are owned Silex copies
and never borrow the native environment block.

Names must be nonempty and contain neither `=` nor a null byte. Values may be
empty but cannot contain a null byte. POSIX treats names as case-sensitive
UTF-8 bytes. Windows compares names without case and converts strictly between
UTF-8 and UTF-16; its internal entries beginning with `=` are not public
variables.

`variables` returns one entry per platform-equivalent name, using the value
that `get` observes, then sorts entries by the exact UTF-8 bytes of their names.
Malformed native UTF data causes `System.ErrorKind.invalid_data` rather than
being omitted. Mutation by unrelated native code at the same instant remains
outside the API contract.

This module does not read `.env` files, expand names, search `PATH`, or mark
values as secrets. Child-process inheritance and overrides are specified by
`STD.Subprocess`.
