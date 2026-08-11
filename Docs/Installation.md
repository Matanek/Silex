# Install Silex

The published compiler currently supports macOS on Apple Silicon. It is a
standalone executable: using it does not require Zig or a source checkout.

## User installation

Inspect [`install.sh`](../install.sh), then run:

```sh
curl -fsSL https://raw.githubusercontent.com/Matanek/Silex/main/install.sh | sh
```

The installer downloads the latest `silex-macos-arm64` release, verifies its
published SHA-256 checksum, and installs `silex` under `~/.local/bin`. Set an
explicit destination when needed:

```sh
SILEX_INSTALL_DIR="$HOME/bin" sh install.sh
```

Set `SILEX_VERSION` to a published semantic version to install that release
instead of the latest. An existing executable at the selected destination is
replaced only after the new archive has been downloaded and verified.

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
manifest. It builds and smoke-tests the standalone executable before publishing
the archive and its checksum.

## Remove Silex

Remove the installed executable. User packages, compiler tools, and caches live
separately under `~/.silex/` and can be retained for a later installation.
