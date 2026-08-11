# Install Silex

The published compiler supports macOS on Apple Silicon, Linux x64, and Windows
x64. It is a standalone executable: using it does not require Zig, Git, or a
source checkout.

## macOS and Linux

Inspect [`install.sh`](../install.sh), then run:

```sh
curl -fsSL https://raw.githubusercontent.com/Matanek/Silex/main/install.sh | sh
```

The installer selects `silex-macos-arm64` or `silex-linux-x64`, verifies its
published SHA-256 checksum, and installs `silex` under `~/.local/bin`. Set an
explicit destination when needed:

```sh
SILEX_INSTALL_DIR="$HOME/bin" sh install.sh
```

## Windows

Inspect [`install.ps1`](../install.ps1), then run it from PowerShell:

```powershell
irm https://raw.githubusercontent.com/Matanek/Silex/main/install.ps1 | iex
```

The installer downloads `silex-windows-x64`, verifies its published SHA-256
checksum, and installs `silex.exe` under `%LOCALAPPDATA%\Silex\bin`. Select a
different destination with the `SILEX_INSTALL_DIR` environment variable:

```powershell
$env:SILEX_INSTALL_DIR = "$HOME\bin"
irm https://raw.githubusercontent.com/Matanek/Silex/main/install.ps1 | iex
```

The Windows executable is currently unsigned, so Windows may display a
reputation warning. The checksum still detects a modified or incomplete
download when compared with the file published by the release workflow.

## Version and verification

Set `SILEX_VERSION` to a published semantic version to install that release
instead of the latest. On PowerShell, use `$env:SILEX_VERSION = "0.38.2"`.
An existing executable at the selected destination is replaced only after the
new archive has been downloaded and verified.

Make sure the destination is on `PATH`, then verify the installation:

```sh
silex --version
silex targets
```

The compiler itself is now ready. Shader compilation is an optional toolchain
capability and requires one additional setup step:

```sh
silex setup
```

This installs the verified Shadercross tool for the host under
`~/.silex/toolchain/`. It is not linked into applications.

## Build from source

Building the compiler requires the Zig version declared by
`Toolchain/build.zig.zon`:

```sh
cd Toolchain
zig build
./zig-out/bin/silex --version
```

The release workflow accepts a tag only when its version matches the toolchain
manifest. It builds each standalone executable on its native GitHub runner,
then installs STD, compiles a package-consuming Silex program, and exercises
native execution before publishing the archives and their checksums. Linux and
Windows additionally execute that package-consuming program on their runners.

## Remove Silex

Remove the installed executable. User packages, compiler tools, and caches live
separately under `~/.silex/` on Unix and `%USERPROFILE%\.silex\` on Windows;
they can be retained for a later installation.
