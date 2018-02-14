module LangParserUtils exposing
  ( space
  , spaces
  , keywordWithSpace
  , symbolWithSpace
  , spaceSaverKeyword
  , paddedBefore
  , paddedAfter
  , padded
  , mapPat_
  , mapExp_
  )

import Parser exposing (..)
import Parser.LowLevel as LL

import ParserUtils exposing (..)

import Lang exposing (..)
import Info exposing (..)

--------------------------------------------------------------------------------
-- Whitespace
--------------------------------------------------------------------------------

isSpace : Char -> Bool
isSpace c =
  c == ' ' || c == '\n' || c == '\t' || c == '\r'

isOnlySpaces : String -> Bool
isOnlySpaces =
  String.all isSpace

space : Parser WS
space =
  trackInfo <|
    keep (Exactly 1) isSpace

spaces : Parser WS
spaces =
  trackInfo <|
    keep zeroOrMore isSpace

guardSpace : ParserI ()
guardSpace =
  trackInfo
    ( ( succeed (,)
        |= LL.getOffset
        |= LL.getSource
      )
      |> andThen
      ( \(offset, source) ->
          guard "expecting space" <|
            isOnlySpaces <| String.slice offset (offset + 1) source
      )
    )

keywordWithSpace : String -> ParserI ()
keywordWithSpace kword =
  trackInfo <|
    succeed ()
      |. keyword kword
      |. guardSpace

symbolWithSpace : String -> ParserI ()
symbolWithSpace sym =
  trackInfo <|
    succeed ()
      |. symbol sym
      |. guardSpace

spaceSaverKeyword : Parser WS -> String -> (WS -> a) -> ParserI a
spaceSaverKeyword sp kword combiner =
  delayedCommitMap
    ( \ws _ ->
        withInfo (combiner ws) ws.start ws.end
    )
    ( sp )
    ( keyword kword )


paddedBefore : (WS -> a -> b) -> Parser WS -> ParserI a -> ParserI b
paddedBefore combiner spacePolicy p =
  delayedCommitMap
    ( \wsBefore x ->
        withInfo (combiner wsBefore x.val) x.start x.end
    )
    spacePolicy
    p

paddedAfter : (a -> WS -> b) -> ParserI a -> Parser WS -> ParserI b
paddedAfter combiner p spacePolicy =
  succeed
    ( \x wsAfter ->
        withInfo (combiner x.val wsAfter) x.start x.end
    )
    |= p
    |= spacePolicy

padded : (WS -> a -> WS -> b) -> Parser WS -> ParserI a -> Parser WS -> ParserI b
padded combiner spacePolicyBefore p spacePolicyAfter =
  delayedCommitMap
    ( \wsBefore (x, wsAfter) ->
        withInfo (combiner wsBefore x.val wsAfter) x.start x.end
    )
    spacePolicyBefore
    ( succeed (,)
        |= p
        |= spacePolicyAfter
    )

--------------------------------------------------------------------------------
-- Patterns
--------------------------------------------------------------------------------

mapPat_ : ParserI Pat__ -> Parser Pat
mapPat_ = (map << mapInfo) pat_

--------------------------------------------------------------------------------
-- Expressions
--------------------------------------------------------------------------------

mapExp_ : ParserI Exp__ -> Parser Exp
mapExp_ = (map << mapInfo) exp_
