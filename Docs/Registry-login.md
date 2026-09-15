# Registry identity client qualification

`Toolchain/Sources/RegistryLogin.zig` owns the experimental identity client;
`Main.zig` only dispatches `login` and `logout`. Public usage documentation belongs
to `Silex-Documentation/FR/Tools/Registry-login.md` (English translation pending
French editorial approval). This is not a deployed service or an OAuth proof.

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
directory. Logout revokes before deleting and synchronizing. The store protects
against other ordinary local users, not a compromised user account or privileged
process. Windows refuses before creating state: POSIX modes do not provide a
Windows ACL guarantee. macOS is the tested host; Linux and Windows qualification
remain explicit work, not implied portability claims.

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
loopback sockets. Real GitHub consent must still be qualified with the dedicated
minimal-identity application and the user's own action.
