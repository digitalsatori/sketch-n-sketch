module ElmPrettyPrint exposing
  ( prettyPrint
  )

import ElmLang exposing
  ( Pattern(..)
  , Expression(..)
  , ETerm
  , PTerm
  )

prettyPrintP : PTerm -> String
prettyPrintP { pattern } =
  case pattern of
    PNamed { name } ->
      name

prettyPrint : ETerm -> String
prettyPrint { expression } =
  case expression of
    ELineComment { text, termAfter } ->
      "--"
        ++ text
        ++ (Maybe.withDefault "" <| Maybe.map prettyPrint termAfter)

    EBlockComment { text, termAfter } ->
      "{-"
        ++ text
        ++ "-}"
        ++ (Maybe.withDefault "" <| Maybe.map prettyPrint termAfter)

    EVariable { identifier } ->
      identifier

    EBool { bool } ->
      if bool then "True" else "False"

    EInt { int } ->
      toString int

    EFloat { float } ->
      toString float

    EChar { char } ->
      "'" ++ String.fromChar char ++ "'"

    EString { string } ->
      "\"" ++ string ++ "\""

    EMultiLineString { string } ->
      "\"\"\"" ++ string ++ "\"\"\""

    EList { members } ->
      members
        |> List.map prettyPrint
        |> String.join ", "
        |> String.append "["
        |> flip String.append "]"

    EEmptyList { whitespace } ->
      "[" ++ whitespace.ws ++ "]"

    ERecord { base, entries } ->
      let
        prettyBase =
          case base of
            Just baseTerm ->
              "" ++ prettyPrint baseTerm ++ " | "
            Nothing ->
              ""
      in
        entries
          |> List.map (\(p, e) -> prettyPrintP p ++ " = " ++ prettyPrint e)
          |> String.join ", "
          |> String.append prettyBase
          |> String.append "{ "
          |> flip String.append " }"

    EEmptyRecord { whitespace } ->
      "{" ++ whitespace.ws ++ "}"

    ELambda { parameter, body } ->
      "\\" ++ prettyPrintP parameter ++ " -> " ++ prettyPrint body

    EParen { inside } ->
      "(" ++ prettyPrint inside ++ ")"

    EConditional { condition, trueBranch, falseBranch } ->
      "if" ++ prettyPrint condition
        ++ "then" ++ prettyPrint trueBranch
        ++ "else" ++ prettyPrint falseBranch

    EFunctionApplication { function, argument } ->
      prettyPrint function ++ " " ++ prettyPrint argument

    EBinaryOperator { operator, left, right } ->
      prettyPrint left ++ operator ++ prettyPrint right