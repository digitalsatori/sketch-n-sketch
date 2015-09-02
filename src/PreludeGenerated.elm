module PreludeGenerated (src) where

prelude =
 "
; prelude.little
;
; This little library is accessible by every program.
; This is not an example that generates an SVG canvas,
; but we include it here for reference.

;; id : a -> a
;; The identity function - given a value, returns exactly that value
(def id (\\x x))

;; always : a -> b -> a
;; A function that always returns the same value a, regardless of b
(def always (\\(x _) x))

;; compose : (a -> b)-> (b -> c) -> (a -> c)
;; Composes two functions together
(def compose (\\(f g) (\\x (f (g x)))))

;; fst : List a -> a
;; Returns the first element of a given list
(def fst (\\[x|_] x))

;; len : List a -> Int
;; Returns the length of a given list
(defrec len (\\xs (case xs ([] 0) ([_ | xs1] (+ 1 (len xs1))))))

;; map : (a -> b) -> List a -> List b
;; Maps a function, f, over a list of values and returns the resulting list
(defrec map (\\(f xs)
  (case xs ([] []) ([hd|tl] [(f hd)|(map f tl)]))))

;; map2 : (a -> b -> c) -> List a -> List b -> List c
;; Combines two lists with a given function, extra elements are dropped
(defrec map2 (\\(f xs ys)
  (case [xs ys]
    ([[x|xs1] [y|ys1]] [ (f x y) | (map2 f xs1 ys1) ])
    (_                 []))))

;; foldl : (a -> b -> b) -> b -> List a -> b
;; Takes a function, an accumulator, and a list as input and reduces using the function from the left
(defrec foldl (\\(f acc xs)
  (case xs ([] acc) ([x|xs1] (foldl f (f x acc) xs1)))))

;; foldl : (a -> b -> b) -> b -> List a -> b
;; Takes a function, an accumulator, and a list as input and reduces using the function from the right
(defrec foldr (\\(f acc xs)
  (case xs ([] acc) ([x|xs1] (f x (foldr f acc xs1))))))

;;filter : (a -> Bool) -> List a -> List a
(def filter (\\(pred xs)
  (let conditionalCons (\\(x xss)
    (if (pred x)
      (cons x xss)
      xss) )
  (foldr conditionalCons [] xs) ) ) )

;; append : List a -> List a -> List a
;; Given two lists, append the second list to the end of the first
(defrec append (\\(xs ys)
  (case xs ([] ys) ([x|xs1] [ x | (append xs1 ys)]))))

;; concat : List (List a) -> List a
;; concatenate a list of lists into a single list 
(def concat (foldr append []))

;; concatMap : (a -> List b) -> List a -> List b
;; Map a given function over a list and concatenate the resulting list of lists
(def concatMap (\\(f xs) (concat (map f xs))))

;; cartProd : List a -> List b -> List [a b]
;; Takes two lists and returns a list that is their cartesian product
(def cartProd (\\(xs ys)
  (concatMap (\\x (map (\\y [x y]) ys)) xs)))

;; zip : List a -> List b -> List [a b]
;; Takes elements at the same position from two input lists and returns a list of pairs of these elements
(def zip (map2 (\\(x y) [x y])))

;; nil : List a
;; The empty list
(def nil  [])

;; cons : a -> List a -> List a
;; attaches an element to the front of a list
(def cons (\\(x xs) [x | xs]))

;; snoc : a -> List a -> List a
;; attaches an element to the end of a list 
(def snoc (\\(x ys) (append ys [x])))

;; hd : List a -> a
;; Returns the first element of a given list
(def hd   (\\[x|xs] x))

;; tl : List a -> a
;; Returns the last element of a given list
(def tl   (\\[x|xs] xs))

;; reverse : List a -> List a
;; Given a list, reverse its order
(def reverse (foldl cons nil))

;; range : a -> a -> List a
;; Given two numbers, creates the list between them (inclusive) 
(defrec range (\\(i j)
  (if (< i (+ j 1))
      (cons i (range (+ i 1) j))
      nil)))

;; list0N : a -> List a
;; Given a number, create the list of 0 to that number inclusive (number must be > 0)
(def list0N
  (letrec foo (\\i (if (< i 0) nil (cons i (foo (- i 1)))))
  (compose reverse foo)))

;; list1N : a -> List a
;; Given a number, create the list of 1 to that number inclusive
(def list1N (\\n (range 1 n)))

;; repeat : Int -> a -> List a
;; Given a number n and some value x, return a list with x repeated n times
(def repeat (\\(n x) (map (always x) (range 1 n))))

;; intermingle : List a -> List a -> List a
;; Given two lists, return a single list that alternates between their values (first element is from first list)
(defrec intermingle (\\(xs ys)
  (case [xs ys]
    ([[x|xs1] [y|ys1]] (cons x (cons y (intermingle xs1 ys1))))
    ([[]      []]      nil)
    (_                 (append xs ys)))))

;; mult : Number -> Number -> Number
;; multiply two numbers and return the result
(defrec mult (\\(m n)
  (if (< m 1) 0 (+ n (mult (+ m -1) n)))))

;; minus : Number -> Number -> Number
;; Given two numbers, subtract the second from the first
(def minus (\\(x y) (+ x (mult y -1))))

;; div : Number -> Number -> Number
;; Given two numbers, divide the first by the second
(defrec div (\\(m n)
  (if (< m n) 0
  (if (< n 2) m
    (+ 1 (div (minus m n) n))))))

;; neg : Number -> Number
;; Given a number, returns the negative of that number
(def neg (\\x (- 0 x)))

;; not : Bool -> Bool
;; Given a bool, returns the opposite boolean value
(def not (\\b (if b false true)))

;; implies : Bool -> Bool -> Bool
;; Given two bools, returns a bool regarding if the first argument is true, then the second argument is as well
(def implies (\\(p q) (if p q true)))

;; clamp : Number -> Number -> Number -> Number
;; Given an upper bound, lower bound, and a number, restricts that number between those bounds (inclusive)
;; Ex. clamp 1 5 4 = 4
;; Ex. clamp 1 5 6 = 5
(def clamp (\\(i j n) (if (< n i) i (if (< j n) j n))))

;; joinStrings : String -> List String -> String
;; Combine a list of strings with a given separator
;; Ex. joinStrings ', ' ['hello' 'world'] = 'hello, world'
(def joinStrings (\\(sep ss)
  (foldr (\\(str acc) (if (= acc '') str (+ str (+ sep acc)))) '' ss)))

;; concatStrings : List String -> String
;; Concatenate a list of strings and return the resulting string
(def concatStrings (joinStrings ''))

;; spaces : List String -> String
;; Concatenates a list of strings, interspersing a single space in between each string
(def spaces (joinStrings ' '))

;; delimit : String -> String -> String -> String
;; First two arguments are appended at the front and then end of the third argument correspondingly
;; Ex. delimit '+' '+' 'plus' = '+plus+'
(def delimit (\\(a b s) (concatStrings [a s b])))

;; parens : String -> String
;; delimit a string with parentheses
(def parens (delimit '(' ')'))

;
; HTML manipulating functions
;

(def body (\\(attrs children) ['body' attrs children]))

(def head (\\(attrs children) ['head' attrs children]))

(def html (\\(attrs children) ['html' attrs children]))

; A basic HTML document, handy for simple documents
(def basicDoc (\\(attrs children) 
  (html [] 
    [ (head [] []) 
      (body 
        (concat [ [ ['width' '100%'] 
                    ['height' '100%']
                    ['margin' '0'] 
                  ] 
                  attrs ] )
        children ) ] ) ) )

(def p (\\(attrs children) ['p' attrs children]))

(def div (\\(attrs children) ['div' attrs children]))

(def text (\\string ['TEXT' string]))

(def span (\\(attrs children) ['span' attrs children]))

(def style (\\attrs
  (let boundKVs
    (map (\\[key value] (+ (+ (+ key ': ') value) '; ')) attrs)
  ['style' (foldr (\\(a b) (+ a b)) '' boundKVs)] ) ) )

;
; Element Abstraction
;

;; addAttr : Node -> Attribute -> Node
;; argument order - shape, new attribute
;; Add a new attribute to a given Node
(def addAttr (\\([nodeKind oldAttrs children] newAttr)
  [nodeKind (snoc newAttr oldAttrs) children]))

;; addChild : Node -> Child -> Node
;; argument order - node, new child
;; Add a child Node to a given Node
(def addChild (\\([node attrs children] newChild)
  [node attrs (snoc newChild children)] ) )

;; eStyle : Node -> Attributes -> Node
;; argument order - node to add styles to, attrs to add
;; Adds a list of attributes to a node - is helpful when using the Element
;; abstraction, as the constructor functions do not have a Style field.
;; Attributes in this case should be CSS
;; TODO: deal with double instances of the same attr?
(def eStyle (\\(newAttrs [node attrs children])
  [node
    (append newAttrs attrs )
    children ] ) )

;; eDiv : Width -> Height -> Children -> Node
;; argument order - width, height, initial children
;; Make a Div that has a specified width and height so as to be compatible with
;; the Element abstraction
(def eDiv (\\(w h initialChildren)
  (eStyle [ ['width' w] ['height' h] ]
    [ 'div' [] initialChildren ] ) ) )

; \"constant folding\"
(def twoPi (* 2 (pi)))
(def halfPi (/ (pi) 2))

;; nPointsOnUnitCircle : Number -> Number -> List Number
;; Helper function for nPointsOnCircle, calculates angle of points
;; Note: angles are calculated clockwise from the traditional pi/2 mark
(def nPointsOnUnitCircle (\\(n rot)
  (let off (- halfPi rot)
  (let foo (\\i
    (let ang (+ off (* (/ i n) twoPi))
    [(cos ang) (neg (sin ang))]))
  (map foo (list0N (- n 1)))))))

;; nPointsOnCircle : Number -> Number -> Number -> Number -> Number -> List Number
;; argument order - Number of points, degree of rotation, x-center, y-center, radius
;; Scales nPointsOnUnitCircle to the proper size and location with a given radius and center
(def nPointsOnCircle (\\(n rot cx cy r)
  (let pts (nPointsOnUnitCircle n rot)
  (map (\\[x y] [(+ cx (* x r)) (+ cy (* y r))]) pts))))

;; zones : String -> Shape -> Shape
;; Add a string-specified type of zones to a given shape
(def zones (\\s (map (\\shape (addAttr shape ['zones' s])))))

;; hideZonesTail : List Shape -> List Shape
;; Remove all zones from shapes except for the first in the list
(def hideZonesTail  (\\[hd | tl] [hd | (zones 'none'  tl)]))

;; basicZonesTail : List Shape -> List Shape
;; Turn all zones to basic for a given list of shapes except for the first shape
(def basicZonesTail (\\[hd | tl] [hd | (zones 'basic' tl)]))

; 0
['html' [] []]

"


src = prelude

