-- move to lens library

customUpdate record x =
  record.apply x

customUpdateFreeze =
  customUpdate { apply x = x, update p = [p.input] }

-- move to table library

addRowFlags =
  { apply =
      map <| \row -> [freeze False, row]
  , unapply rows =
      just <|
        concatMap (\[flag,row] ->
          if flag == True
            then [ row, ["","",""] ]
            else [ row ]
        ) rows
  }

customUpdateTable =
  customUpdate addRowFlags

trWithButton showButton flag styles attrs children =
  if showButton == False then
    tr styles attrs children

  else
    let [hasBeenClicked, nope, yep] =
      ["has-been-clicked", customUpdateFreeze "gray", customUpdateFreeze "coral"]
    in
    let onclick =
      """
      var hasBeenClicked = document.createAttribute("@hasBeenClicked");
      var buttonStyle = document.createAttribute("style");
      
      if (this.parentNode.getAttribute("@hasBeenClicked") == "False") {
        hasBeenClicked.value = "True";
        buttonStyle.value = "color: @yep;";
      } else {
        hasBeenClicked.value = "False";
        buttonStyle.value = "color: @nope;";
      }
      
      this.parentNode.setAttributeNode(hasBeenClicked);
      this.setAttributeNode(buttonStyle);
      """
    in
    let button = -- text-button.enabled is an SnS class
      [ "span"
      , [ ["class", "text-button.enabled"]
        , ["onclick", onclick]
        , ["style", [["color", nope]]]
        ]
      , [textNode "+"]
      ]
    in
    tr styles
      ([hasBeenClicked, toString flag] :: attrs)
      (snoc button children)

------------------------------------------------

-- State, Abbreviation, Capital
states = [
  ["Alabama", "AL", "Montgomery"],
  ["Alaska", "AK", "Juneau"],
  ["Arizona", "AZ", "Phoenix"],
  ["Arkansas", "AR", "Little Rock"],
  ["California", "CA", "Sacramento"],
  ["Colorado", "CO", "Denver"],
  ["Connecticut", "CT", "Hartford"]
]

headers =
  ["State", "", "Capital"]

rows =
  states
    |> customUpdateTable

padding =
  ["padding", "3px"]

theTable =
  let headerRow =
    let styles = [padding, ["text-align", "left"], ["background-color", "coral"]] in
    tr [] [] (map (th styles []) headers)
  in
  let stateRows =
    let colors = ["lightyellow", "white"] in
    indexedMap (\i [flag,row] ->
      let color =
        nth colors (mod i (len colors))
      in
      let columns =
        map (td [padding, ["background-color", color]] []) row
      in
      trWithButton True flag [] [] columns
    ) rows
  in
  table
    [padding, ["border", "8px solid lightgray"]]
    []
    (headerRow :: stateRows)

main =
  theTable
