# Publish Silex packages

The public package registry is hosted at
[`https://registry.silex-lang.org/v1/index.json`](https://registry.silex-lang.org/v1/index.json).
It assigns each package name to one canonical Git repository. Versions,
compatibility, dependencies, namespace extension grants, friend grants, and package contents
remain owned by tagged commits in that repository.

The generated registry index has this shape:

```json
{
  "schema": 2,
  "packages": [
    {
      "name": "GFX",
      "repository": "https://github.com/Matanek/Silex-Lib-GFX.git"
    }
  ]
}
```

`silex install Name` resolves the registered repository, fetches its
`vMAJOR.MINOR.PATCH` tags, and reads `Package.json` from each tagged commit. It
selects the newest version whose `requires.silex` accepts the running
toolchain. An exact `silex install Name@MAJOR.MINOR.PATCH` request resolves only
that tag.

Silex creates the package archive directly from the selected commit and stores
a source proof beside the installed files. The proof binds the package name and
version to its repository, commit, archive checksum, manifest checksum,
extension grants, and friend grants. Editing an installed manifest therefore
cannot grant another namespace or privileged package access. The local Git
cache also refuses to replace an already observed tag with another commit.

Dependencies remain declared only in the tagged `Package.json`. The installer
resolves them transitively through their own registered repositories before it
installs the requested package.

## Register a package once

Once the package name and canonical repository are established, register that
identity:

```sh
silex register path/to/Package
```

Silex prepares one immutable registration at
`registry/v1/packages/Name.json`, creates or reuses the developer's registry
fork, and opens a pull request. Repeating the command after that registration
is merged is an idempotent no-op. Versions never require another registry
review.

Registry maintainers can prepare a registration in a local checkout without
submitting it to GitHub:

```sh
SILEX_REGISTRY_SOURCE=/absolute/path/to/Silex-Registry silex register path/to/Package
```

## Prepare and tag versions

1. Update and validate `Package.json`, including `version`, `requires.silex`,
   dependencies, `extensions`, and `friends`.
2. Commit the complete package contents.
3. Optionally validate the Silex package contract and display the expected tag:

   ```sh
   silex check path/to/Package
   ```

4. Create and push the version tag with Git:

   ```sh
   git tag vMAJOR.MINOR.PATCH
   git push origin vMAJOR.MINOR.PATCH
   ```

`silex check` validates `Package.json`, its compatibility and dependency
contracts, then reports the `vMAJOR.MINOR.PATCH` tag implied by its version. It
does not require a Git repository, inspect release state, create a commit, tag,
or contact a remote. Git remains the source of truth for version publication.
When installing, Silex accepts a tag only when its tagged `Package.json`
declares that exact version. No additional archive, release asset, registry
version document or additional Silex publication command is required.

## Develop the registry locally

Build the deployable index, then point Silex at it:

```sh
node scripts/build-registry.mjs dist/v1
SILEX_REGISTRY=/absolute/path/to/dist/v1/index.json silex install STD
```

The public registry and its repository URLs use HTTPS. A local registry index
may use local Git repositories for integration testing.
