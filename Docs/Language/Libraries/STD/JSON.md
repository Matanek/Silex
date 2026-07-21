# JSON

`STD.JSON` exposes an immutable six-kind DOM. `Value` factories create null,
boolean, string, exact-number, array, and ordered-object nodes. Arrays and
object accessors return fresh lists of immutable references. Object construction
and parsing reject member names duplicated after escape decoding.

`parse` accepts exactly RFC 8259 JSON: JSON whitespace only, strict escapes and
surrogate pairs, exact number grammar, no comments or trailing commas, and no
data after the root. Errors identify the first byte offset plus one-based scalar
line and column. Container depth defaults to 128 and can be bounded explicitly.

Numbers retain their validated source lexeme, including integers beyond native
ranges. Integer factories emit minimal decimal text; finite `float64` values use
the shortest round-trippable IEEE representation and non-finite values fail.

`stringify(..., compact)` adds no whitespace. `pretty` uses LF, two spaces per
level, one member or element per line, and keeps empty containers on one line.
Object order and number lexemes are preserved; control characters, quote, and
backslash are escaped while other UTF-8 scalars are emitted directly.
