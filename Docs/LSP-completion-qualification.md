# LSP completion qualification

This file records one reproducible external-corpus observation. It is evidence
for the admitted toolchain revision, not a frozen expectation for future
package contents. The durable pass/fail rules live in the LSP tests and in the
`check-lsp-completion` and `audit-lsp-completion` build steps.

## Campaign input

- Date: 2026-09-09
- Target: macOS 26.6.2, arm64, Zig ReleaseSafe
- Workspace roots: `Silex`, `Silex-Examples`, `Packages`, `Sandbox`
- Package manifests: 57 sorted `Package.json` files
- Manifest-list SHA-256: `1f5fc933b897907256c783274d90d605c1c32746e7c9008d712de86f1de0dd9d`
- Silex candidate: branch `spec-silex-lsp-completion-guarantees`; use this
  document's introducing commit for the exact revision

Repository closure:

```text
Silex-Examples              6dcc7fdcbc85c911c536e7412fd6831be59f9683
Packages/AI                 f342ad184aa493d83a59b6533e80984e86d73361
Packages/GFX.Animation      7c719bb2770de51849f97dd58ff3f477d1ea10a4
Packages/GFX.Application    a752087d537f59c96d4d724dc1fda1977bf28cd5
Packages/GFX.Assets         907960397db0f0d300e6fc895fa8d5635a0aad01
Packages/GFX.Audio          8096161adc4c627092fe69a48f3e454544d949d9
Packages/GFX.Canvas         c64f73da05b82bcdaf9bb493fa7fd984213bd741
Packages/GFX.ECS            22544631fe7c112d99a0889994e261387b4a9667
Packages/GFX.Font           e520dd899ac5a2598bdb646ee270baa49c1f301c
Packages/GFX.GPU            43db95baa0abfad4ee3f1990323c7493aae03a30
Packages/GFX.Physics        ab63f10d70e7afae2d3bfa5cff51e405c1197536
Packages/GFX.Rendering      542b366ca071a8a0bd9451ea6a500e60b4e290f8
Packages/GFX.Scene2D        73393df8f7ce04e64a66eb3b3ff56eeeee7c7880
Packages/GFX.Scene3D        3f060c819554f3f3d2ffec50e9de5e3c4b2c4b3f
Packages/GFX.Stats          b13785e8630db2b73cd7a43cac2b8bbe4b7281e2
Packages/GFX.UI.Terminal    1086d5040237455c9777250233850eaa360f2a66
Packages/GFX.UI             80f758aa9f615d6ff86ce6b49891781801325eb2
Packages/GFX.Viewer         f9bec08fc6b7d896c8ffe72e337a8b37c9027bb7
Packages/GFX.WebView        197dd6863f5ca9360600d28ddd3f8ea1dc7551f4
Packages/GFX                1b5084f7d8605a678df2a0ff7da46af3d692a20c
Packages/HTML               cd16f2705d38819f4bfd2a55da171ae6206e4122
Packages/HTTP               a889ec7c7b7d0e9cf0a276cefb5e6f6bb39545be
Packages/Image              753f9f6c584481626905fe2ea3ba8da957ae4ae5
Packages/JSON               e5eae6c2ca9a7244df3c09e531ca1c818010e32a
Packages/Plot               b03db956f1f8a45ddedfeb8e4217e35c3aa9d34c
Packages/STD                80aabd9a2de919af52dc0b8bf2d0f9de50aa75c5
Packages/Sync               e27120158e8a18b72bd36318369110b9ab431592
Packages/Tensor             332a1878e8928caf93a2cdd042b0cf50a9659a18
Packages/XML                6ef85c4ac4440ad10857fae483fc94be4d70e4e0
Packages/YAML               d3f3650028e814903b909eab43e6081d26cdec9e
```

## Deterministic report

Two consecutive runs returned the same report:

```text
source_files                    1018
source_bytes                    6081449
fingerprint                     37aef170edccfeda
use_path                        4158
member_or_qualified_path        112453
cascade                         3982
safe_member                     4
parenthesized_site              94120
generic_or_comparison           9517
label_or_type_annotation        35383
indexed_or_collection_site      15611
interpolation                   1174
extension                       19
contribution                    24
alias                           5487
public_visibility               2011
package_visibility              739
module_visibility               512
local_visibility                173
protected_visibility            5
private_visibility              2222
```

The source fingerprint includes each sorted relative path, a separator, and
the complete source bytes. The manifest hash is produced from the sorted,
relative-path `shasum -a 256` list. A future corpus change is expected to alter
these observations; admission requires every closed signal to remain
represented and every semantic contract to remain green, not preservation of
these exact counts.
