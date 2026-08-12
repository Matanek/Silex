# Publish Silex packages

The public package registry is hosted at
[`https://silex-lang.org/registry/v1/index.json`](https://silex-lang.org/registry/v1/index.json).
The Silex CLI reads it when `silex install Name` or
`silex install Name@MAJOR.MINOR.PATCH` does not name a local directory.

The registry is split by package and version. Its generated package index lists
the available versions and their Silex compatibility, while each immutable
manifest owns the archive URL and checksum:

```text
registry/v1/
  index.json
  packages/
    STD/
      index.json        generated during deployment
      0.16.2.json       immutable release manifest
```

Each registry release records the package version, its supported Silex range,
and one immutable source archive:

```json
{
  "schema": 1,
  "name": "STD",
  "version": "0.16.2",
  "requires": {
    "silex": ">=0.38.0"
  },
  "archive": {
    "url": "https://github.com/Matanek/Silex-Lib-STD/releases/download/v0.16.2/STD-0.16.2.tar.gz",
    "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }
}
```

For an unversioned request, Silex selects the newest release whose
`requires.silex` accepts the running toolchain. An exact request selects only
that version. The downloaded archive must contain one top-level directory and
its `Package.json` must match the registry name, version, and Silex range.
Dependencies remain declared only in that manifest; the installer resolves
them transitively through the same registry and verifies each archive in turn.

## Release sequence

1. Update and validate `Package.json`, including `version` and
   `requires.silex`.
2. Commit the complete package contents.
3. Tag that commit as `vMAJOR.MINOR.PATCH` and push the tag.
4. Let the package release workflow publish the source archive and checksum.
5. Open a pull request against `Matanek/Silex-Website` that adds
   `registry/v1/packages/Name/MAJOR.MINOR.PATCH.json` with the release URL and
   published SHA-256 value.

The deployment validates the version manifest and regenerates the package
`index.json`. The tag and manifest versions must match. A registry entry is
added only after the immutable archive exists; placeholder URLs or checksums
are not valid releases.

## Develop the registry locally

Set `SILEX_REGISTRY` to a local registry root index while editing or testing
registry selection. Relative package and manifest endpoints are resolved from
that file:

```sh
SILEX_REGISTRY=/absolute/path/to/registry/v1/index.json silex install STD
```

The default registry always uses HTTPS. Package archives referenced by either
the public or development registry must also use HTTPS and pass their declared
SHA-256 check before extraction.
