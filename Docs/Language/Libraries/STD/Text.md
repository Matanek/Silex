# Text

`STD.Text` exposes locale-independent Unicode transformations pinned to
Unicode 17.0.0. `normalize(text, form)` implements NFC, NFD, NFKC, and NFKD;
`is_normalized` is exactly the comparison with that transformation.
`lowercase` and `uppercase` apply the complete default mappings, including
multi-scalar expansions and the context-sensitive final Greek sigma.
`case_fold` applies full default case folding for caseless comparison.
`unicode_version()` returns `"17.0.0"`.

These calls do not change intrinsic `str` equality: callers explicitly choose
normalization or folding. They do not perform locale-tailored casing,
collation, transliteration, IDNA, or diacritic removal.

`STD.Text.UTF8` exposes exact conversions between Silex `str`, UTF-8 bytes,
and Unicode scalar values. A byte is one encoded `uint8`; a scalar is one
Unicode code point represented as `uint32`. Neither is a user-perceived
grapheme.

`bytes(text)` returns an independent copy of the internal UTF-8 bytes,
including null bytes. `decode(values)` accepts only shortest-form UTF-8,
rejects surrogates and values above U+10FFFF, and returns the first offending
byte offset in `DecodeError`. Invalid external data is a recoverable
`Result.failure`, never a fatal native string conversion.

`scalars(text)` returns every scalar in order. `from_scalars(values)` encodes
them or reports the first surrogate or out-of-range scalar index. Both
round-trips are exact and perform no normalization, case conversion, or
replacement. The intrinsic `str.count()` continues to count scalars.

Silex compiles its distributed utf8proc 2.11.3 sources and generated default
casing tables for the requested target. The tables derive from Unicode 17.0.0
data distributed beside the native source; neither build nor execution reads
the host locale or downloads Unicode data. The bundled `LICENSE.md` covers
utf8proc and the derived Unicode data.

`STD.Text.Grapheme` segments default extended grapheme clusters with UAX #29
for the same Unicode version. `boundaries(text)` returns increasing UTF-8 byte
offsets, always beginning at zero and ending at the byte length for nonempty
text. `count(text)` derives the cluster count. `split(text)` returns independent
copies whose concatenation preserves the original bytes. Empty text has
boundaries `[0]` and no segments. These operations do not normalize text,
compute display width, or change scalar-based `str.count()`.

`STD.Text.Encoding` transcodes `str` to explicit UTF-8, UTF-16 LE/BE, and
UTF-32 LE/BE byte arrays. `encode` never emits a BOM;
`encode_with_bom` always emits the selected signature. `decode` accepts a
matching BOM or no BOM, rejects a different complete BOM at byte zero, and
reports strict length, surrogate, sequence, and range failures with the first
offending byte offset. `detect_bom` recognizes only complete signatures and
prefers UTF-32 signatures over their UTF-16 prefixes. No operation uses
`wchar_t`, a system locale, heuristic detection, replacement, or normalization.
