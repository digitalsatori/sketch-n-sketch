module ShapeWidgets exposing (..)

import Eval
import FastParser
import Lang exposing (..)
import LangSvg exposing (RootedIndexedTree, IndexedTree, NodeId, ShapeKind, Attr, AVal)
import Utils

import Dict
import Regex
import Set
import String


------------------------------------------------------------------------------
-- Shape Features

type Feature
  = PointFeature PointFeature
  | DistanceFeature DistanceFeature
  | OtherFeature OtherFeature

type PointFeature
  = TopLeft | TopRight  | BotLeft | BotRight
  | TopEdge | RightEdge | BotEdge | LeftEdge
  | Center
  | LonePoint
  | Point Int
  | Midpoint Int
  | EndPoint

type DistanceFeature
  = Width | Height
  | Radius
  | RadiusX | RadiusY
  | Offset

type OtherFeature
  = FillColor | FillOpacity
  | StrokeColor | StrokeOpacity | StrokeWidth
  | Rotation

eightPointFeatures =
  List.map PointFeature
     [ TopLeft , TopRight  , BotLeft , BotRight
     , TopEdge , RightEdge , BotEdge , LeftEdge
     ]

ninePointFeatures =
  eightPointFeatures ++ [PointFeature Center]

simpleKindFeatures : List (ShapeKind, List Feature)
simpleKindFeatures =
  [ ( "rect", ninePointFeatures ++ List.map DistanceFeature [Width, Height])
  , ( "BOX", ninePointFeatures ++ List.map DistanceFeature [Width, Height])
  , ( "circle", ninePointFeatures ++ List.map DistanceFeature [Radius])
  , ( "OVAL", ninePointFeatures ++ List.map DistanceFeature [RadiusX, RadiusY])
  , ( "ellipse", ninePointFeatures ++ List.map DistanceFeature [RadiusX, RadiusY])
  , ( "line", List.map PointFeature [Point 1, Point 2, Center])
  ]

polyKindFeatures : ShapeKind -> List Attr -> List Feature
polyKindFeatures kind attrs =
  let cap = "polyKindFeatures" in
  let err s = Debug.crash <| Utils.spaces [cap, kind, ": ", s] in
  if kind == "polygon" then
    case (Utils.find cap attrs "points").interpreted of
      LangSvg.APoints pts ->
        List.concatMap
          (\i -> [PointFeature (Point i), PointFeature (Midpoint i)])
          (List.range 1 (List.length pts))
      _ ->
        err "polyKindFeatures: points not found"
  else if kind == "path" then
    case (Utils.find cap attrs "d").interpreted of
      LangSvg.APath2 (_, pathCounts) ->
        List.concatMap
          (\i -> [PointFeature (Point i)])
          (List.range 1 (pathCounts.numPoints))
      _ ->
        err "polyKindFeatures: d not found"
  else
    err <| "polyKindFeatures: " ++ kind

featuresOfShape : ShapeKind -> List Attr -> List Feature
featuresOfShape kind attrs =
  case (Utils.maybeFind kind simpleKindFeatures, kind) of
    (Just features, _)   -> features
    (Nothing, "polygon") -> polyKindFeatures kind attrs
    (Nothing, "path")    -> polyKindFeatures kind attrs
    _                    -> []

pointFeaturesOfShape : ShapeKind -> List Attr -> List PointFeature
pointFeaturesOfShape kind attrs =
  featuresOfShape kind attrs |> List.concatMap (\feature ->
    case feature of
      PointFeature pf -> [pf]
      _               -> []
  )


------------------------------------------------------------------------------
-- FeatureNum (for selecting/relating individual values)

type FeatureNum
  = XFeat PointFeature
  | YFeat PointFeature
  | DFeat DistanceFeature
  | OFeat OtherFeature


featureNumsOfFeature : Feature -> List FeatureNum
featureNumsOfFeature feature =
  case feature of
    PointFeature pf    -> [XFeat pf, YFeat pf]
    DistanceFeature df -> [DFeat df]
    OtherFeature feat  -> [OFeat feat]

-- featureNumsOfShape : ShapeKind -> List Attr -> List FeatureNum
-- featureNumsOfShape kind attrs =
--   featuresOfShape kind attrs
--   |> List.concatMap featureNumsOfFeature


------------------------------------------------------------------------------
-- ShapeFeature ~= a comparable version of ShapeKind + FeatureNum

-- Must be a comparable to be put in a Set
-- Otherwise, this shouldn't be a string
-- For now, these are unnecessarily entangled with ShapeKinds.
-- See sanityChecks below for the output of unparseFeatureNum.
--
type alias ShapeFeature = String

unparseFeatureNum : Maybe ShapeKind -> FeatureNum -> ShapeFeature
unparseFeatureNum mKind featureNum =
  case mKind of
    Just kind -> String.toLower kind ++ strFeatureNum kind featureNum
    Nothing   -> strFeatureNum "XXX" featureNum

strFeatureNum : ShapeKind -> FeatureNum -> ShapeFeature
strFeatureNum kind featureNum =
  case (kind, featureNum) of
    ("line", XFeat (Point 1)) -> "X1"
    ("line", XFeat (Point 2)) -> "X2"
    ("line", YFeat (Point 1)) -> "Y1"
    ("line", YFeat (Point 2)) -> "Y2"
    (_,      XFeat pf)        -> strPointFeature pf "X"
    (_,      YFeat pf)        -> strPointFeature pf "Y"
    (_,      DFeat df)        -> strDistanceFeature df
    (_,      OFeat f)         -> strOtherFeature f

strPointFeature pointFeature xy =
  case pointFeature of
    TopLeft    -> "TL" ++ xy
    TopRight   -> "TR" ++ xy
    BotLeft    -> "BL" ++ xy
    BotRight   -> "BR" ++ xy
    TopEdge    -> "TC" ++ xy
    RightEdge  -> "CR" ++ xy
    BotEdge    -> "BC" ++ xy
    LeftEdge   -> "CL" ++ xy
    Center     -> "C" ++ xy
    LonePoint  -> xy
    Point i    -> "Pt" ++ xy ++ toString i
    Midpoint i -> "Midpt" ++ xy ++ toString i
    EndPoint   -> "Endpt" ++ xy

strDistanceFeature distanceFeature =
  case distanceFeature of
    Width         -> "Width"
    Height        -> "Height"
    Radius        -> "R"
    RadiusX       -> "RX"
    RadiusY       -> "RY"
    Offset        -> ""

strOtherFeature otherFeature =
  case otherFeature of
    FillColor     -> "fill"
    StrokeColor   -> "stroke"
    FillOpacity   -> "fillOpacity"
    StrokeOpacity -> "strokeOpacity"
    StrokeWidth   -> "strokeWidth"
    Rotation      -> "rotation"

shapeKindRegexStr  = "line|rect|circle|ellipse|polygon|path|box|oval|point|offset"
xShapeFeatureRegex = Regex.regex <| "^(" ++ shapeKindRegexStr ++ ")(.*)X(\\d*)$"
yShapeFeatureRegex = Regex.regex <| "^(" ++ shapeKindRegexStr ++ ")(.*)Y(\\d*)$"

distanceFeatureRegex =
  Regex.regex <| "^(" ++ shapeKindRegexStr ++ ")(Width|Height|R|RX|RY)$"

parseFeatureNum : ShapeFeature -> FeatureNum
parseFeatureNum shapeFeature =
  if Regex.contains distanceFeatureRegex shapeFeature then
    Regex.find (Regex.AtMost 1) distanceFeatureRegex shapeFeature
      |> Utils.head_
      |> (.submatches)
      |> parseDistanceFeature
      |> DFeat
  else if Regex.contains xShapeFeatureRegex shapeFeature then
    Regex.find (Regex.AtMost 1) xShapeFeatureRegex shapeFeature
      |> Utils.head_
      |> (.submatches)
      |> parseShapeFeaturePoint
      |> XFeat
  else if Regex.contains yShapeFeatureRegex shapeFeature then
    Regex.find (Regex.AtMost 1) yShapeFeatureRegex shapeFeature
      |> Utils.head_
      |> (.submatches)
      |> parseShapeFeaturePoint
      |> YFeat
  else
    case shapeFeature of
      "offset"        -> DFeat Offset

      "fill"          -> OFeat FillColor
      "stroke"        -> OFeat StrokeColor
      "fillOpacity"   -> OFeat FillOpacity
      "strokeOpacity" -> OFeat StrokeOpacity
      "strokeWidth"   -> OFeat StrokeWidth
      "rotation"      -> OFeat Rotation

      _ -> Debug.crash <| "parseFeatureNum: " ++ shapeFeature

parseDistanceFeature matches =
  case matches of
    [Just kind, Just "Width"]  -> Width
    [Just kind, Just "Height"] -> Height
    [Just kind, Just "R"]      -> Radius
    [Just kind, Just "RX"]     -> RadiusX
    [Just kind, Just "RY"]     -> RadiusY

    _ -> Debug.crash <| "parseDistanceFeature: " ++ (toString matches)

parseShapeFeaturePoint matches =
  case matches of

    [Just kind, Just "TL", Just ""] -> TopLeft
    [Just kind, Just "TR", Just ""] -> TopRight
    [Just kind, Just "BL", Just ""] -> BotLeft
    [Just kind, Just "BR", Just ""] -> BotRight
    [Just kind, Just "TC", Just ""] -> TopEdge
    [Just kind, Just "CR", Just ""] -> RightEdge
    [Just kind, Just "BC", Just ""] -> BotEdge
    [Just kind, Just "CL", Just ""] -> LeftEdge
    [Just kind, Just "C" , Just ""] -> Center

    [Just kind, Just "",    Just ""] -> LonePoint

    [Just kind, Just "", Just "1"] -> Point 1
    [Just kind, Just "", Just "2"] -> Point 2

    [Just kind, Just "Pt", Just s] -> Point (Utils.parseInt s)

    [Just kind, Just "Midpt", Just s]  -> Midpoint (Utils.parseInt s)
    [Just kind, Just "Endpt", Just ""] -> EndPoint

    _ -> Debug.crash <| "parsePoint: " ++ toString matches


-- Explicitly exclude ellipseRX/ellipseRX
xFeatureNameRegex = Regex.regex "^(?!ellipseR)(.*)X(\\d*)$"
yFeatureNameRegex = Regex.regex "^(?!ellipseR)(.*)Y(\\d*)$"
xOrYFeatureNameRegex = Regex.regex "^(?!ellipseR)(.*)[XY](\\d*)$"

featureNameIsX featureName =
  Regex.contains xFeatureNameRegex featureName

featureNameIsY featureName =
  Regex.contains yFeatureNameRegex featureName

featureNameIsXOrY featureName =
  Regex.contains xOrYFeatureNameRegex featureName

featurePointAndNumber featureName =
  Regex.find (Regex.AtMost 1) xOrYFeatureNameRegex featureName
  |> Utils.head_
  |> (.submatches)

-- Assuming features are already on the same nodeId...
featuresNamesAreXYPairs featureNameA featureNameB =
  (featureNameIsXOrY featureNameA) &&
  (featureNameIsXOrY featureNameB) &&
  (featureNameA /= featureNameB) && -- Not the same feature
  (featurePointAndNumber featureNameA) ==
    (featurePointAndNumber featureNameB) -- But the same point


------------------------------------------------------------------------------
-- Selected Shape Features

type alias SelectedShapeFeature = (NodeId, ShapeFeature)

selectedPointFeatureOf : SelectedShapeFeature -> SelectedShapeFeature
                      -> Maybe (NodeId, PointFeature)
selectedPointFeatureOf selected1 selected2 =
  let (id1, feature1) = selected1 in
  let (id2, feature2) = selected2 in
  if id1 /= id2 then Nothing
  else
    case pointFeatureOf (feature1, feature2) of
      Just pt -> Just (id1, pt)
      Nothing -> selectedPointFeatureOf selected2 selected1

pointFeatureOf : (ShapeFeature, ShapeFeature) -> Maybe PointFeature
pointFeatureOf (feature1, feature2) =
  case (parseFeatureNum feature1, parseFeatureNum feature2) of
    (XFeat pointFeature1, YFeat pointFeature2) ->
      if pointFeature1 == pointFeature2
      then Just pointFeature1
      else Nothing
    _ ->
      Nothing


------------------------------------------------------------------------------

-- Keeping these Strings around to avoid pervasive changes to
-- ValueBasedTransform. Can remove them in favor of FeatureNums instead.

assertString string result =
  if result == string then string
  else Debug.crash <| Utils.spaces ["assertString:", result, "/= ", string]

sanityCheck string kind featureNum =
  assertString string (unparseFeatureNum (Just kind) featureNum)

sanityCheckOther string featureNum =
  assertString string (unparseFeatureNum Nothing featureNum)

shapeFill          = sanityCheckOther "fill" (OFeat FillColor)
shapeStroke        = sanityCheckOther "stroke" (OFeat StrokeColor)
shapeFillOpacity   = sanityCheckOther "fillOpacity" (OFeat FillOpacity)
shapeStrokeOpacity = sanityCheckOther "strokeOpacity" (OFeat StrokeOpacity)
shapeStrokeWidth   = sanityCheckOther "strokeWidth" (OFeat StrokeWidth)
shapeRotation      = sanityCheckOther "rotation" (OFeat Rotation)

{-
rectTLX = sanityCheck "rectTLX" "rect" (X TopLeft)
rectTLY = sanityCheck "rectTLY" "rect" (Y TopLeft)
rectTRX = sanityCheck "rectTRX" "rect" (X TopRight)
rectTRY = sanityCheck "rectTRY" "rect" (Y TopRight)
rectBLX = sanityCheck "rectBLX" "rect" (X BotLeft)
rectBLY = sanityCheck "rectBLY" "rect" (Y BotLeft)
rectBRX = sanityCheck "rectBRX" "rect" (X BotRight)
rectBRY = sanityCheck "rectBRY" "rect" (Y BotRight)
rectTCX = sanityCheck "rectTCX" "rect" (X TopEdge)
rectTCY = sanityCheck "rectTCY" "rect" (Y TopEdge)
rectCRX = sanityCheck "rectCRX" "rect" (X RightEdge)
rectCRY = sanityCheck "rectCRY" "rect" (Y RightEdge)
rectBCX = sanityCheck "rectBCX" "rect" (X BotEdge)
rectBCY = sanityCheck "rectBCY" "rect" (Y BotEdge)
rectCLX = sanityCheck "rectCLX" "rect" (X LeftEdge)
rectCLY = sanityCheck "rectCLY" "rect" (Y LeftEdge)
rectCX  = sanityCheck "rectCX"  "rect" (X Center)
rectCY  = sanityCheck "rectCY"  "rect" (Y Center)

rectWidth  = sanityCheck "rectWidth"  "rect" (D Width)
rectHeight = sanityCheck "rectHeight" "rect" (D Height)

boxTLX = sanityCheck "boxTLX" "BOX" (X TopLeft)
boxTLY = sanityCheck "boxTLY" "BOX" (Y TopLeft)
boxTRX = sanityCheck "boxTRX" "BOX" (X TopRight)
boxTRY = sanityCheck "boxTRY" "BOX" (Y TopRight)
boxBLX = sanityCheck "boxBLX" "BOX" (X BotLeft)
boxBLY = sanityCheck "boxBLY" "BOX" (Y BotLeft)
boxBRX = sanityCheck "boxBRX" "BOX" (X BotRight)
boxBRY = sanityCheck "boxBRY" "BOX" (Y BotRight)
boxTCX = sanityCheck "boxTCX" "BOX" (X TopEdge)
boxTCY = sanityCheck "boxTCY" "BOX" (Y TopEdge)
boxCRX = sanityCheck "boxCRX" "BOX" (X RightEdge)
boxCRY = sanityCheck "boxCRY" "BOX" (Y RightEdge)
boxBCX = sanityCheck "boxBCX" "BOX" (X BotEdge)
boxBCY = sanityCheck "boxBCY" "BOX" (Y BotEdge)
boxCLX = sanityCheck "boxCLX" "BOX" (X LeftEdge)
boxCLY = sanityCheck "boxCLY" "BOX" (Y LeftEdge)
boxCX  = sanityCheck "boxCX"  "BOX" (X Center)
boxCY  = sanityCheck "boxCY"  "BOX" (Y Center)

boxWidth  = sanityCheck "boxWidth"  "BOX" (D Width)
boxHeight = sanityCheck "boxHeight" "BOX" (D Height)

ovalTLX = sanityCheck "ovalTLX" "OVAL" (X TopLeft)
ovalTLY = sanityCheck "ovalTLY" "OVAL" (Y TopLeft)
ovalTRX = sanityCheck "ovalTRX" "OVAL" (X TopRight)
ovalTRY = sanityCheck "ovalTRY" "OVAL" (Y TopRight)
ovalBLX = sanityCheck "ovalBLX" "OVAL" (X BotLeft)
ovalBLY = sanityCheck "ovalBLY" "OVAL" (Y BotLeft)
ovalBRX = sanityCheck "ovalBRX" "OVAL" (X BotRight)
ovalBRY = sanityCheck "ovalBRY" "OVAL" (Y BotRight)
ovalTCX = sanityCheck "ovalTCX" "OVAL" (X TopEdge)
ovalTCY = sanityCheck "ovalTCY" "OVAL" (Y TopEdge)
ovalCRX = sanityCheck "ovalCRX" "OVAL" (X RightEdge)
ovalCRY = sanityCheck "ovalCRY" "OVAL" (Y RightEdge)
ovalBCX = sanityCheck "ovalBCX" "OVAL" (X BotEdge)
ovalBCY = sanityCheck "ovalBCY" "OVAL" (Y BotEdge)
ovalCLX = sanityCheck "ovalCLX" "OVAL" (X LeftEdge)
ovalCLY = sanityCheck "ovalCLY" "OVAL" (Y LeftEdge)
ovalCX  = sanityCheck "ovalCX"  "OVAL" (X Center)
ovalCY  = sanityCheck "ovalCY"  "OVAL" (Y Center)

ovalRX = sanityCheck "ovalRX" "OVAL" (D RadiusX)
ovalRY = sanityCheck "ovalRY" "OVAL" (D RadiusY)

circleTCX = sanityCheck "circleTCX" "circle" (X TopEdge)
circleTCY = sanityCheck "circleTCY" "circle" (Y TopEdge)
circleCRX = sanityCheck "circleCRX" "circle" (X RightEdge)
circleCRY = sanityCheck "circleCRY" "circle" (Y RightEdge)
circleBCX = sanityCheck "circleBCX" "circle" (X BotEdge)
circleBCY = sanityCheck "circleBCY" "circle" (Y BotEdge)
circleCLX = sanityCheck "circleCLX" "circle" (X LeftEdge)
circleCLY = sanityCheck "circleCLY" "circle" (Y LeftEdge)
circleCX  = sanityCheck "circleCX"  "circle" (X Center)
circleCY  = sanityCheck "circleCY"  "circle" (Y Center)

circleR = sanityCheck "circleR" "circle" (D Radius)

ellipseTCX = sanityCheck "ellipseTCX" "ellipse" (X TopEdge)
ellipseTCY = sanityCheck "ellipseTCY" "ellipse" (Y TopEdge)
ellipseCRX = sanityCheck "ellipseCRX" "ellipse" (X RightEdge)
ellipseCRY = sanityCheck "ellipseCRY" "ellipse" (Y RightEdge)
ellipseBCX = sanityCheck "ellipseBCX" "ellipse" (X BotEdge)
ellipseBCY = sanityCheck "ellipseBCY" "ellipse" (Y BotEdge)
ellipseCLX = sanityCheck "ellipseCLX" "ellipse" (X LeftEdge)
ellipseCLY = sanityCheck "ellipseCLY" "ellipse" (Y LeftEdge)
ellipseCX  = sanityCheck "ellipseCX"  "ellipse" (X Center)
ellipseCY  = sanityCheck "ellipseCY"  "ellipse" (Y Center)

ellipseRX = sanityCheck "ellipseRX" "ellipse" (D RadiusX)
ellipseRY = sanityCheck "ellipseRY" "ellipse" (D RadiusY)

lineX1 = sanityCheck "lineX1" "line" (X (Point 1))
lineY1 = sanityCheck "lineY1" "line" (Y (Point 1))
lineX2 = sanityCheck "lineX2" "line" (X (Point 2))
lineY2 = sanityCheck "lineY2" "line" (Y (Point 2))
lineCX = sanityCheck "lineCX" "line" (X Center)
lineCY = sanityCheck "lineCY" "line" (Y Center)

pathPtX i    = sanityCheck (pathPtXPrefix ++ toString i) "path" (X (Point i))
pathPtY i    = sanityCheck (pathPtYPrefix ++ toString i) "path" (Y (Point i))
polyPtX i    = sanityCheck (polyPtXPrefix ++ toString i) "polygon" (X (Point i))
polyPtY i    = sanityCheck (polyPtYPrefix ++ toString i) "polygon" (Y (Point i))
polyMidptX i = sanityCheck (polyMidptXPrefix ++ toString i) "polygon" (X (Midpoint i))
polyMidptY i = sanityCheck (polyMidptYPrefix ++ toString i) "polygon" (Y (Midpoint i))

pathPtXPrefix = "pathPtX"
pathPtYPrefix = "pathPtY"
polyPtXPrefix = "polygonPtX"
polyPtYPrefix = "polygonPtY"
polyMidptXPrefix = "polygonMidptX"
polyMidptYPrefix = "polygonMidptY"
-}


------------------------------------------------------------------------------
-- Feature Equations

-- Can't just use Trace because we need to introduce
-- constants not found in the program's Subst
-- If need more structured values in the future,
-- add EqnVal AVal (rather than EqnVal Val).
--
type alias FeatureEquation    = FeatureEquationOf NumTr
type alias FeatureValEquation = FeatureEquationOf Val

type FeatureEquationOf a
  = EqnNum a
  | EqnOp Op_ (List (FeatureEquationOf a))


selectedShapeFeatureToEquation : SelectedShapeFeature -> IndexedTree -> Widgets -> Dict.Dict LocId (Num, Loc) -> Maybe FeatureEquation
selectedShapeFeatureToEquation (nodeId, featureName) tree widgets locIdToNumberAndLoc =
  selectedShapeFeatureToEquation_ featureEquation widgetFeatureEquation (nodeId, featureName) tree widgets locIdToNumberAndLoc

selectedShapeFeatureToValEquation : SelectedShapeFeature -> IndexedTree -> Widgets -> Dict.Dict LocId (Num, Loc) -> Maybe FeatureValEquation
selectedShapeFeatureToValEquation (nodeId, featureName) tree widgets locIdToNumberAndLoc =
  selectedShapeFeatureToEquation_ featureValEquation widgetFeatureValEquation (nodeId, featureName) tree widgets locIdToNumberAndLoc

selectedShapeFeatureToEquation_
  :  (ShapeKind -> ShapeFeature -> List Attr -> FeatureEquationOf a)
  -> (ShapeFeature -> Widget -> Dict.Dict LocId (Num, Loc) -> FeatureEquationOf a)
  -> SelectedShapeFeature
  -> IndexedTree
  -> Widgets
  -> Dict.Dict LocId (Num, Loc)
  -> Maybe (FeatureEquationOf a)
selectedShapeFeatureToEquation_ getFeatureEquation getWidgetFeatureEquation (nodeId, featureName) tree widgets locIdToNumberAndLoc =
  if not <| nodeId < -2 then
    -- shape feature
    case Dict.get nodeId tree |> Maybe.map .interpreted of
      Just (LangSvg.SvgNode kind nodeAttrs _) ->
        Just (getFeatureEquation kind featureName nodeAttrs)

      Just (LangSvg.TextNode _) ->
        Nothing

      Nothing ->
        Debug.crash <| "ShapeWidgets.selectedShapeFeatureToEquation " ++ (toString nodeId) ++ " " ++ (toString tree)
  else
    -- widget feature
    -- change to index widgets by position in widget list; then pull feature from widget type
    let widgetId = -nodeId - 2 in -- widget nodeId's are encoded at -2 and count down. (And they are 1-indexed, so actually they start at -3)
    case Utils.maybeGeti1 widgetId widgets of
      Just widget -> Just (getWidgetFeatureEquation featureName widget locIdToNumberAndLoc)
      Nothing     -> Debug.crash <| "ShapeWidgets.selectedShapeFeatureToEquation can't find widget " ++ (toString widgetId) ++ " " ++ (toString widgets)


equationNumTrs featureEqn =
  case featureEqn of
    EqnNum val   -> [val]
    EqnOp _ eqns -> List.concatMap equationNumTrs eqns



type alias BoxyFeatureEquationsOf a =
  { left : FeatureEquationOf a
  , top : FeatureEquationOf a
  , right : FeatureEquationOf a
  , bottom : FeatureEquationOf a
  , cx : FeatureEquationOf a
  , cy : FeatureEquationOf a
  , mWidth : Maybe (FeatureEquationOf a)
  , mHeight : Maybe (FeatureEquationOf a)
  , mRadius : Maybe (FeatureEquationOf a)
  , mRadiusX : Maybe (FeatureEquationOf a)
  , mRadiusY : Maybe (FeatureEquationOf a)
  }


twoNumTr  = EqnNum (2, dummyTrace)
twoVal    = EqnNum (Val (VConst Nothing (2, dummyTrace)) (Provenance [] (eConst0 2 dummyLoc) []) [])
plus a b  = EqnOp Plus [a, b]
minus a b = EqnOp Minus [a, b]
div a b   = EqnOp Div [a, b]


featureEquation : ShapeKind -> ShapeFeature -> List Attr -> FeatureEquation
featureEquation kind featureName nodeAttrs =
  let featureNum = parseFeatureNum featureName in
  let toOpacity attr =
    case attr.interpreted of
      LangSvg.AColorNum (_, Just opacity) -> opacity
      _                                   -> Debug.crash "featureEquation: toOpacity"
  in
  featureEquationOf
      LangSvg.findNumishAttr
      LangSvg.getPathPoint
      LangSvg.getPolyPoint
      toOpacity
      LangSvg.toTransformRot
      twoNumTr
      kind
      nodeAttrs
      featureNum

featureNumToEquation : ShapeKind -> List Attr -> FeatureNum -> FeatureEquation
featureNumToEquation kind nodeAttrs featureNum =
  featureEquation kind (unparseFeatureNum (Just kind) featureNum) nodeAttrs

featureValEquation : ShapeKind -> ShapeFeature -> List Attr -> FeatureValEquation
featureValEquation kind featureName nodeAttrs =
  let featureNum = parseFeatureNum featureName in
  let getAttr attrName attrList =
    (Utils.find ("featureValEquation: getAttr " ++ attrName) attrList attrName).val
  in
  let getPathPoint attrList i =
    let toPointValPairs vListElems =
      let commandIsAnyOf cmd options = String.contains (String.toUpper cmd) options in
      case vListElems of
        []     -> []
        v::rest -> case v.v_ of
          VBase (VString cmd) ->
            if commandIsAnyOf cmd "Z" then
              toPointValPairs rest
            else if commandIsAnyOf cmd "MLT" then
              case Utils.split 2 rest of
                ([xVal, yVal], rest) -> (xVal, yVal) :: toPointValPairs rest
                _                    -> let _ = Utils.log "toPointValPairs MLT parse fail" in []
            else if commandIsAnyOf cmd "HV" then
              toPointValPairs (List.drop 1 rest)
            else if commandIsAnyOf cmd "C" then
              case Utils.split 6 rest of
                ([x1,y1,x2,y2,x,y], rest) -> (x1,y1) :: (x2,y2) :: (x,y) :: toPointValPairs rest
                _                         -> let _ = Utils.log "toPointValPairs C parse fail" in []
            else if commandIsAnyOf cmd "SQ" then
              case Utils.split 4 rest of
                ([x1,y1,x,y], rest) -> (x1,y1) :: (x,y) :: toPointValPairs rest
                _                   -> let _ = Utils.log "toPointValPairs SQ parse fail" in []
            else if commandIsAnyOf cmd "A" then
              case Utils.split 7 rest of
                ([rx,ry,axis,flag,sweep,x,y], rest) -> (x,y) :: toPointValPairs rest
                _                                   -> let _ = Utils.log "toPointValPairs A parse fail" in []
            else
              let _ = Utils.log ("toPointValPairs bad command " ++ cmd) in
              []

          _ ->
            let _ = Utils.log ("toPointValPairs expected command string, got " ++ strVal v) in
            []
    in
    case (Utils.find "featureValEquation: getPathPoint d" attrList "d").val.v_ of
      VList cmds -> toPointValPairs cmds |> Utils.geti i
      _          -> Debug.crash "featureValEquation: getPathPoint2"
  in
  let getPolyPoint attrList i =
    case (Utils.find "featureValEquation: getPolyPoint" attrList "points").val.v_ of
      VList points ->
        case (Utils.geti i points).v_ of
          VList [xVal, yVal] -> (xVal, yVal)
          _                  -> Debug.crash "featureValEquation: getPolyPoint2"
      _            -> Debug.crash "featureValEquation: getPolyPoint3"
  in
  let toOpacity attrVal =
    case attrVal.val.v_ of
      VList [_, opacityVal] -> opacityVal
      _                     -> Debug.crash "featureValEquation: toOpacity"
  in
  let toTransformRot attrVal =
    case attrVal.val.v_ of
      VList [cmd, rot, cx, cy] -> if cmd.v_ == VBase (VString "rotate") then (rot, cx, cy) else Debug.crash "featureValEquation: bad rotate command"
      _                        -> Debug.crash "featureValEquation: toTransformRot"
  in
  featureEquationOf
      getAttr
      getPathPoint
      getPolyPoint
      toOpacity
      toTransformRot
      twoVal
      kind
      nodeAttrs
      featureNum


widgetFeatureEquation : ShapeFeature -> Widget -> Dict.Dict LocId (Num, Loc) -> FeatureEquation
widgetFeatureEquation featureName widget locIdToNumberAndLoc =
  case widget of
    WIntSlider low high caption curVal provenance (locId,_,_) _ ->
      let (n, loc) =
        Utils.justGet_ "ShapeWidgets.widgetFeatureEquation" locId locIdToNumberAndLoc
      in
      EqnNum (n, TrLoc loc)
    WNumSlider low high caption curVal provenance (locId,_,_) _ ->
      let (n, loc) =
        Utils.justGet_ "ShapeWidgets.widgetFeatureEquation" locId locIdToNumberAndLoc
      in
      EqnNum (n, TrLoc loc)
    WPoint (x, xTr) xProvenance (y, yTr) yProvenance ->
      let featureNum = parseFeatureNum featureName in
      case featureNum of
        XFeat LonePoint -> EqnNum (x, xTr)
        YFeat LonePoint -> EqnNum (y, yTr)
        _               -> Debug.crash <| "WPoint only supports XFeat LonePoint and YFeat LonePoint; but asked for " ++ featureName
    WOffset1D (baseX, baseXTr) (baseY, baseYTr) axis sign (amount, amountTr) amountProvenance endXProvenance endYProvenance ->
      let featureNum = parseFeatureNum featureName in
      let op =
        case sign of
          Positive -> Plus
          Negative -> Minus
      in
      case (featureNum, axis) of
        (DFeat Offset, _)   -> EqnNum (amount, amountTr)
        (XFeat EndPoint, X) -> EqnOp op [EqnNum (baseX, baseXTr), EqnNum (amount, amountTr)]
        (XFeat EndPoint, Y) -> EqnNum (baseX, baseXTr)
        (YFeat EndPoint, X) -> EqnNum (baseY, baseYTr)
        (YFeat EndPoint, Y) -> EqnOp op [EqnNum (baseY, baseYTr), EqnNum (amount, amountTr)]
        _                   -> Debug.crash <| "WOffset1D only supports DFeat Offset, XFeat EndPoint, and YFeat EndPoint; but asked for " ++ featureName


widgetFeatureValEquation : ShapeFeature -> Widget -> Dict.Dict LocId (Num, Loc) -> FeatureValEquation
widgetFeatureValEquation featureName widget locIdToNumberAndLoc =
  case widget of
    WIntSlider low high caption curVal provenance (locId,_,_) _ ->
      case Eval.provenanceToMaybeVal provenance of
        Just val -> EqnNum val
        Nothing  -> Debug.crash <| "ShapeWidgets.widgetFeatureValEquation bad WIntSlider provenance"
    WNumSlider low high caption curVal provenance (locId,_,_) _ ->
      case Eval.provenanceToMaybeVal provenance of
        Just val -> EqnNum val
        Nothing  -> Debug.crash <| "ShapeWidgets.widgetFeatureValEquation bad WNumSlider provenance"
    WPoint (x, xTr) xProvenance (y, yTr) yProvenance ->
      let featureNum = parseFeatureNum featureName in
      case featureNum of
        XFeat LonePoint -> Eval.provenanceToMaybeVal xProvenance |> Maybe.map EqnNum |> Utils.fromJust_ "widgetFeatureValEquation bad WPoint XFeat provenance"
        YFeat LonePoint -> Eval.provenanceToMaybeVal yProvenance |> Maybe.map EqnNum |> Utils.fromJust_ "widgetFeatureValEquation bad WPoint YFeat provenance"
        _               -> Debug.crash <| "widgetFeatureValEquation WPoint only supports XFeat LonePoint and YFeat LonePoint; but asked for " ++ featureName
    WOffset1D (baseX, baseXTr) (baseY, baseYTr) axis sign (amount, amountTr) amountProvenance endXProvenance endYProvenance ->
      let featureNum = parseFeatureNum featureName in
      let op =
        case sign of
          Positive -> Plus
          Negative -> Minus
      in
      case featureNum of
        DFeat Offset   -> Eval.provenanceToMaybeVal amountProvenance |> Maybe.map EqnNum |> Utils.fromJust_ "widgetFeatureValEquation bad WOffset1D DFeat provenance"
        XFeat EndPoint -> Eval.provenanceToMaybeVal endXProvenance   |> Maybe.map EqnNum |> Utils.fromJust_ "widgetFeatureValEquation bad WOffset1D XFeat provenance"
        YFeat EndPoint -> Eval.provenanceToMaybeVal endYProvenance   |> Maybe.map EqnNum |> Utils.fromJust_ "widgetFeatureValEquation bad WOffset1D YFeat provenance"
        _              -> Debug.crash <| "widgetFeatureValEquation WOffset1D only supports DFeat Offset, XFeat EndPoint, and YFeat EndPoint; but asked for " ++ featureName


featureEquationOf
  :  (String -> List Attr -> a)
  -> (List Attr -> Int -> (a, a))
  -> (List Attr -> Int -> (a, a))
  -> (AVal -> a)
  -> (AVal -> (a, a, a))
  -> FeatureEquationOf a
  -> ShapeKind
  -> List Attr
  -> FeatureNum
  -> FeatureEquationOf a
featureEquationOf getAttrNum getPathPoint getPolyPoint toOpacity toTransformRot two kind attrs featureNum =

  let get attr  = EqnNum <| getAttrNum attr attrs in
  let crash () =
    let s = unparseFeatureNum (Just kind) featureNum in
    Debug.crash <| Utils.spaces [ "featureEquationOf:", kind, s ] in

  let handleLine () =
    case featureNum of
      XFeat (Point 1) -> get "x1"
      XFeat (Point 2) -> get "x2"
      YFeat (Point 1) -> get "y1"
      YFeat (Point 2) -> get "y2"
      XFeat Center    -> div (plus (get "x1") (get "x2")) two
      YFeat Center    -> div (plus (get "y1") (get "y2")) two
      _           -> crash () in

  let handleBoxyShape () =
    let equations = boxyFeatureEquationsOf getAttrNum two kind attrs in
    case featureNum of

      XFeat TopLeft   -> equations.left
      YFeat TopLeft   -> equations.top
      XFeat TopRight  -> equations.right
      YFeat TopRight  -> equations.top
      XFeat BotLeft   -> equations.left
      YFeat BotLeft   -> equations.bottom
      XFeat BotRight  -> equations.right
      YFeat BotRight  -> equations.bottom
      XFeat TopEdge   -> equations.cx
      YFeat TopEdge   -> equations.top
      XFeat BotEdge   -> equations.cx
      YFeat BotEdge   -> equations.bottom
      XFeat LeftEdge  -> equations.left
      YFeat LeftEdge  -> equations.cy
      XFeat RightEdge -> equations.right
      YFeat RightEdge -> equations.cy
      XFeat Center    -> equations.cx
      YFeat Center    -> equations.cy

      DFeat distanceFeature ->
        let s = strDistanceFeature distanceFeature in
        let cap = Utils.spaces ["shapeFeatureEquationOf:", kind, s] in
        case distanceFeature of
          Width     -> Utils.fromJust_ cap equations.mWidth
          Height    -> Utils.fromJust_ cap equations.mHeight
          Radius    -> Utils.fromJust_ cap equations.mRadius
          RadiusX   -> Utils.fromJust_ cap equations.mRadiusX
          RadiusY   -> Utils.fromJust_ cap equations.mRadiusY
          _         -> crash ()

      _ -> crash () in

  let handlePath () =
    let x i = EqnNum <| Tuple.first <| getPathPoint attrs i in
    let y i = EqnNum <| Tuple.second <| getPathPoint attrs i in
    case featureNum of
      XFeat (Point i) -> x i
      YFeat (Point i) -> y i
      _           -> crash () in

  let handlePoly () =
    let ptCount = LangSvg.getPtCount attrs in
    let x i = EqnNum <| Tuple.first <| getPolyPoint attrs i in
    let y i = EqnNum <| Tuple.second <| getPolyPoint attrs i in
    case featureNum of

      XFeat (Point i) -> x i
      YFeat (Point i) -> y i

      XFeat (Midpoint i1) ->
        let i2 = if i1 == ptCount then 1 else i1 + 1 in
        div (plus (x i1) (x i2)) two
      YFeat (Midpoint i1) ->
        let i2 = if i1 == ptCount then 1 else i1 + 1 in
        div (plus (y i1) (y i2)) two

      _  -> crash () in

  case featureNum of

    OFeat FillColor   -> get "fill"
    OFeat StrokeColor -> get "stroke"
    OFeat StrokeWidth -> get "stroke-width"

    OFeat FillOpacity   -> EqnNum <| toOpacity <| Utils.find_ attrs "fill"
    OFeat StrokeOpacity -> EqnNum <| toOpacity <| Utils.find_ attrs "stroke"
    OFeat Rotation ->
      let (rot,cx,cy) = toTransformRot <| Utils.find_ attrs "transform" in
      EqnNum rot

    _ ->
      case kind of
        "line"     -> handleLine ()
        "polygon"  -> handlePoly ()
        "polyline" -> handlePoly ()
        "path"     -> handlePath ()
        "rect"     -> handleBoxyShape ()
        "BOX"      -> handleBoxyShape ()
        "circle"   -> handleBoxyShape ()
        "ellipse"  -> handleBoxyShape ()
        "OVAL"     -> handleBoxyShape ()
        _          -> crash ()


boxyFeatureEquationsOf : (String -> List Attr -> a) -> FeatureEquationOf a -> ShapeKind -> List Attr -> BoxyFeatureEquationsOf a
boxyFeatureEquationsOf getAttrNum two kind attrs =
  let get attr  = EqnNum <| getAttrNum attr attrs in
  case kind of

    "rect" ->
      { left     = get "x"
      , top      = get "y"
      , right    = plus (get "x") (get "width")
      , bottom   = plus (get "y") (get "height")
      , cx       = plus (get "x") (div (get "width") two)
      , cy       = plus (get "y") (div (get "height") two)
      , mWidth   = Just <| get "width"
      , mHeight  = Just <| get "height"
      , mRadius  = Nothing
      , mRadiusX = Nothing
      , mRadiusY = Nothing
      }

    "BOX" ->
      { left     = get "LEFT"
      , top      = get "TOP"
      , right    = get "RIGHT"
      , bottom   = get "BOT"
      , cx       = div (plus (get "LEFT") (get "RIGHT")) two
      , cy       = div (plus (get "TOP") (get "BOT")) two
      , mWidth   = Just <| minus (get "RIGHT") (get "LEFT")
      , mHeight  = Just <| minus (get "BOT") (get "TOP")
      , mRadius  = Nothing
      , mRadiusX = Nothing
      , mRadiusY = Nothing
      }

    "OVAL" ->
      { left     = get "LEFT"
      , top      = get "TOP"
      , right    = get "RIGHT"
      , bottom   = get "BOT"
      , cx       = div (plus (get "LEFT") (get "RIGHT")) two
      , cy       = div (plus (get "TOP") (get "BOT")) two
      , mWidth   = Nothing
      , mHeight  = Nothing
      , mRadius  = Nothing
      , mRadiusX = Just <| div (minus (get "RIGHT") (get "LEFT")) two
      , mRadiusY = Just <| div (minus (get "BOT") (get "TOP")) two
      }

    "circle" ->
      { left     = minus (get "cx") (get "r")
      , top      = minus (get "cy") (get "r")
      , right    = plus (get "cx") (get "r")
      , bottom   = plus (get "cy") (get "r")
      , cx       = get "cx"
      , cy       = get "cy"
      , mWidth   = Nothing
      , mHeight  = Nothing
      , mRadius  = Just <| get "r"
      , mRadiusX = Nothing
      , mRadiusY = Nothing
      }

    "ellipse" ->
      { left     = minus (get "cx") (get "rx")
      , top      = minus (get "cy") (get "ry")
      , right    = plus (get "cx") (get "rx")
      , bottom   = plus (get "cy") (get "ry")
      , cx       = get "cx"
      , cy       = get "cy"
      , mWidth   = Nothing
      , mHeight  = Nothing
      , mRadius  = Nothing
      , mRadiusX = Just <| get "rx"
      , mRadiusY = Just <| get "ry"
      }

    _ -> Debug.crash <| "boxyFeatureEquationsOf: " ++ kind


evaluateFeatureEquation : FeatureEquation -> Maybe Num
evaluateFeatureEquation eqn =
  case eqn of
    EqnNum (n, _) ->
      Just n

    EqnOp op [left, right] ->
      let maybePerformBinop op =
        let maybeLeftResult = evaluateFeatureEquation left in
        let maybeRightResult = evaluateFeatureEquation right in
        case (maybeLeftResult, maybeRightResult) of
          (Just leftResult, Just rightResult) -> Just (op leftResult rightResult)
          _                                   -> Nothing
      in
      case op of
        Plus  -> maybePerformBinop (+)
        Minus -> maybePerformBinop (-)
        Mult  -> maybePerformBinop (*)
        Div   -> maybePerformBinop (/)
        _     -> Nothing

    _ -> Nothing


evaluateFeatureEquation_ =
  Utils.fromJust_ "evaluateFeatureEquation_" << evaluateFeatureEquation


evaluateLineFeatures attrs =
  Utils.unwrap6 <|
    List.map (evaluateFeatureEquation_ << featureNumToEquation "line" attrs) <|
      [ XFeat (Point 1), YFeat (Point 1)
      , XFeat (Point 2), YFeat (Point 2)
      , XFeat Center, YFeat Center
      ]


type alias BoxyNums =
  { left : Num , top : Num , right : Num , bot : Num , width : Num , height : Num
  , cx : Num , cy : Num
  , rx : Num , ry : Num , r : Num
  }


evaluateBoxyNums kind attrs =
  let equations = boxyFeatureEquationsOf LangSvg.findNumishAttr twoNumTr kind attrs in
  let (left, top, right, bot, cx, cy) =
    ( evaluateFeatureEquation_ equations.left
    , evaluateFeatureEquation_ equations.top
    , evaluateFeatureEquation_ equations.right
    , evaluateFeatureEquation_ equations.bottom
    , evaluateFeatureEquation_ equations.cx
    , evaluateFeatureEquation_ equations.cy
    )
  in
  let
    width  = right - left
    height = bot - top
    rx     = width / 2
    ry     = height / 2
  in
  { left = left, top = top, right = right, bot = bot
  , width = width, height = height
  , cx = cx, cy = cy
  , rx = rx, ry = ry
  , r = rx
  }


------------------------------------------------------------------------------
-- Point Feature Equations

type alias PointEquations = (FeatureEquation, FeatureEquation)

getPointEquations : ShapeKind -> List Attr -> PointFeature -> PointEquations
getPointEquations kind attrs pointFeature =
  ( featureNumToEquation kind attrs (XFeat pointFeature)
  , featureNumToEquation kind attrs (YFeat pointFeature) )

getPrimitivePointEquations : RootedIndexedTree -> NodeId -> List (NumTr, NumTr)
getPrimitivePointEquations (_, tree) nodeId =
  case Utils.justGet_ "LangSvg.getPrimitivePoints" nodeId tree |> .interpreted of
    LangSvg.SvgNode kind attrs _ ->
      List.concatMap (\pointFeature ->
        case getPointEquations kind attrs pointFeature of
          (EqnNum v1, EqnNum v2) -> [(v1,v2)]
          _                      -> []
      ) (pointFeaturesOfShape kind attrs)
    _ ->
      Debug.crash "LangSvg.getPrimitivePoints"


------------------------------------------------------------------------------
-- Zones

type alias ZoneName = String

-- NOTE: would like to use only the following definition, but datatypes
-- aren't comparable... so using Strings for storing in dictionaries, but
-- using the following for pattern-matching purposes

type RealZone
  = ZInterior
  | ZPoint PointFeature
  | ZLineEdge
  | ZPolyEdge Int
  | ZOther OtherFeature   -- fill and stroke sliders
  | ZSlider               -- range annotations
  | ZOffset1D

unparseZone : RealZone -> ZoneName
unparseZone z =
  case z of
    ZInterior            -> "Interior"

    ZPoint (Point i)     -> "Point" ++ toString i
    ZPoint TopLeft       -> "TopLeft"
    ZPoint TopRight      -> "TopRight"
    ZPoint BotLeft       -> "BotLeft"
    ZPoint BotRight      -> "BotRight"
    ZPoint TopEdge       -> "TopEdge"
    ZPoint RightEdge     -> "RightEdge"
    ZPoint BotEdge       -> "BotEdge"
    ZPoint LeftEdge      -> "LeftEdge"

    ZPoint (Midpoint _)  -> Debug.crash <| "unparseZone: " ++ toString z
    ZPoint Center        -> Debug.crash <| "unparseZone: " ++ toString z
    ZPoint LonePoint     -> "LonePoint"
    ZPoint EndPoint      -> Debug.crash <| "unparseZone: " ++ toString z

    ZLineEdge            -> "Edge"
    ZPolyEdge i          -> "Edge" ++ toString i

    ZOther FillColor     -> "FillBall"
    ZOther StrokeColor   -> "StrokeBall"
    ZOther FillOpacity   -> "FillOpacityBall"
    ZOther StrokeOpacity -> "StrokeOpacityBall"
    ZOther StrokeWidth   -> "StrokeWidthBall"
    ZOther Rotation      -> "RotateBall"

    ZSlider              -> "SliderBall"
    ZOffset1D            -> "Offset1D"


parseZone : ZoneName -> RealZone
parseZone s =
  case realZoneOf s of
    Just z  -> z
    Nothing -> Debug.crash <| "parseZone: " ++ s

realZoneOf s =
  Utils.firstMaybe
    [ toInteriorZone s
    , toOtherWidgetZone s
    , toCardinalPointZone s
    , toSliderZone s
    , toPointZone s
    , toEdgeZone s
    ]

toInteriorZone s =
  case s of
    "Interior"  -> Just ZInterior
    _           -> Nothing

toOtherWidgetZone s =
  case s of
    "LonePoint" -> Just (ZPoint LonePoint)
    "Offset1D"  -> Just ZOffset1D
    _           -> Nothing

toCardinalPointZone s =
  case s of
    "TopLeft"   -> Just (ZPoint TopLeft)
    "TopRight"  -> Just (ZPoint TopRight)
    "BotLeft"   -> Just (ZPoint BotLeft)
    "BotRight"  -> Just (ZPoint BotRight)
    "TopEdge"   -> Just (ZPoint TopEdge)
    "BotEdge"   -> Just (ZPoint BotEdge)
    "LeftEdge"  -> Just (ZPoint LeftEdge)
    "RightEdge" -> Just (ZPoint RightEdge)
    _           -> Nothing

toSliderZone s =
  case s of
    "FillBall"          -> Just (ZOther FillColor)
    "StrokeBall"        -> Just (ZOther StrokeColor)
    "FillOpacityBall"   -> Just (ZOther FillOpacity)
    "StrokeOpacityBall" -> Just (ZOther StrokeOpacity)
    "StrokeWidthBall"   -> Just (ZOther StrokeWidth)
    "RotateBall"        -> Just (ZOther Rotation)
    "SliderBall"        -> Just ZSlider
    _                   -> Nothing

toPointZone s =
  Utils.bindMaybe
    (\suffix ->
      if suffix == "" then Nothing
      else Just (ZPoint (Point (Utils.fromOk_ (String.toInt suffix)))))
    (Utils.munchString "Point" s)

toEdgeZone s =
  Utils.bindMaybe
    (\suffix ->
      if suffix == "" then Just ZLineEdge
      else Just (ZPolyEdge (Utils.fromOk_ (String.toInt suffix))))
    (Utils.munchString "Edge" s)


------------------------------------------------------------------------------
-- Relating Zones and Shape Point Features

-- In View, may want to create a single SVG element for points
-- that double as selection and drag widgets. If so, then
-- eliminate this connection.
--
zoneToCrosshair : ShapeKind -> RealZone -> Maybe (ShapeFeature, ShapeFeature)
zoneToCrosshair shape realZone =
  case realZone of
    ZPoint point ->
      let xFeature = unparseFeatureNum (Just shape) (XFeat point) in
      let yFeature = unparseFeatureNum (Just shape) (YFeat point) in
      Just (xFeature, yFeature)
    _ ->
      Nothing


------------------------------------------------------------------------------
-- Params for Shape Widget Sliders (needed by Sync and View)

wColorSlider = 250
wStrokeWidthSlider = 60
wOpacitySlider = 20


------------------------------------------------------------------------------
-- Mapping ouput selections to code EIds for synthesis suggestions.

featureValEquationToValTree : FeatureValEquation -> Val
featureValEquationToValTree valEqn =
  case valEqn of
    EqnNum val        -> val
    EqnOp op children ->
      let childVals = List.map featureValEquationToValTree children in
      -- Only need Provenance-basedOn list and the EId of the expression (dummy here)
      { v_         = VList []
      , provenance = Provenance [] (eTuple []) childVals
      , parents    = []
      }

-- All possible interpretations of "which expressions brought this value into being".
--
-- Namely, the provenance forms a tree of values: the below returns the EId sets associated
-- with the leaves of all possible prunings if that tree of values.
--
-- Or, as written below, a value comes from either:
--   1. The immediate expression that produced the value OR
--   2. Any combination of the expressions that produced the values this value was based on.
--
-- Expressions outside of the program (i.e. in the Prelude) are ignored.
--
-- Example, eids given as letters:
--
-- (def var 10_b)_a
--
-- (+ 20_d (sqrt_f var_g)_e)_c
--
-- Interpretations are:
-- [ {c}
-- , {d, e}
-- , {d, g}
-- , {d, b}
-- ]
--
-- Note: Expression f does not appear in the provenance--which function to call is
-- considered "control flow".
valTreeToProgramEIdInterpretations : Val -> List (Set.Set EId)
valTreeToProgramEIdInterpretations val =
  let (Provenance _ exp basedOnVals) = val.provenance in
  let perhapsThisExp = if FastParser.isProgramEId exp.val.eid then [Set.singleton exp.val.eid] else [] in
  basedOnVals
  |> List.map valTreeToProgramEIdInterpretations
  |> Utils.oneOfEach
  |> List.map Utils.unionAll
  |> (++) perhapsThisExp
  |> Utils.dedupByEquality


featureValEquationToEIdSets : FeatureValEquation -> List (Set.Set EId)
featureValEquationToEIdSets valEqn =
  valEqn
  |> featureValEquationToValTree
  |> valTreeToProgramEIdInterpretations
  -- |> Debug.log "eids"

selectionsEIdInterpretations : Exp -> RootedIndexedTree -> Widgets -> Set.Set SelectedShapeFeature -> Set.Set NodeId -> Dict.Dict Int NodeId -> List (List EId)
selectionsEIdInterpretations program ((rootI, shapeTree) as slate) widgets selectedFeatures selectedShapes selectedBlobs =
  selectedFeaturesToEIdInterpretationLists program slate widgets (Set.toList selectedFeatures) ++
  selectedShapesToEIdInterpretationLists   program slate widgets (Set.toList selectedShapes) ++
  selectedBlobsToEIdInterpretationLists    program slate widgets (Dict.toList selectedBlobs)
  |> Utils.oneOfEach
  |> List.map Utils.unionAll
  |> List.map Set.toList
  |> Utils.dedupByEquality

selectedFeaturesToEIdInterpretationLists : Exp -> RootedIndexedTree -> Widgets -> List SelectedShapeFeature -> List (List (Set.Set EId))
selectedFeaturesToEIdInterpretationLists program ((rootI, shapeTree) as slate) widgets selectedFeatures =
  let recurse selectedFeatures =
    selectedFeaturesToEIdInterpretationLists program slate widgets selectedFeatures
  in
  case selectedFeatures of
    [] -> []
    (nodeId, shapeFeature)::rest ->
      let eidSets = featureValEquationToEIdSets <| Utils.fromJust_ "selectedFeaturesToEIdLists: can't make feature into val equation" <| selectedShapeFeatureToValEquation (nodeId, shapeFeature) shapeTree widgets Dict.empty in
      -- Try to interpret as point?
      case rest |> Utils.findFirst (\(otherNodeId, otherShapeFeature) -> nodeId == otherNodeId && featuresNamesAreXYPairs shapeFeature otherShapeFeature) of
        Just (otherNodeId, otherShapeFeature) ->
          let otherEIdSets = featureValEquationToEIdSets <| Utils.fromJust_ "selectedFeaturesToEIdLists2: can't make feature into val equation" <| selectedShapeFeatureToValEquation (otherNodeId, otherShapeFeature) shapeTree widgets Dict.empty in
          let singletonEIdSets      = eidSets      |> List.filter (Set.size >> (==) 1) in
          let singletonOtherEIdSets = otherEIdSets |> List.filter (Set.size >> (==) 1) in
          let pointTuples =
            Utils.cartProd singletonEIdSets singletonOtherEIdSets
            |> List.filterMap
                (\(eidSingleton, otherEIdSingleton) ->
                  case ( parentByEId program (Utils.unwrapSingletonSet eidSingleton)
                       , parentByEId program (Utils.unwrapSingletonSet otherEIdSingleton) ) of
                    (Just (Just parent), Just (Just otherParent)) ->
                      if isPair parent && parent == otherParent
                      then Just parent.val.eid
                      else Nothing

                    _ -> Nothing
                )
          in
          case pointTuples of
            []   -> eidSets :: recurse rest
            _::_ -> List.map Set.singleton pointTuples :: recurse (Utils.removeAsSet (otherNodeId, otherShapeFeature) rest)

        Nothing ->
          eidSets :: recurse rest

selectedShapesToEIdInterpretationLists : Exp -> RootedIndexedTree -> Widgets -> List NodeId -> List (List (Set.Set EId))
selectedShapesToEIdInterpretationLists program ((rootI, shapeTree) as slate) widgets selectedShapes =
  []

selectedBlobsToEIdInterpretationLists : Exp -> RootedIndexedTree -> Widgets -> List (Int, NodeId) -> List (List (Set.Set EId))
selectedBlobsToEIdInterpretationLists program ((rootI, shapeTree) as slate) widgets selectedBlobs =
  [] -- blobs will go away sometime