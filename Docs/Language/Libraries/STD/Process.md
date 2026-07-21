# Process

`STD.Process` describes the current process. `arguments` returns owned copies of
argument zero and every following argument without parsing options, quotes,
wildcards, or variables. POSIX rejects non-UTF-8 argument bytes. Windows uses
the native UTF-16 command line and the platform argument-splitting rules.

`current_directory` returns an absolute UTF-8 `/` path.
`set_current_directory` changes the process-global directory immediately, so
later relative `STD.File` and `STD.FileSystem` operations resolve from the new
location. Callers coordinating multiple threads must serialize that mutation.

`executable_path` returns the absolute path of the image actually running,
rather than copying `arguments()[0]`. A platform without a reliable mechanism
returns `System.ErrorKind.unsupported`. `id` exposes the current native process
identifier as `uint`; it is nonpersistent and may be reused after termination.

This module does not expose users, groups, threads, signals, daemons, services,
option parsing, or environment variables.
