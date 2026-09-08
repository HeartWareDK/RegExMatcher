UNIT HeartWare.RegEx.Matcher;

(*
Copyright © 2026 HeartWare. All rights reserved.

This UNIT is released as **FreeWare for non-commercial use only**: **free as
in "free beer", not free as in "free speech"**. It may be used free of charge
for private, hobby, educational, and other non-commercial purposes, but
remains copyrighted software and is not released under a Free Software or Open
Source license. **Commercial use requires permission from the author; please
contact the author to arrange commercial usage.**

For an explanation of the distinction between *free as in free speech* and
*free as in free beer*, see the [GNU/Free Software Foundation definition of
Free Software][fsf-free-software]. This UNIT deliberately uses **free** in the
latter, **price-related sense**.

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

Consequently, `TRegExMatcherOption` values must be referenced using their enum
type, for example:

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
┌──────────────┬─────────────────────────────────┬────────────────────────────────────┐
│ Mask element │ Without `Unicode`               │ With `Unicode`                     │
├──────────────┼─────────────────────────────────┼────────────────────────────────────┤
│ `#`          │ one ASCII digit `0-9`           │ one Unicode decimal digit          │
│ `$`          │ one or more ASCII digits        │ one or more Unicode decimal digits │
│ `@`          │ one ASCII letter `A-Z` or `a-z` │ one Unicode letter                 │
└──────────────┴─────────────────────────────────┴────────────────────────────────────┘

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

`Unicode` extends the meanings of `#`, `$` and `@` from ASCII digits and
letters to their Unicode equivalents.

`CaseSensitive` changes the entire match from the default case-insensitive
behavior to case-sensitive matching.

The matcher deliberately provides only forward, whole-string mask matching. It
does not expose regular-expression groups, captures, lookarounds,
backreferences or other advanced RegEx constructs. Characters that happen to
be RegEx metacharacters are escaped internally and remain literal unless they
are explicitly part of the mask syntax described above.

[fsf-free-software]: https://www.gnu.org/philosophy/free-sw.html
*)

INTERFACE

USES System.RegularExpressions;

{$SCOPEDENUMS ON}

TYPE
  TRegExMatcherOption   = (HashNumeric,
                           DollarNumeric,
                           StarWildCard,
                           QuestionWildCard,
                           Sets,
                           LineEndings,
                           BackslashEscaping,
                           AlphaAt,
                           Unicode,
                           CaseSensitive);
  TRegExMatcherOptions  = SET OF TRegExMatcherOption;

FUNCTION RegExMatcher(CONST Mask : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : TRegEx;
FUNCTION RegExMatch(CONST Mask,Value : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : BOOLEAN;

TYPE
  TRegExMatcherOptionHelper     = RECORD HELPER FOR TRegExMatcherOption
                                  PRIVATE
                                    PROCEDURE   SetStr(CONST Value : STRING);
                                  PUBLIC
                                    FUNCTION    ToString : STRING; INLINE;
                                    PROPERTY    AsString : STRING Read ToString Write SetStr;
                                    CLASS FUNCTION Create(CONST Value : STRING) : TRegExMatcherOption; static;
                                  END;

FUNCTION RegExMatcherStr(CONST Options : TRegExMatcherOptions) : STRING;
FUNCTION RegExMatcherVal(CONST Value : STRING) : TRegExMatcherOptions;

PROCEDURE UnitTest;

IMPLEMENTATION

USES System.SysUtils, System.RTTI;

FUNCTION RegExMatcher(CONST Mask : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : TRegEx;
  VAR
    I : INTEGER;
    R : STRING;

  FUNCTION NumberPattern : STRING;
    BEGIN
      IF TRegExMatcherOption.Unicode IN Options THEN
        Result:='\p{N}'
      ELSE
        Result:='[0-9]'
    END;

  FUNCTION NumberSetPattern : STRING;
    BEGIN
      IF TRegExMatcherOption.Unicode IN Options THEN
        Result:='\p{N}'
      ELSE
        Result:='0-9'
    END;

  FUNCTION AlphaPattern : STRING;
    BEGIN
      IF TRegExMatcherOption.Unicode IN Options THEN
        Result:='\p{L}'
      ELSE
        Result:='[A-Za-z]'
    END;

  FUNCTION AlphaSetPattern : STRING;
    BEGIN
      IF TRegExMatcherOption.Unicode IN Options THEN
        Result:='\p{L}'
      ELSE
        Result:='A-Za-z'
    END;

  PROCEDURE AddLiteral(C : CHAR);
    BEGIN
      CASE C OF
        '\','.','^','$','|','(',')','[',']','{','}','*','+','?' :
          R:=R+'\'+C
        ELSE
          R:=R+C
      END
    END;

  PROCEDURE AddSetLiteral(VAR S : STRING ; C : CHAR ; Escaped : BOOLEAN);
    BEGIN
      CASE C OF
        '\' :
          S:=S+'\\';

        '[' :
          S:=S+'\[';

        ']' :
          S:=S+'\]';

        '^' :
          S:=S+'\^';

        '-' :
          IF Escaped THEN
            S:=S+'\-'
          ELSE
            S:=S+'-';

        ELSE
          S:=S+C
      END
    END;

  FUNCTION AddSet : BOOLEAN;
    VAR
      J,K : INTEGER;
      Negated : BOOLEAN;
      S : STRING;
      C : CHAR;
    BEGIN
      Result:=FALSE;

      {
        Find the closing "]".

        If BackslashEscaping is enabled, an escaped "]" does not
        terminate the set.
      }

      J:=I+1;

      WHILE J<=Length(Mask) DO BEGIN
        IF (TRegExMatcherOption.BackslashEscaping IN Options) AND
           (Mask[J]='\') AND
           (J<Length(Mask)) THEN
          INC(J,2)
        ELSE IF Mask[J]=']' THEN
          BREAK
        ELSE
          INC(J)
      END;

      IF J>Length(Mask) THEN EXIT;

      K:=I+1;

      {
        A leading, unescaped "!" negates the set.
      }

      Negated:=(K<J) AND (Mask[K]='!');

      IF Negated THEN INC(K);

      {
        [] and [!] are not treated as sets.
      }

      IF K>=J THEN EXIT;

      S:='';

      WHILE K<J DO BEGIN

        {
          Backslash always removes the special meaning of the
          immediately following character.
        }

        IF (TRegExMatcherOption.BackslashEscaping IN Options) AND
           (Mask[K]='\') THEN BEGIN

          IF K+1<J THEN BEGIN
            INC(K);
            AddSetLiteral(S,Mask[K],TRUE)
          END ELSE
            AddSetLiteral(S,'\',TRUE)

        END ELSE BEGIN

          C:=Mask[K];

          CASE C OF

            '#' :
              IF TRegExMatcherOption.HashNumeric IN Options THEN
                S:=S+NumberSetPattern
              ELSE
                AddSetLiteral(S,C,FALSE);

            '$' :
              IF TRegExMatcherOption.DollarNumeric IN Options THEN
                {
                  Inside a set "$" means one numeric character.
                  The "+" semantics would make no sense inside [].
                }
                S:=S+NumberSetPattern
              ELSE
                AddSetLiteral(S,C,FALSE);

            '@' :
              IF TRegExMatcherOption.AlphaAt IN Options THEN
                S:=S+AlphaSetPattern
              ELSE
                AddSetLiteral(S,C,FALSE);

            ELSE
              AddSetLiteral(S,C,FALSE)

          END
        END;

        INC(K)
      END;

      IF Negated THEN
        R:=R+'[^'+S+']'
      ELSE
        R:=R+'['+S+']';

      I:=J;
      Result:=TRUE
    END;

  BEGIN
    R:='\A';

    I:=1;

    WHILE I<=Length(Mask) DO BEGIN

      {
        Backslash escaping gets first priority.

        Thus:
          \*   literal *
          \?   literal ?
          \#   literal #
          \$   literal $
          \@   literal @
          \[   literal [
          \\   literal \
      }

      IF (TRegExMatcherOption.BackslashEscaping IN Options) AND
         (Mask[I]='\') THEN BEGIN

        IF I<Length(Mask) THEN BEGIN
          INC(I);
          AddLiteral(Mask[I])
        END ELSE
          AddLiteral('\')

      END

      {
        CR, LF and CR/LF in the mask are all one logical line ending.
      }

      ELSE IF (TRegExMatcherOption.LineEndings IN Options) AND
              ((Mask[I]=#13) OR (Mask[I]=#10)) THEN BEGIN

        IF (Mask[I]=#13) AND
           (I<Length(Mask)) AND
           (Mask[I+1]=#10) THEN INC(I);

        {
          Atomic grouping is deliberate.

          If the value contains CR/LF, it must be consumed as CR/LF
          and cannot later be backtracked into two separate characters.
        }

        R:=R+'(?>\r\n|\r|\n)'

      END ELSE CASE Mask[I] OF

        '#' :
          IF TRegExMatcherOption.HashNumeric IN Options THEN
            R:=R+NumberPattern
          ELSE
            AddLiteral(Mask[I]);

        '$' :
          IF TRegExMatcherOption.DollarNumeric IN Options THEN
            R:=R+NumberPattern+'+'
          ELSE
            AddLiteral(Mask[I]);

        '@' :
          IF TRegExMatcherOption.AlphaAt IN Options THEN
            R:=R+AlphaPattern
          ELSE
            AddLiteral(Mask[I]);

        '*' :
          IF TRegExMatcherOption.StarWildCard IN Options THEN BEGIN

            IF TRegExMatcherOption.LineEndings IN Options THEN
              {
                One iteration is one logical character.

                CR/LF is tried first and the atomic group prevents
                it from subsequently being split into CR + LF.
              }
              R:=R+'(?>\r\n|[^\r\n]|\r|\n)*'
            ELSE
              R:=R+'[\s\S]*'

          END ELSE
            AddLiteral(Mask[I]);

        '?' :
          IF TRegExMatcherOption.QuestionWildCard IN Options THEN BEGIN

            IF TRegExMatcherOption.LineEndings IN Options THEN
              R:=R+'(?>\r\n|[^\r\n]|\r|\n)'
            ELSE
              R:=R+'[\s\S]'

          END ELSE
            AddLiteral(Mask[I]);

        '[' :
          IF NOT ((TRegExMatcherOption.Sets IN Options) AND AddSet) THEN
            AddLiteral(Mask[I]);

        ELSE
          AddLiteral(Mask[I])

      END;

      INC(I)
    END;

    R:=R+'\z';

    {
      Explicit RegEx options are intentional.

      TRegEx.Create's default is [roNotEmpty], which would make an
      empty mask fail to match an empty string. For mask semantics
      I think "" should match "". Case-insensitive matching is the
      default unless CaseSensitive is explicitly requested.
    }

    IF TRegExMatcherOption.CaseSensitive IN Options THEN
      Result:=TRegEx.Create(R,[])
    ELSE
      Result:=TRegEx.Create(R,[TRegExOption.roIgnoreCase])
  END;

FUNCTION RegExMatch(CONST Mask,Value : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : BOOLEAN;
  BEGIN
    Result:=RegExMatcher(Mask).IsMatch(Value)
  END;

FUNCTION RegExMatcherStr(CONST Options : TRegExMatcherOptions) : STRING;
  VAR
    O : TRegExMatcherOption;

  BEGIN
    Result:='[';
    FOR O:=LOW(TRegExMatcherOption) TO HIGH(TRegExMatcherOption) DO IF O IN Options THEN BEGIN
      IF Length(Result)>1 THEN Result:=Result+',';
      Result:=Result+O.ToString
    END;
    Result:=Result+']'
  END;

FUNCTION RegExMatcherVal(CONST Value : STRING) : TRegExMatcherOptions;
  VAR
    S,N         : STRING;
    A           : TArray<STRING>;

  BEGIN
    Result:=[];
    S:=Value.Trim;
    IF S.IsEmpty THEN EXIT;

    { Allow either [Value,Value] or Value,Value }

    IF S.StartsWith('[') THEN BEGIN
      IF NOT S.EndsWith(']') THEN RAISE EConvertError.CreateFmt('Invalid TRegExMatcherOptions value "%s"',[Value]);
      S:=COPY(S,2,LENGTH(S)-2).Trim
    END ELSE IF S.EndsWith(']') THEN
      RAISE EConvertError.CreateFmt('Invalid TRegExMatcherOptions value "%s"',[Value]);

    IF S.IsEmpty THEN EXIT;

    A:=S.Split([',']);
    FOR N IN A DO
      Include(Result,TRegExMatcherOption.Create(N))
  END;

{ TRegExMatcherOptionHelper }

CLASS FUNCTION TRegExMatcherOptionHelper.Create(CONST Value : STRING) : TRegExMatcherOption;
  BEGIN
    Result.AsString:=Value.Trim
  END;

PROCEDURE TRegExMatcherOptionHelper.SetStr(CONST Value : STRING);
  BEGIN
    VAR R:=TRttiEnumerationType.GetValue<TRegExMatcherOption>(Value);
    IF ORD(R)<0 THEN RAISE EInvalidCast.CreateFmt('Invalid TRegExMatcherOption Value: "%s"',[Value]);
    Self:=R
  END;

FUNCTION TRegExMatcherOptionHelper.ToString : STRING;
  BEGIN
    Result:=TRttiEnumerationType.GetName(Self)
  END;

PROCEDURE UnitTest;
  BEGIN

    { ---------------------------------------------------------------------------
      Basic literal matching / whole-string matching
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('ABC',[]).IsMatch('ABC'),
           'ABC does not match ABC');

    ASSERT(RegExMatcher('ABC',[]).IsMatch('abc'),
           'ABC does not match abc with default case-insensitive matching');

    ASSERT(NOT RegExMatcher('ABC',[]).IsMatch('XABC'),
           'ABC unexpectedly matches XABC');

    ASSERT(NOT RegExMatcher('ABC',[]).IsMatch('ABCX'),
           'ABC unexpectedly matches ABCX');

    ASSERT(NOT RegExMatcher('ABC',[]).IsMatch('XABCX'),
           'ABC unexpectedly matches XABCX');

    ASSERT(RegExMatcher('',[]).IsMatch(''),
           '<empty> does not match <empty>');

    ASSERT(NOT RegExMatcher('',[]).IsMatch('A'),
           '<empty> unexpectedly matches A');


    { ---------------------------------------------------------------------------
      Case sensitivity

      Matching is case-insensitive by default. CaseSensitive restores exact
      case matching, including inside character sets.
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('ABC',[]).IsMatch('abc'),
           'Default matching is unexpectedly case-sensitive');

    ASSERT(RegExMatcher('AbC',[]).IsMatch('aBc'),
           'Default matching does not ignore mixed case');

    ASSERT(NOT RegExMatcher('ABC',[TRegExMatcherOption.CaseSensitive]).IsMatch('abc'),
           'CaseSensitive ABC unexpectedly matches abc');

    ASSERT(RegExMatcher('ABC',[TRegExMatcherOption.CaseSensitive]).IsMatch('ABC'),
           'CaseSensitive ABC does not match ABC');

    ASSERT(RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('a'),
           'Default case-insensitive [A-Z] does not match a');

    ASSERT(NOT RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets,TRegExMatcherOption.CaseSensitive]).IsMatch('a'),
           'CaseSensitive [A-Z] unexpectedly matches a');

    ASSERT(RegExMatcher('[!A-Z]',[TRegExMatcherOption.Sets,TRegExMatcherOption.CaseSensitive]).IsMatch('a'),
           'CaseSensitive [!A-Z] does not match lowercase a');

    ASSERT(NOT RegExMatcher('IMG####.JPG',
           [TRegExMatcherOption.HashNumeric,TRegExMatcherOption.CaseSensitive]).IsMatch('IMG0042.jpg'),
           'CaseSensitive filename mask unexpectedly ignores extension case');

    ASSERT(RegExMatcher('IMG####.JPG',
           [TRegExMatcherOption.HashNumeric]).IsMatch('img0042.jpg'),
           'Default filename mask does not ignore case');


    { ---------------------------------------------------------------------------
      RegEx metacharacters must be literal when they aren't enabled mask tokens
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A.B',[]).IsMatch('A.B'),
           'A.B does not match A.B');

    ASSERT(NOT RegExMatcher('A.B',[]).IsMatch('AXB'),
           'A.B unexpectedly matches AXB');

    ASSERT(RegExMatcher('A+B',[]).IsMatch('A+B'),
           'A+B does not match A+B');

    ASSERT(RegExMatcher('A(B)',[]).IsMatch('A(B)'),
           'A(B) does not match A(B)');

    ASSERT(RegExMatcher('A^B',[]).IsMatch('A^B'),
           'A^B does not match A^B');

    ASSERT(RegExMatcher('A{2}B',[]).IsMatch('A{2}B'),
           'A{2}B does not match A{2}B');


    { ---------------------------------------------------------------------------
      HashNumeric
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('ABC#',[TRegExMatcherOption.HashNumeric]).IsMatch('ABC0'),
           'ABC# does not match ABC0');

    ASSERT(RegExMatcher('ABC#',[TRegExMatcherOption.HashNumeric]).IsMatch('ABC9'),
           'ABC# does not match ABC9');

    ASSERT(NOT RegExMatcher('ABC#',[TRegExMatcherOption.HashNumeric]).IsMatch('ABCA'),
           'ABC# unexpectedly matches ABCA');

    ASSERT(NOT RegExMatcher('ABC#',[TRegExMatcherOption.HashNumeric]).IsMatch('ABC12'),
           'ABC# unexpectedly matches ABC12');

    ASSERT(NOT RegExMatcher('ABC#',[TRegExMatcherOption.HashNumeric]).IsMatch('ABC'),
           'ABC# unexpectedly matches ABC');

    ASSERT(RegExMatcher('ABC#',[]).IsMatch('ABC#'),
           'ABC# does not match literal ABC# when HashNumeric is disabled');

    ASSERT(NOT RegExMatcher('ABC#',[]).IsMatch('ABC1'),
           'ABC# unexpectedly has numeric meaning when HashNumeric is disabled');


    { ---------------------------------------------------------------------------
      DollarNumeric
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('ABC$',[TRegExMatcherOption.DollarNumeric]).IsMatch('ABC0'),
           'ABC$ does not match ABC0');

    ASSERT(RegExMatcher('ABC$',[TRegExMatcherOption.DollarNumeric]).IsMatch('ABC123456'),
           'ABC$ does not match ABC123456');

    ASSERT(NOT RegExMatcher('ABC$',[TRegExMatcherOption.DollarNumeric]).IsMatch('ABC'),
           'ABC$ unexpectedly matches ABC');

    ASSERT(NOT RegExMatcher('ABC$',[TRegExMatcherOption.DollarNumeric]).IsMatch('ABC12X'),
           'ABC$ unexpectedly matches ABC12X');

    ASSERT(RegExMatcher('ABC$',[]).IsMatch('ABC$'),
           'ABC$ does not match literal ABC$ when DollarNumeric is disabled');


    { ---------------------------------------------------------------------------
      AlphaAt - non-Unicode
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt]).IsMatch('A'),
           '@ does not match A');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt]).IsMatch('z'),
           '@ does not match z');

    ASSERT(NOT RegExMatcher('@',[TRegExMatcherOption.AlphaAt]).IsMatch('7'),
           '@ unexpectedly matches 7');

    ASSERT(NOT RegExMatcher('@',[TRegExMatcherOption.AlphaAt]).IsMatch('Æ'),
           '@ unexpectedly matches Æ without Unicode');

    ASSERT(RegExMatcher('@',[]).IsMatch('@'),
           '@ does not match literal @ when AlphaAt is disabled');


    { ---------------------------------------------------------------------------
      Unicode AlphaAt
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('A'),
           'Unicode @ does not match A');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('Æ'),
           'Unicode @ does not match Æ');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('ø'),
           'Unicode @ does not match ø');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('Ж'),
           'Unicode @ does not match Cyrillic letter');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('λ'),
           'Unicode @ does not match Greek letter');

    ASSERT(RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('日'),
           'Unicode @ does not match CJK letter');

    ASSERT(NOT RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('7'),
           'Unicode @ unexpectedly matches 7');

    ASSERT(NOT RegExMatcher('@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('-'),
           'Unicode @ unexpectedly matches -');


    { ---------------------------------------------------------------------------
      Unicode numbers

      Arabic-Indic:
        ٣ = U+0663
        ٧ = U+0667
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('#',[TRegExMatcherOption.HashNumeric,TRegExMatcherOption.Unicode]).IsMatch('٣'),
           'Unicode # does not match Arabic-Indic digit');

    ASSERT(RegExMatcher('$',[TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.Unicode]).IsMatch('٣٧'),
           'Unicode $ does not match Arabic-Indic digits');

    ASSERT(NOT RegExMatcher('#',[TRegExMatcherOption.HashNumeric]).IsMatch('٣'),
           'Non-Unicode # unexpectedly matches Arabic-Indic digit');

    ASSERT(NOT RegExMatcher('$',[TRegExMatcherOption.DollarNumeric]).IsMatch('٣٧'),
           'Non-Unicode $ unexpectedly matches Arabic-Indic digits');


    { ---------------------------------------------------------------------------
      StarWildCard
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard]).IsMatch('AB'),
           'A*B does not match AB');

    ASSERT(RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard]).IsMatch('AXB'),
           'A*B does not match AXB');

    ASSERT(RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard]).IsMatch('A123456B'),
           'A*B does not match A123456B');

    ASSERT(NOT RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard]).IsMatch('A123456C'),
           'A*B unexpectedly matches A123456C');

    ASSERT(RegExMatcher('*',[TRegExMatcherOption.StarWildCard]).IsMatch(''),
           '* does not match empty string');

    ASSERT(RegExMatcher('*',[TRegExMatcherOption.StarWildCard]).IsMatch('Anything'),
           '* does not match Anything');

    ASSERT(RegExMatcher('A*B',[]).IsMatch('A*B'),
           'A*B does not match literal A*B when StarWildCard is disabled');


    { ---------------------------------------------------------------------------
      QuestionWildCard
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard]).IsMatch('AXB'),
           'A?B does not match AXB');

    ASSERT(RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard]).IsMatch('A7B'),
           'A?B does not match A7B');

    ASSERT(NOT RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard]).IsMatch('AB'),
           'A?B unexpectedly matches AB');

    ASSERT(NOT RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard]).IsMatch('AXXB'),
           'A?B unexpectedly matches AXXB');

    ASSERT(RegExMatcher('A?B',[]).IsMatch('A?B'),
           'A?B does not match literal A?B when QuestionWildCard is disabled');


    { ---------------------------------------------------------------------------
      Sets
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('A'),
           '[A-Z] does not match A');

    ASSERT(RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('M'),
           '[A-Z] does not match M');

    ASSERT(RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('Z'),
           '[A-Z] does not match Z');

    ASSERT(RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('a'),
           '[A-Z] does not match a with default case-insensitive matching');

    ASSERT(NOT RegExMatcher('[A-Z]',[TRegExMatcherOption.Sets]).IsMatch('0'),
           '[A-Z] unexpectedly matches 0');

    ASSERT(RegExMatcher('[A-Z0-9]',[TRegExMatcherOption.Sets]).IsMatch('Q'),
           '[A-Z0-9] does not match Q');

    ASSERT(RegExMatcher('[A-Z0-9]',[TRegExMatcherOption.Sets]).IsMatch('7'),
           '[A-Z0-9] does not match 7');

    ASSERT(RegExMatcher('[A-Z0-9]',[TRegExMatcherOption.Sets]).IsMatch('q'),
           '[A-Z0-9] does not match q with default case-insensitive matching');

    ASSERT(NOT RegExMatcher('[!A-Z]',[TRegExMatcherOption.Sets]).IsMatch('a'),
           '[!A-Z] unexpectedly matches a with default case-insensitive matching');

    ASSERT(RegExMatcher('[!A-Z]',[TRegExMatcherOption.Sets]).IsMatch('7'),
           '[!A-Z] does not match 7');

    ASSERT(NOT RegExMatcher('[!A-Z]',[TRegExMatcherOption.Sets]).IsMatch('Q'),
           '[!A-Z] unexpectedly matches Q');

    ASSERT(RegExMatcher('[ABC]',[TRegExMatcherOption.Sets]).IsMatch('B'),
           '[ABC] does not match B');

    ASSERT(NOT RegExMatcher('[ABC]',[TRegExMatcherOption.Sets]).IsMatch('D'),
           '[ABC] unexpectedly matches D');


    { ---------------------------------------------------------------------------
      Magic characters inside sets
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric]).IsMatch('5'),
           '[#] does not match digit');

    ASSERT(NOT RegExMatcher('[#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric]).IsMatch('A'),
           '[#] unexpectedly matches A');

    ASSERT(RegExMatcher('[$]',[TRegExMatcherOption.Sets,TRegExMatcherOption.DollarNumeric]).IsMatch('5'),
           '[$] does not match digit');

    ASSERT(NOT RegExMatcher('[$]',[TRegExMatcherOption.Sets,TRegExMatcherOption.DollarNumeric]).IsMatch('55'),
           '[$] unexpectedly matches two digits');

    ASSERT(RegExMatcher('[@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt]).IsMatch('G'),
           '[@] does not match G');

    ASSERT(RegExMatcher('[@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt]).IsMatch('q'),
           '[@] does not match q');

    ASSERT(NOT RegExMatcher('[@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt]).IsMatch('4'),
           '[@] unexpectedly matches 4');

    ASSERT(RegExMatcher('[@#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('X'),
           '[@#] does not match X');

    ASSERT(RegExMatcher('[@#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('8'),
           '[@#] does not match 8');

    ASSERT(NOT RegExMatcher('[@#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('-'),
           '[@#] unexpectedly matches -');


    { ---------------------------------------------------------------------------
      Unicode magic characters inside sets
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('Æ'),
           'Unicode [@] does not match Æ');

    ASSERT(RegExMatcher('[@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('Ж'),
           'Unicode [@] does not match Cyrillic letter');

    ASSERT(RegExMatcher('[#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.Unicode]).IsMatch('٣'),
           'Unicode [#] does not match Arabic-Indic digit');

    ASSERT(RegExMatcher('[$]',[TRegExMatcherOption.Sets,TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.Unicode]).IsMatch('٧'),
           'Unicode [$] does not match Arabic-Indic digit');

    ASSERT(RegExMatcher('[@#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.Unicode]).IsMatch('ø'),
           'Unicode [@#] does not match ø');

    ASSERT(RegExMatcher('[@#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.Unicode]).IsMatch('٣'),
           'Unicode [@#] does not match Arabic-Indic digit');


    { ---------------------------------------------------------------------------
      Disabled Sets option: [] must be literal
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[A-Z]',[]).IsMatch('[A-Z]'),
           '[A-Z] does not match literally when Sets is disabled');

    ASSERT(NOT RegExMatcher('[A-Z]',[]).IsMatch('A'),
           '[A-Z] unexpectedly acts as a set when Sets is disabled');


    { ---------------------------------------------------------------------------
      Backslash escaping outside sets

      NOTE: Delphi does NOT itself use backslash escaping in string literals.
            Thus '\@' below really contains two characters: "\" and "@".
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('\@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.BackslashEscaping]).IsMatch('@'),
           '\@ does not match literal @');

    ASSERT(NOT RegExMatcher('\@',[TRegExMatcherOption.AlphaAt,TRegExMatcherOption.BackslashEscaping]).IsMatch('A'),
           '\@ unexpectedly acts as AlphaAt');

    ASSERT(RegExMatcher('\#',[TRegExMatcherOption.HashNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('#'),
           '\# does not match literal #');

    ASSERT(NOT RegExMatcher('\#',[TRegExMatcherOption.HashNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('5'),
           '\# unexpectedly acts as HashNumeric');

    ASSERT(RegExMatcher('\$',[TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('$'),
           '\$ does not match literal $');

    ASSERT(NOT RegExMatcher('\$',[TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('123'),
           '\$ unexpectedly acts as DollarNumeric');

    ASSERT(RegExMatcher('\*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.BackslashEscaping]).IsMatch('*'),
           '\* does not match literal *');

    ASSERT(RegExMatcher('\?',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.BackslashEscaping]).IsMatch('?'),
           '\? does not match literal ?');

    ASSERT(RegExMatcher('\[',[TRegExMatcherOption.Sets,TRegExMatcherOption.BackslashEscaping]).IsMatch('['),
           '\[ does not match literal [');

    ASSERT(RegExMatcher('\\',[TRegExMatcherOption.BackslashEscaping]).IsMatch('\'),
           '\\ does not match literal backslash');


    { ---------------------------------------------------------------------------
      Backslash disabled
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('\@',[TRegExMatcherOption.AlphaAt]).IsMatch('\A'),
           '\@ does not treat backslash literally when escaping is disabled');

    ASSERT(NOT RegExMatcher('\@',[TRegExMatcherOption.AlphaAt]).IsMatch('@'),
           '\@ unexpectedly ignores literal backslash when escaping is disabled');


    { ---------------------------------------------------------------------------
      Backslash escaping inside sets
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[\@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.BackslashEscaping]).IsMatch('@'),
           '[\@] does not match literal @');

    ASSERT(NOT RegExMatcher('[\@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.BackslashEscaping]).IsMatch('A'),
           '[\@] unexpectedly treats @ as AlphaAt');

    ASSERT(RegExMatcher('[\#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('#'),
           '[\#] does not match literal #');

    ASSERT(NOT RegExMatcher('[\#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('5'),
           '[\#] unexpectedly treats # as HashNumeric');

    ASSERT(RegExMatcher('[\$]',[TRegExMatcherOption.Sets,TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('$'),
           '[\$] does not match literal $');

    ASSERT(NOT RegExMatcher('[\$]',[TRegExMatcherOption.Sets,TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.BackslashEscaping]).IsMatch('5'),
           '[\$] unexpectedly treats $ as DollarNumeric');

    ASSERT(RegExMatcher('[\-]',[TRegExMatcherOption.Sets,TRegExMatcherOption.BackslashEscaping]).IsMatch('-'),
           '[\-] does not match literal -');

    ASSERT(RegExMatcher('[\]]',[TRegExMatcherOption.Sets,TRegExMatcherOption.BackslashEscaping]).IsMatch(']'),
           '[\]] does not match literal ]');


    { ---------------------------------------------------------------------------
      Multiple mask operators together
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('@-###-$',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.DollarNumeric]).IsMatch('A-123-45678'),
           '@-###-$ does not match A-123-45678');

    ASSERT(NOT RegExMatcher('@-###-$',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.DollarNumeric]).IsMatch('AA-123-45678'),
           '@-###-$ unexpectedly matches AA-123-45678');

    ASSERT(NOT RegExMatcher('@-###-$',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.DollarNumeric]).IsMatch('A-12-45678'),
           '@-###-$ unexpectedly matches A-12-45678');

    ASSERT(NOT RegExMatcher('@-###-$',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.DollarNumeric]).IsMatch('A-123-'),
           '@-###-$ unexpectedly matches A-123-');


    { ---------------------------------------------------------------------------
      LineEndings: explicit line ending in mask

      Every CR, LF or CRLF in the MASK represents precisely one logical
      line ending in the VALUE.
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A'+#13+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13+'B'),
           'CR mask does not match CR value');

    ASSERT(RegExMatcher('A'+#13+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#10+'B'),
           'CR mask does not match LF value');

    ASSERT(RegExMatcher('A'+#13+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13#10+'B'),
           'CR mask does not match CRLF value');

    ASSERT(RegExMatcher('A'+#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13+'B'),
           'LF mask does not match CR value');

    ASSERT(RegExMatcher('A'+#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#10+'B'),
           'LF mask does not match LF value');

    ASSERT(RegExMatcher('A'+#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13#10+'B'),
           'LF mask does not match CRLF value');

    ASSERT(RegExMatcher('A'+#13#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13+'B'),
           'CRLF mask does not match CR value');

    ASSERT(RegExMatcher('A'+#13#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#10+'B'),
           'CRLF mask does not match LF value');

    ASSERT(RegExMatcher('A'+#13#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch('A'+#13#10+'B'),
           'CRLF mask does not match CRLF value');


    { ---------------------------------------------------------------------------
      LineEndings: one logical line ending must NOT consume two line endings
      --------------------------------------------------------------------------- }

    ASSERT(NOT RegExMatcher('A'+#13+'B',[TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#10#13#10+'B'),
           'One mask line ending unexpectedly matches two CRLFs');

    ASSERT(NOT RegExMatcher('A'+#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#10#10+'B'),
           'One mask line ending unexpectedly matches two LFs');

    ASSERT(NOT RegExMatcher('A'+#13#10+'B',[TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#13+'B'),
           'One mask line ending unexpectedly matches two CRs');


    { ---------------------------------------------------------------------------
      LineEndings: without option they remain literal
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A'+#13+'B',[]).IsMatch('A'+#13+'B'),
           'Literal CR does not match CR');

    ASSERT(NOT RegExMatcher('A'+#13+'B',[]).IsMatch('A'+#10+'B'),
           'Literal CR unexpectedly matches LF without LineEndings');

    ASSERT(NOT RegExMatcher('A'+#13+'B',[]).IsMatch('A'+#13#10+'B'),
           'Literal CR unexpectedly matches CRLF without LineEndings');


    { ---------------------------------------------------------------------------
      ? with LineEndings: CRLF is ONE logical character
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13+'B'),
           '? does not match CR as one logical character');

    ASSERT(RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#10+'B'),
           '? does not match LF as one logical character');

    ASSERT(RegExMatcher('A?B',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#10+'B'),
           '? does not match CRLF as one logical character');

    ASSERT(NOT RegExMatcher('A??B',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#10+'B'),
           'Two ? unexpectedly split one CRLF into two characters');


    { ---------------------------------------------------------------------------
      * with LineEndings
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#10+'B'),
           '* does not match CRLF');

    ASSERT(RegExMatcher('A*B',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           'A'+#13#10+'X'+#10+'YB'),
           '* does not match text containing multiple line endings');

    ASSERT(RegExMatcher('*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           #13#10),
           '* does not match one CRLF');


    { ---------------------------------------------------------------------------
      Aggressive CRLF handling around adjacent wildcards

      These specifically test that CRLF is not split into CR and LF to satisfy
      two separate one-character mask constructs.
      --------------------------------------------------------------------------- }

    ASSERT(NOT RegExMatcher('??',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(#13#10),
           '?? unexpectedly splits CRLF into two logical characters');

    ASSERT(RegExMatcher('?',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(#13#10),
           '? does not treat CRLF as one logical character');

    ASSERT(RegExMatcher('?*',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.StarWildCard,TRegExMatcherOption.LineEndings]).IsMatch(
           #13#10),
           '?* does not match one logical CRLF');

    ASSERT(NOT RegExMatcher('??',[TRegExMatcherOption.QuestionWildCard,TRegExMatcherOption.LineEndings]).IsMatch(#13),
           '?? unexpectedly matches one CR');


    { ---------------------------------------------------------------------------
      Sets + negation + magic tokens
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[!#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric]).IsMatch('A'),
           '[!#] does not match non-digit');

    ASSERT(NOT RegExMatcher('[!#]',[TRegExMatcherOption.Sets,TRegExMatcherOption.HashNumeric]).IsMatch('5'),
           '[!#] unexpectedly matches digit');

    ASSERT(RegExMatcher('[!@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt]).IsMatch('5'),
           '[!@] does not match non-alpha');

    ASSERT(NOT RegExMatcher('[!@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt]).IsMatch('Q'),
           '[!@] unexpectedly matches alpha');

    ASSERT(RegExMatcher('[!@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('5'),
           'Unicode [!@] does not match digit');

    ASSERT(NOT RegExMatcher('[!@]',[TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.Unicode]).IsMatch('Æ'),
           'Unicode [!@] unexpectedly matches Æ');


    { ---------------------------------------------------------------------------
      Range edge cases
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('[-A]',[TRegExMatcherOption.Sets]).IsMatch('-'),
           '[-A] does not match -');

    ASSERT(RegExMatcher('[A-]',[TRegExMatcherOption.Sets]).IsMatch('-'),
           '[A-] does not match -');

    ASSERT(RegExMatcher('[A-C]',[TRegExMatcherOption.Sets]).IsMatch('B'),
           '[A-C] does not match B');

    ASSERT(NOT RegExMatcher('[A-C]',[TRegExMatcherOption.Sets]).IsMatch('D'),
           '[A-C] unexpectedly matches D');


    { ---------------------------------------------------------------------------
      Useful realistic combinations
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('IMG####.JPG',
           [TRegExMatcherOption.HashNumeric]).IsMatch('IMG0042.JPG'),
           'IMG####.JPG does not match IMG0042.JPG');

    ASSERT(NOT RegExMatcher('IMG####.JPG',
           [TRegExMatcherOption.HashNumeric]).IsMatch('IMG042.JPG'),
           'IMG####.JPG unexpectedly matches IMG042.JPG');

    ASSERT(RegExMatcher('File-$.*',
           [TRegExMatcherOption.DollarNumeric,TRegExMatcherOption.StarWildCard]).IsMatch('File-12345.txt'),
           'File-$.* does not match File-12345.txt');

    ASSERT(RegExMatcher('@@@-###',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('ABC-123'),
           '@@@-### does not match ABC-123');

    ASSERT(NOT RegExMatcher('@@@-###',
           [TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('AB1-123'),
           '@@@-### unexpectedly matches AB1-123');

    ASSERT(RegExMatcher('User-[@#][@#][@#]',
           [TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('User-A7z'),
           'User-[@#][@#][@#] does not match User-A7z');

    ASSERT(RegExMatcher('User-[@#][@#][@#]',
           [TRegExMatcherOption.Sets,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric,TRegExMatcherOption.Unicode]).IsMatch('User-Æ٣ø'),
           'Unicode User mask does not match User-Æ٣ø');

  END;

END.

