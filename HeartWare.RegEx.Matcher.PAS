UNIT HeartWare.RegEx.Matcher;

(*
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
charged. It also includes putting this software or links to it on sites
that are supported by ads.

If you redistribute a modified or derivative version, it must be released
under this **exact same license**. You may neither add nor remove
permissions, restrictions, or licensing terms.

The copyright notice and this license must remain with all redistributed
copies and derivative versions.

**Commercial use requires separate permission from HeartWare.**

The software is provided "as is", without warranty of any kind.

For full documentation: See the accompanying README.MD file.
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
                           CaseSensitive,
                           CurlyBracketsWord);
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

FUNCTION RegExPOS(CONST Mask,Value : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : INTEGER;

PROCEDURE UnitTest;

IMPLEMENTATION

USES System.SysUtils, System.RTTI;

FUNCTION InternalRegExMatcher(CONST Mask : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard] ; Anchored : BOOLEAN) : TRegEx;
  VAR
    I,CurlyEnd : INTEGER;
    R          : STRING;

  FUNCTION NumberSetPattern : STRING;
    BEGIN
      Result:=IF TRegExMatcherOption.Unicode IN Options THEN '\p{N}' ELSE '0-9'
    END;

  FUNCTION NumberPattern : STRING;
    BEGIN
      Result:=IF TRegExMatcherOption.Unicode IN Options THEN NumberSetPattern ELSE '['+NumberSetPattern+']'
    END;

  FUNCTION AlphaSetPattern : STRING;
    BEGIN
      Result:=IF TRegExMatcherOption.Unicode IN Options THEN '\p{L}'  ELSE Result:='A-Za-z'
    END;

  FUNCTION AlphaPattern : STRING;
    BEGIN
      Result:=IF TRegExMatcherOption.Unicode IN Options THEN AlphaSetPattern ELSE Result:='['+AlphaSetPattern+']'
    END;

  FUNCTION WordAlphaNumericSetPattern : STRING;
    BEGIN
      Result:=AlphaSetPattern+NumberSetPattern // IF TRegExMatcherOption.Unicode IN Options THEN AlphaSetPattern+'\p{N}' ELSE AlphaSetPattern+'0-9'
    END;

  FUNCTION FindCurlyEnd(CONST StartPos : INTEGER) : INTEGER;
    VAR
      J : INTEGER;

    BEGIN
      Result:=0; J:=SUCC(StartPos);

      WHILE J<=Length(Mask) DO BEGIN
        {
          Inside {...}, braces can always be escaped with a backslash,
          independently of BackslashEscaping. If BackslashEscaping is
          enabled, its normal escaping rules apply as well.
        }
        IF (Mask[J]='\') AND (J<Length(Mask)) AND ((TRegExMatcherOption.BackslashEscaping IN Options) OR CharInSet(Mask[SUCC(J)],['{','}'])) THEN
          INC(J,2)
        ELSE IF Mask[J]='{' THEN
          RAISE EConvertError.CreateFmt('Unescaped "{" inside CurlyBracketsWord at position %d in mask "%s"',[J,Mask])
        ELSE IF Mask[J]='}' THEN
          EXIT(J)
        ELSE
          INC(J)
      END
    END;

  PROCEDURE AddLiteral(C : CHAR);
    BEGIN
      CASE C OF
        '\','.','^','$','|','(',')','[',']','{','}','*','+','?' : R:=R+'\'+C
      ELSE // OTHERWISE //
        R:=R+C
      END
    END;

  PROCEDURE AddSetLiteral(VAR S : STRING ; C : CHAR ; Escaped : BOOLEAN);
    BEGIN
      CASE C OF
        '\','[',']','^' : S:=S+'\'+C;
                    '-' : S:=S+(IF Escaped THEN '\-' ELSE '-');
      ELSE // OTHERWISE //
        S:=S+C
      END
    END;

  FUNCTION AddSet : BOOLEAN;
    VAR
      J,K       : INTEGER;
      Negated   : BOOLEAN;
      S         : STRING;
      C         : CHAR;
      
    BEGIN
      Result:=FALSE;
      {
        Find the closing "]".

        If BackslashEscaping is enabled, an escaped "]" does not
        terminate the set.
      }
      J:=SUCC(I);
      WHILE (J<=Length(Mask)) AND ((CurlyEnd=0) OR (J<CurlyEnd)) DO BEGIN
        IF (TRegExMatcherOption.BackslashEscaping IN Options) AND (Mask[J]='\') AND (J<Length(Mask)) THEN
          INC(J,2)
        ELSE IF Mask[J]=']' THEN
          BREAK
        ELSE
          INC(J)
      END;

      IF (J>Length(Mask)) OR ((CurlyEnd>0) AND (J>=CurlyEnd)) THEN EXIT;

      K:=SUCC(I);

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
        IF (CurlyEnd>0) AND (Mask[K]='\') AND (SUCC(K)<J) AND CharInSet(Mask[SUCC(K)],['{','}']) THEN BEGIN
          { Curly-brace escaping remains active inside sets within {...}. }
          INC(K);
          AddSetLiteral(S,Mask[K],TRUE)
        END ELSE IF (TRegExMatcherOption.BackslashEscaping IN Options) AND (Mask[K]='\') THEN
          IF SUCC(K)>=J THEN 
            AddSetLiteral(S,'\',TRUE)
          ELSE BEGIN
            INC(K);
            AddSetLiteral(S,Mask[K],TRUE)
          END
        ELSE BEGIN
          C:=Mask[K];
          CASE C OF
            '#' : IF TRegExMatcherOption.HashNumeric IN Options THEN S:=S+NumberSetPattern ELSE AddSetLiteral(S,C,FALSE);
            '$' : IF TRegExMatcherOption.DollarNumeric IN Options THEN
                    {
                      Inside a set "$" means one numeric character.
                      The "+" semantics would make no sense inside [].
                    }
                    S:=S+NumberSetPattern
                  ELSE
                    AddSetLiteral(S,C,FALSE);
            '@' : IF TRegExMatcherOption.AlphaAt IN Options THEN S:=S+AlphaSetPattern ELSE AddSetLiteral(S,C,FALSE);
          ELSE // OTHERWISE //
            AddSetLiteral(S,C,FALSE)
          END
        END;
        INC(K)
      END;

      R:=R+'['+(IF Negaed THEN '^' ELSE '')+S+']';
      I:=J;
      Result:=TRUE
    END;

  BEGIN
    R:=IF Anchored THEN '\A' ELSE '';
    I:=1;
    CurlyEnd:=0;
    WHILE I<=Length(Mask) DO BEGIN
      {
        CurlyBracketsWord's mandatory brace escaping gets first priority while
        inside a {...} segment. Normal BackslashEscaping is then applied.

        Thus, with BackslashEscaping enabled:
          \*   literal *
          \?   literal ?
          \#   literal #
          \$   literal $
          \@   literal @
          \[   literal [
          \{   literal {
          \}   literal }
          \\   literal \
      }
      IF I=CurlyEnd THEN BEGIN
        R:=R+'(?!['+WordAlphaNumericSetPattern+'])';
        CurlyEnd:=0
      ELSE IF (CurlyEnd>0) AND (Mask[I]='\') AND (I<CurlyEnd) AND CharInSet(Mask[I+1],['{','}']) THEN BEGIN
        {
          Within a CurlyBracketsWord segment, \{ and \} always mean
          literal braces, even when BackslashEscaping is not enabled.
        }
        INC(I);
        AddLiteral(Mask[I])
      END ELSE IF (TRegExMatcherOption.BackslashEscaping IN Options) AND (Mask[I]='\') THEN
        IF I>=Length(Mask) THEN 
          AddLiteral('\')
        ELSE BEGIN
          INC(I);
          AddLiteral(Mask[I])
        END
      {
        CR, LF and CR/LF in the mask are all one logical line ending.
      }
      ELSE IF (TRegExMatcherOption.LineEndings IN Options) AND ((Mask[I]=#13) OR (Mask[I]=#10)) THEN BEGIN
        IF (Mask[I]=#13) AND (I<Length(Mask)) AND (Mask[SUCC(I)]=#10) THEN INC(I);
        {
          Atomic grouping is deliberate.

          If the value contains CR/LF, it must be consumed as CR/LF
          and cannot later be backtracked into two separate characters.
        }
        R:=R+'(?>\r\n|\r|\n)'
      END ELSE 
        CASE Mask[I] OF
          '#' : IF TRegExMatcherOption.HashNumeric IN Options THEN R:=R+NumberPattern ELSE AddLiteral(Mask[I]);
          '$' : IF TRegExMatcherOption.DollarNumeric IN Options THEN R:=R+NumberPattern+'+' ELSE AddLiteral(Mask[I]);
          '@' : IF TRegExMatcherOption.AlphaAt IN Options THEN R:=R+AlphaPattern ELSE AddLiteral(Mask[I]);
          '*' : IF TRegExMatcherOption.StarWildCard NOT IN Options THEN 
                  AddLiteral(Mask[I])
                ELSE IF TRegExMatcherOption.LineEndings IN Options THEN
                  {
                    One iteration is one logical character.

                    CR/LF is tried first and the atomic group prevents
                    it from subsequently being split into CR + LF.
                  }
                  R:=R+'(?>\r\n|[^\r\n]|\r|\n)*'
                ELSE
                  R:=R+'[\s\S]*';
          '{' : IF (TRegExMatcherOption.CurlyBracketsWord IN Options) AND (CurlyEnd=0) THEN BEGIN
                  CurlyEnd:=FindCurlyEnd(I);
                  IF CurlyEnd>0 THEN
                    R:=R+'(?<!['+WordAlphaNumericSetPattern+'])'
                  ELSE
                    AddLiteral(Mask[I])
                END ELSE
                  AddLiteral(Mask[I]);
          '[' : IF NOT ((TRegExMatcherOption.Sets IN Options) AND AddSet) THEN AddLiteral(Mask[I]);
          '?' : IF TRegExMatcherOption.QuestionWildCard NOT IN Options THEN
                  AddLiteral(Mask[I])
                ELSE IF TRegExMatcherOption.LineEndings IN Options THEN
                  R:=R+'(?>\r\n|[^\r\n]|\r|\n)'
                ELSE
                  R:=R+'[\s\S]';
        ELSE // OTHERWISE //
          AddLiteral(Mask[I])
        END;
      INC(I)
    END;
    IF Anchored THEN R:=R+'\z';
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

FUNCTION RegExPOS(CONST Mask,Value : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : INTEGER;
  BEGIN
    VAR M:=InternalRegExMatcher(Mask,Options,FALSE).Match(Value);
    Result:=IF M.Success THEN SUCC(M.Index) ELSE 0
  END;
  
FUNCTION RegExMatcher(CONST Mask : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : TRegEx;
  BEGIN
    Result:=InternalRegExMatcher(Mask,Options,TRUE)
  END;

FUNCTION RegExMatch(CONST Mask,Value : STRING ; CONST Options : TRegExMatcherOptions = [TRegExMatcherOption.StarWildCard,TRegExMatcherOption.QuestionWildCard]) : BOOLEAN;
  BEGIN
    Result:=RegExMatcher(Mask,Options).IsMatch(Value)
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

  FUNCTION InvalidCurlyMask(CONST TestMask : STRING ; CONST TestOptions : TRegExMatcherOptions) : BOOLEAN;
    BEGIN
      Result:=FALSE;
      TRY
        RegExMatcher(TestMask,TestOptions)
      EXCEPT
        ON E:EConvertError DO Result:=TRUE
      END
    END;

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
      CurlyBracketsWord
      --------------------------------------------------------------------------- }

    ASSERT(RegExMatcher('{CAT}',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('CAT'),
           '{CAT} does not match CAT');

    ASSERT(RegExMatcher('{CAT}',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('cat'),
           '{CAT} does not match cat with default case-insensitive matching');

    ASSERT(RegExMatcher('{CAT}',[]).IsMatch('{CAT}'),
           '{CAT} is not literal when CurlyBracketsWord is disabled');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('A CAT!'),
           '*{CAT}* does not match A CAT!');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('(CAT)'),
           '*{CAT}* does not match (CAT)');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('_CAT_'),
           '*{CAT}* does not treat underscore as a word separator');

    ASSERT(NOT RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('SCATTER'),
           '*{CAT}* unexpectedly matches CAT inside SCATTER');

    ASSERT(NOT RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('CAT2'),
           '*{CAT}* unexpectedly matches CAT followed by a digit');

    ASSERT(NOT RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('2CAT'),
           '*{CAT}* unexpectedly matches CAT preceded by a digit');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('CAT!'),
           '*{CAT}* does not accept CAT at the start of the value');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('!CAT'),
           '*{CAT}* does not accept CAT at the end of the value');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]).IsMatch('ÆCATØ'),
           'ASCII CurlyBracketsWord does not treat Unicode letters as separators without Unicode');

    ASSERT(NOT RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Unicode]).IsMatch('ÆCATØ'),
           'Unicode CurlyBracketsWord unexpectedly treats Unicode letters as separators');

    ASSERT(RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Unicode]).IsMatch('—CAT—'),
           'Unicode CurlyBracketsWord does not treat punctuation as separators');

    ASSERT(NOT RegExMatcher('*{CAT}*',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Unicode]).IsMatch('٣CAT٧'),
           'Unicode CurlyBracketsWord unexpectedly treats Unicode numbers as separators');

    ASSERT(RegExMatcher('\{CAT\}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.BackslashEscaping]).IsMatch('{CAT}'),
           '\{CAT\} does not match literal {CAT}');

    ASSERT(RegExMatcher('{CAT',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('{CAT'),
           'Unmatched opening curly bracket is not treated literally');

    ASSERT(RegExMatcher('CAT}',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('CAT}'),
           'Unmatched closing curly bracket is not treated literally');

    ASSERT(RegExMatcher('{@##}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.AlphaAt,TRegExMatcherOption.HashNumeric]).IsMatch('A42'),
           'Mask syntax inside {...} is not honored');

    ASSERT(RegExMatcher('{Option[A-Z]}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Sets]).IsMatch('OptionQ'),
           '{Option[A-Z]} does not honor set syntax inside CurlyBracketsWord');

    ASSERT(InvalidCurlyMask('{Test{1}}',[TRegExMatcherOption.CurlyBracketsWord]),
           'Unescaped nested { inside CurlyBracketsWord does not raise EConvertError');

    ASSERT(InvalidCurlyMask('{Test{1}}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.BackslashEscaping]),
           'BackslashEscaping unexpectedly permits an unescaped nested { inside CurlyBracketsWord');

    ASSERT(InvalidCurlyMask('{Test[A{B]}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Sets]),
           'Unescaped { inside a set within CurlyBracketsWord does not raise EConvertError');

    ASSERT(RegExMatcher('{Test\{1\}}',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('Test{1}'),
           '\{ and \} are not honored inside CurlyBracketsWord without BackslashEscaping');

    ASSERT(RegExMatcher('{Test\{1\}}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.BackslashEscaping]).IsMatch('Test{1}'),
           '\{ and \} are not honored inside CurlyBracketsWord with BackslashEscaping');

    ASSERT(RegExMatcher('{[\{]}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Sets]).IsMatch('{'),
           '\{ is not honored inside a set within CurlyBracketsWord');

    ASSERT(RegExMatcher('{[\}]}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.Sets]).IsMatch('}'),
           '\} is not honored inside a set within CurlyBracketsWord');

    ASSERT(RegExMatcher('{Test\X}',[TRegExMatcherOption.CurlyBracketsWord]).IsMatch('Test\X'),
           'Backslash unexpectedly escapes a non-brace inside CurlyBracketsWord without BackslashEscaping');

    ASSERT(RegExMatcher('{Test\X}',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.BackslashEscaping]).IsMatch('TestX'),
           'BackslashEscaping does not escape a non-brace inside CurlyBracketsWord');

    ASSERT(RegExMatcher('*{Test\{1}}*',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.StarWildCard]).IsMatch('X Test{1}A'),
           'First unescaped } does not close CurlyBracketsWord and leave following } literal');

    ASSERT(NOT RegExMatcher('*{Test\{1\}}*',[TRegExMatcherOption.CurlyBracketsWord,TRegExMatcherOption.StarWildCard]).IsMatch('X Test{1}A'),
           'Escaped } inside CurlyBracketsWord unexpectedly acts as the closing delimiter');

    ASSERT(RegExMatch('*{CAT}*','A CAT!',[TRegExMatcherOption.StarWildCard,TRegExMatcherOption.CurlyBracketsWord]),
           'RegExMatch does not forward CurlyBracketsWord option');


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

