# Registry identity client qualification

`Toolchain/Sources/RegistryLogin.zig` owns the experimental identity client;
`Main.zig` only dispatches `login` and `logout`. Public usage documentation belongs
to the mirrored `Silex-Documentation/{FR,EN}/Tools/Registry-login.md` pages.
This is not a deployed service. A real GitHub device flow and registry revocation
have been exercised locally; offline fixtures are separate evidence.

## Trust boundaries

The sole normal origin is `https://registry.silex-lang.org`. The client generates
a private 256-bit attempt ticket and sends it only in the Login authorization
header. The server performs the GitHub exchange and returns a distinct, bounded
registry bearer. The ticket is never persisted; no GitHub access token is exposed
to the CLI. Redirects are not followed, responses are limited to 32 KiB and each
HTTP operation has a 25-second cancellation deadline. Browser launch uses only
the fixed GitHub device URL and no shell. Provider codes/credentials, response
bodies and browser subprocess output are never included in error diagnostics.

The command verifies attempt IDs, terminal states, identity syntax and credential
lifetime before saving. A consumed attempt requires a new login; a lost final
response is not a recoverable credential channel. A failed save attempts to revoke
the newly issued bearer; if that request also fails, the bearer expires server-side.

POSIX storage uses a 0700 directory, 0600 files, no-follow opens, regular-file and
single-link checks, a nonblocking process lock and an exclusive random temporary
file. A successful save synchronizes the file, renames it and synchronizes the
directory. The client tightens an empty legacy registry store to 0700, but
refuses to trust a credential already found beneath permissive directory modes.
Logout revokes before deleting and synchronizing. The store protects
against other ordinary local users, not a compromised user account or privileged
process.

Windows uses current-user DPAPI in `%USERPROFILE%\.silex\auth\registry.dpapi`,
never machine-wide protection or a plaintext fallback. Authentication and
decryption happen before JSON parsing. Native file attributes use their Windows
defaults, not numeric POSIX modes; DPAPI provides credential confidentiality, not
an assertion about inherited ACLs. Regular-file/single-link checks and process
locking remain mandatory. File contents are flushed before atomic rename; the
read-only directory handle is not flushed, so no power-loss durability guarantee
is claimed on Windows. Browser launch uses `ShellExecuteW` with a fixed URL.
macOS ARM64 is the tested host; other native executions remain explicit work,
not implied portability claims.

## Offline end-to-end bank

Build this candidate normally. From the Spec Worktree group, run the bank with
absolute paths (do not modify HOME, PATH, user package links or installed tools):

```sh
node Silex/Toolchain/Tools/VerifyRegistryLogin.mjs /absolute/candidate/silex /absolute/php
```

It needs the sibling `Silex-Registry/server/tests/login-router.php`, PHP with the
registry extensions and Node. It creates fresh state below `TestState/cli-login`,
starts loopback-only PHP and hostile-response HTTP fixtures and stops them in a
finally block. The provider is injected only by the registry's test bootstrap;
the production bootstrap has no mock-provider switch.

`SILEX_REGISTRY_TEST_URL` and `SILEX_REGISTRY_TEST_ROOT` are a paired qualification
interface, not multi-registry configuration. Both must be present. The endpoint
must be exactly `http://127.0.0.1:<port>` and the root an existing absolute path
whose real path is strictly below the current group's `TestState`. The test store
is additionally isolated in its own `auth` subdirectory. An incomplete or invalid
pair fails before reaching user state or making a request.

The bank checks login/session reuse, server-side revocation, failure retention,
denial, expiry, provider failure, process interruption and competing mutations,
private paths, test isolation, redirect refusal, payload limits, browser URL
validation, network cancellation and redacted traces. It is separate from
`zig build check` and `zig build test`, because it needs the sibling service and
loopback sockets. It does not replace real GitHub consent with the dedicated
minimal-identity application and the user's own action.

## Portable storage and session bank

```sh
node Silex/Toolchain/Tools/VerifyRegistrySession.mjs /absolute/candidate/silex
```

This complementary bank needs only Node and the candidate CLI. A loopback mock
registry exercises native storage across two processes, corruption and hard-link
rejection, revocation failure retention, denied/expired/consumed attempts,
competing commands, interrupted-process lock release and output redaction.
Windows must persist encrypted bytes and restore them in a second process; POSIX
must enforce 0700/0600 modes. The bank neither overrides user-home variables nor
makes GitHub requests. Its state stays below `TestState/registry-session`.

The existing `native-portability.yml` workflow has a targeted `registry-login`
campaign and a `registry_target` selector. It cross-builds the exact workflow SHA
and executes its artifacts on native macOS x64, Linux ARM64/x64 and Windows
ARM64/x64 runners. Cross-building is not native execution evidence: record the
run and SHA only after successful execution. Branch publication and dispatch
require separate authorization; this campaign creates no release or tag.
