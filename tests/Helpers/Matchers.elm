module Helpers.Matchers exposing (..)


shouldEqual : a -> a -> String
shouldEqual actual expected =
  if actual == expected then
    "ok"
  else
    "expected " ++ toString expected ++ "\nbut got  " ++ toString actual
