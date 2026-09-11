Copyright © 2026 HeartWare. All rights reserved.

This UNIT is released under the **HeartWare FreeWare License**.

You may freely use, copy, modify, and redistribute this software and its
source code for private, hobby, educational, and other non-commercial
purposes.

You may not use, sell, distribute, include, publish, bundle, or otherwise
make this software, or any modified or derivative version of it, available
in any commercial context without prior permission from HeartWare. This
includes direct or indirect commercial use or distribution, including paid
download sites, subscription services, commercial software collections,
magazines, books, paid media, or products or services for which money is
charged.

If you redistribute a modified or derivative version, it must be released
under this **exact same license**. You may neither add nor remove
permissions, restrictions, or licensing terms.

The copyright notice and this license must remain with all redistributed
copies and derivative versions.

**Commercial use requires separate permission from HeartWare.**

The software is provided "as is", without warranty of any kind.

If you are not completely satisfied, return it to where you obtained it for
a full monetary refund of the price you paid for it.

---

# RegExMatcher

`RegExMatcher` converts a simple wildcard-style mask into a Delphi `TRegEx`.

```delphi
FUNCTION RegExMatcher(
  CONST Mask    : LongString;
  CONST Options : TRegExMatcherOptions =
    [TRegExMatcherOption.StarWildCard,
     TRegExMatcherOption.QuestionWildCard]
) : TRegEx;
```

The matcher is intended to provide a convenient middle ground between simple
`*` / `?` wildcard matching and writing a regular expression directly.

The generated regular expression always matches the **entire value**. A mask
therefore describes a complete string, not a substring to search for.

By default, matching is **case-insensitive**. Include `CaseSensitive` when an
exact case-sensitive match is required.

For example:

```text
Mask:  ABC
```

matches:

```text
ABC
abc
AbC
```

but does not match:

```text
XABC
ABCX
XABCX
```

If you want to do a "Contains" instead of an "Equals", prefix and suffix the
match with '*' and make sure to include StarWildCard in the options, like this:

```text
Mask:  *ABC*
```

matches:

```text
ABC
abc
AbC
XABC
ABCX
XABCX
```

Unless given a special meaning by one of the options described below,
characters in the mask are treated as **literal characters**.
Regular-expression metacharacters therefore have no special RegEx meaning
merely because they occur in a mask.

---

# Options

The available options are:

```delphi
TYPE
  TRegExMatcherOption = (
    HashNumeric,
    DollarNumeric,
    StarWildCard,
    QuestionWildCard,
    Sets,
    LineEndings,
    BackslashEscaping,
    AlphaAt,
    Unicode,
    CaseSensitive
  );

  TRegExMatcherOptions = SET OF TRegExMatcherOption;
```

The default options are:

```delphi
[TRegExMatcherOption.StarWildCard,
 TRegExMatcherOption.QuestionWildCard]
```

so, by default, the matcher behaves much like a conventional `*` / `?`
wildcard matcher, with **case-insensitive** matching.

---

# Scoped enums

The UNIT is compiled with:

```delphi
{$SCOPEDENUMS ON}
```

Consequently, `TRegExMatcherOption` values must be referenced using their
enum type, for example:

```delphi
TRegExMatcherOption.HashNumeric
TRegExMatcherOption.StarWildCard
TRegExMatcherOption.CaseSensitive
```

and option sets are written, for example, as:

```delphi
[TRegExMatcherOption.HashNumeric,
 TRegExMatcherOption.Unicode,
 TRegExMatcherOption.CaseSensitive]
```

---

## `CaseSensitive`

Matching is **case-insensitive by default**. Including `CaseSensitive` changes
the entire match to case-sensitive matching; it is a global option and
therefore affects literal text, ranges and sets alike. For example,
without `CaseSensitive`, `ABC` matches `abc` and `[A-Z]` matches `a`;
with `CaseSensitive`, those matches fail.

---

## `StarWildCard`

When enabled:

```text
*
```

matches **zero or more characters**.

Examples:

```text
Mask: A*B

Matches:
    AB
    AXB
    A123B
    AHello WorldB
```

When `StarWildCard` is not enabled, `*` is simply a literal asterisk.

When `LineEndings` is also enabled, a CR/LF pair is treated as one logical
entity while `*` processes the input.

---

## `QuestionWildCard`

When enabled:

```text
?
```

matches **exactly one character**.

Examples:

```text
Mask: A?B

Matches:
    AXB
    A7B

Does not match:
    AB
    AXXB
```

When `QuestionWildCard` is not enabled, `?` is a literal question mark.

When `LineEndings` is also enabled, CR, LF and CR/LF each constitute **one
logical character**.

Thus:

```text
Mask: A?B
```

matches all three of:

```text
A<CR>B
A<LF>B
A<CR><LF>B
```

A CR/LF pair is never split so that its CR and LF can satisfy two separate `?`
wildcards.

Consequently:

```text
Mask: ??
Value: <CR><LF>
```

does **not** match when `LineEndings` is enabled.

---

## `HashNumeric`

When enabled:

```text
#
```

matches **exactly one digit**.

Without the `Unicode` option this means:

```text
0-9
```

Examples:

```text
Mask: IMG####.JPG

Matches:
    IMG0001.JPG
    IMG1234.JPG

Does not match:
    IMG123.JPG
    IMG12A4.JPG
```

When `HashNumeric` is disabled, `#` is a literal hash character.

When `Unicode` is also enabled, `#` matches a Unicode decimal digit rather
than only ASCII `0` through `9`.

This includes, for example, decimal digits from writing systems such as
Arabic-Indic and Devanagari.

---

## `DollarNumeric`

When enabled:

```text
$
```

matches **one or more digits**.

Without `Unicode`, this is equivalent to:

```text
[0-9]+
```

Examples:

```text
Mask: File-$

Matches:
    File-1
    File-42
    File-123456789

Does not match:
    File-
    File-12A
```

When `DollarNumeric` is disabled, `$` is a literal dollar sign.

When `Unicode` is enabled, `$` accepts one or more Unicode decimal digits.

### `$` inside a set

A set always matches exactly **one character**, so `$` cannot retain its "one
or more" meaning inside a set.

Thus:

```text
[$]
```

means:

```text
one numeric character
```

and is therefore equivalent to `[#]` when both corresponding numeric options
are enabled.

---

## `AlphaAt`

When enabled:

```text
@
```

matches **exactly one alphabetic character**.

Without `Unicode`, this means:

```text
A-Z
a-z
```

Examples:

```text
Mask: @@@-###

Matches:
    ABC-123
    abc-456
    AbZ-007

Does not match:
    AB1-123
    ABC-12X
```

When `AlphaAt` is disabled, `@` is a literal at-sign.

When `Unicode` is also enabled, `@` matches any Unicode letter rather than
only ASCII `A-Z` and `a-z`.

This includes letters such as:

```text
Æ
ø
é
λ
Ж
日
```

---

# Unicode

`Unicode` modifies the meaning of the numeric and alphabetic mask elements.

It does nothing by itself.

Its effect is:
```text
┌──────────────┬─────────────────────────────────┬────────────────────────────────────┐
│ Mask element │ Without `Unicode`               │ With `Unicode`                     │
├──────────────┼─────────────────────────────────┼────────────────────────────────────┤
│ `#`          │ one ASCII digit `0-9`           │ one Unicode decimal digit          │
│ `$`          │ one or more ASCII digits        │ one or more Unicode decimal digits │
│ `@`          │ one ASCII letter `A-Z` or `a-z` │ one Unicode letter                 │
└──────────────┴─────────────────────────────────┴────────────────────────────────────┘
```

For example:

```text
Options:
    HashNumeric
    AlphaAt
    Unicode
```

allow:

```text
@###
```

to match a Unicode letter followed by three Unicode decimal digits.

`Unicode` also affects `#`, `$` and `@` when they occur inside a set.

For example:

```text
[@#]
```

with:

```text
Sets
AlphaAt
HashNumeric
Unicode
```

matches one character which is either a Unicode letter or a Unicode decimal
digit.

Because Unicode letters already include `A-Z` and `a-z`, a construct such as:

```text
[A-Z@]
```

is legal but redundant when both `AlphaAt` and `Unicode` are enabled.

In that situation:

```text
[@]
```

already includes `A-Z`.

---

# Sets

When `Sets` is enabled, square brackets describe a set of characters, similar
to a regular-expression character class.

For example:

```text
[A-Z]
```

matches one character from `A` through `Z`; because matching is
case-insensitive by default, it also matches `a` through `z` unless
`CaseSensitive` is enabled.

Multiple ranges or individual characters may be combined:

```text
[A-Z0-9]
```

matches one ASCII letter or one ASCII digit. With `CaseSensitive`, the
alphabetic range is restricted to uppercase `A` through `Z`.

```text
[ABCxyz]
```

matches any one of the listed letters. By default, case differences are
ignored; include `CaseSensitive` if the exact letter case matters.

A set always consumes **exactly one character**.

---

## Negated sets

A leading `!` negates a set:

```text
[!A-Z]
```

matches any one character which is **not** in the `A-Z` range, taking the
global case-sensitivity setting into account.

With the default case-insensitive matching:

```text
Matches:
    7
    -

Does not match:
    A
    Q
    Z
    a
    q
    z
```

With `CaseSensitive` enabled, lowercase letters are no longer part of the
excluded `A-Z` range.

The `!` has this special meaning only as the first character of the set.

---

## Magic characters inside sets

If their corresponding options are enabled, `#`, `$` and `@` retain useful
special meanings inside sets.

For example:

```text
[#]
```

means one numeric character when `HashNumeric` is enabled.

```text
[$]
```

means one numeric character when `DollarNumeric` is enabled.

```text
[@]
```

means one alphabetic character when `AlphaAt` is enabled.

They can be combined:

```text
[@#]
```

means one alphabetic or numeric character.

With `Unicode` enabled, the corresponding Unicode character classes are used.

For example:

```text
[@#]
```

with:

```text
Sets
AlphaAt
HashNumeric
Unicode
```

means:

```text
one Unicode letter or Unicode decimal digit
```

Magic characters whose corresponding option is not enabled are treated
literally.

---

# Backslash escaping

When `BackslashEscaping` is enabled, a backslash removes the special meaning
of the character immediately following it.

This makes it possible to request literal versions of characters which would
otherwise have special mask meanings.

For example:

```text
\*
```

means a literal `*`, even when `StarWildCard` is enabled.

Likewise:

```text
\?    literal ?
\#    literal #
\$    literal $
\@    literal @
\[    literal [
\\    literal \
```

For example:

```text
Mask: File-\#-$

Options:
    HashNumeric
    DollarNumeric
    BackslashEscaping
```

matches:

```text
File-#-12345
```

The first `#` is escaped and is therefore literal, while `$` retains its
numeric meaning.

If `BackslashEscaping` is **not** enabled, a backslash has no special
mask-language meaning and is treated as an ordinary literal character.

---

## Escaping inside sets

Backslash escaping also applies inside sets.

For example:

```text
[\@]
```

matches a literal `@`, even if `AlphaAt` is enabled.

Compare:

```text
[@]
```

which means:

```text
one alphabetic character
```

with:

```text
[\@]
```

which means:

```text
the literal character @
```

Similarly:

```text
[\#]
```

matches a literal `#`, and:

```text
[\$]
```

matches a literal `$`.

A hyphen must be escaped when a literal hyphen is required:

```text
[\-]
```

and an otherwise special closing bracket must likewise be escaped:

```text
[\]]
```

---

# Line endings

When `LineEndings` is enabled, the following three representations are
considered equivalent logical line endings:

```text
CR       #13
LF       #10
CR/LF    #13#10
```

Any one of these in the mask matches exactly **one** of any of these forms in
the value.

For example, a mask containing:

```delphi
'A'+#13+'B'
```

matches values containing:

```delphi
'A'+#13+'B'
'A'+#10+'B'
'A'+#13#10+'B'
```

The same applies if the mask itself contains LF or CR/LF.

Thus these three masks are semantically equivalent when `LineEndings` is
enabled:

```delphi
'A'+#13+'B'
'A'+#10+'B'
'A'+#13#10+'B'
```

---

## CR/LF is indivisible

Line-ending matching is deliberately aggressive.

A CR/LF pair occurring in the value is considered a **single logical line
ending** and is never split into two characters merely to make the rest of a
mask succeed.

For example:

```text
Mask:
    ??

Value:
    <CR><LF>
```

does **not** match when both `QuestionWildCard` and `LineEndings` are enabled.

The CR/LF value contains one logical entity, while the mask requires two.

Likewise, one explicit line ending in the mask cannot consume two consecutive
line endings in the value.

---

## Line endings and wildcards

With `LineEndings` enabled, wildcards understand logical line endings as well.

`?` matches:

```text
one normal character
or one CR
or one LF
or one CR/LF pair
```

as exactly one logical character.

`*` can consume any number of normal characters and logical line endings.

This allows masks to operate naturally on both Unix-style LF text and
Windows-style CR/LF text without having to know which convention was used by
the value.

When `LineEndings` is not enabled, CR and LF remain ordinary, distinct literal
characters.

---

# Option interaction

Mask elements only acquire special meaning if their corresponding options are
enabled.

For example:

```text
Mask: @#-$*
```

with no options enabled means exactly the literal text:

```text
@#-$*
```

With:

```delphi
[TRegExMatcherOption.AlphaAt,
 TRegExMatcherOption.HashNumeric,
 TRegExMatcherOption.DollarNumeric,
 TRegExMatcherOption.StarWildCard]
```

the same mask means:

```text
one letter
one digit
literal "-"
one or more digits
zero or more arbitrary characters
```

Backslash escaping has priority over other mask syntax.

Therefore:

```text
\@
```

is always a literal `@` when `BackslashEscaping` is enabled, regardless of
whether `AlphaAt` is also enabled.

The same principle applies inside sets.

`CaseSensitive` is global rather than tied to a particular mask token: if
present, the complete generated regular expression is matched
case-sensitively.

---

# Examples

### Filename mask

```text
Mask:
    IMG####.JPG

Options:
    HashNumeric
```

Matches, by default:

```text
IMG0001.JPG
IMG4711.JPG
img4711.jpg
```

Add `CaseSensitive` if only the exact `IMG....JPG` case should match.

---

### Variable-length number

```text
Mask:
    Invoice-$

Options:
    DollarNumeric
```

Matches:

```text
Invoice-1
Invoice-42
Invoice-123456
invoice-42
```

Add `CaseSensitive` to reject the lowercase form.

---

### Alphanumeric identifier

```text
Mask:
    @@@-###

Options:
    AlphaAt
    HashNumeric
```

Matches:

```text
ABC-123
abc-007
AbZ-471
```

---

### Character set

```text
Mask:
    File-[A-Z#]

Options:
    Sets
    HashNumeric
    CaseSensitive
```

Matches:

```text
File-A
File-Q
File-0
File-9
```

Does not match:

```text
File-a
File--
```

Without `CaseSensitive`, `File-a` also matches.

---

### Unicode alphanumeric character

```text
Mask:
    [@#]

Options:
    Sets
    AlphaAt
    HashNumeric
    Unicode
```

matches any single Unicode letter or Unicode decimal digit.

---

### Literal mask operators

```text
Mask:
    Price-\$*

Options:
    DollarNumeric
    StarWildCard
    BackslashEscaping
```

Here `\$` is a literal dollar sign while `*` remains a wildcard.

---

# Summary

With all syntax options enabled, the principal syntax is:

```text
┌─────────────────┬───────────────────────────────────────────────────────────┬──────────────────────────────┐
│ Syntax          │ Meaning                                                   │ Option(s)                    │
├─────────────────┼───────────────────────────────────────────────────────────┼──────────────────────────────┤
│ `*`             │ zero or more logical characters                           │ StarWildCard                 │
│ `?`             │ exactly one logical character                             │ QuestionWildCard             │
│ `#`             │ exactly one numeric digit                                 │ HashNumeric                  │
│ `$`             │ one or more numeric digits                                │ DollarNumeric                │
│ `@`             │ exactly one alphabetic character                          │ AlphaAt                      │
│ `[ABC]`         │ one character from the set                                │ Sets                         │
│ `[A-Z]`         │ one character from range; case depends on `CaseSensitive` │ Sets                         │
│ `[A-Z0-9]`      │ one character from either range                           │ Sets                         │
│ `[!A-Z]`        │ one character not in the set/range                        │ Sets                         │
│ `[#]`           │ one numeric character                                     │ Sets + HashNumeric           │
│ `[$]`           │ one numeric character                                     │ Sets + DollarNumeric         │
│ `[@]`           │ one alphabetic character                                  │ Sets + AlphaAt               │
│ `[@#]`          │ one alphabetic or numeric character                       │ Sets + AlphaAt + HashNumeric │
│ `\*`            │ literal `*`                                               │ BackslashEscaping            │
│ `\?`            │ literal `?`                                               │ BackslashEscaping            │
│ `\#`            │ literal `#`                                               │ BackslashEscaping            │
│ `\$`            │ literal `$`                                               │ BackslashEscaping            │
│ `\@`            │ literal `@`                                               │ BackslashEscaping            │
│ `\\`            │ literal `\`                                               │ BackslashEscaping            │
│ CR, LF or CR/LF │ one logical line ending when `LineEndings` is enabled     │ LineEndings                  │
└─────────────────┴───────────────────────────────────────────────────────────┴──────────────────────────────┘
```

`Unicode` extends the meanings of `#`, `$` and `@` from ASCII digits and
letters to their Unicode equivalents.

`CaseSensitive` changes the entire match from the default case-insensitive
behavior to case-sensitive matching.

The matcher deliberately provides only forward, whole-string mask matching. It
does not expose regular-expression groups, captures, lookarounds,
backreferences or other advanced RegEx constructs. Characters that happen to
be RegEx metacharacters are escaped internally and remain literal unless they
are explicitly part of the mask syntax described above.
