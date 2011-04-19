----------------------------------------------------------------------------
--- The standard prelude of Curry.
--- All top-level functions defined in this module
--- are always available in any Curry program.
----------------------------------------------------------------------------

module Prelude where

-- Lines beginning with "--++" are part of the prelude
-- but cannot parsed by the compiler

-- Infix operator declarations:


infixl 9 !!
infixr 9 .
infixl 7 *, `div`, `mod`
infixl 6 +, -
-- infixr 5 :                          -- declared together with list
infixr 5 ++
infix  4 =:=, ==, /=, <, >, <=, >= -- , =:<=, =:<<=
infix  4  `elem`, `notElem`
infixr 3 &&
infixr 2 ||
infixl 1 >>, >>=
infixr 0 $, $!, $!!, $#, $##, `seq`, &, &>, ?


-- externally defined types for numbers and characters
data Int
data Float
data Char


type String = [Char]

-- Some standard combinators:

--- Function composition.
(.)   :: (b -> c) -> (a -> b) -> (a -> c)
f . g = \x -> f (g x)

--- Identity function.
id              :: a -> a
id x            = x

--- Constant function.
const           :: a -> _ -> a
const x _       = x

--- Converts an uncurried function to a curried function.
curry           :: ((a,b) -> c) -> a -> b -> c
curry f a b     =  f (a,b)

--- Converts an curried function to a function on pairs.
uncurry         :: (a -> b -> c) -> (a,b) -> c
uncurry f (a,b) = f a b

--- (flip f) is identical to f but with the order of arguments reversed.
flip            :: (a -> b -> c) -> b -> a -> c
flip  f x y     = f y x

--- Repeats application of a function until a predicate holds.
until          :: (a -> Bool) -> (a -> a) -> a -> a
until p f x     = if p x then x else until p f (f x)

--- Evaluates the first argument to head normal form (which could also
--- be a free variable) and returns the second argument.
seq     :: _ -> a -> a
-- seq external
x `seq` y = const y $! x

--- Evaluates the argument to head normal form and returns it.
--- Suspends until the result is bound to a non-variable term.
ensureNotFree :: a -> a
ensureNotFree external

--- Evaluates the argument to spine form and returns it.
--- Suspends until the result is bound to a non-variable spine.
ensureSpine :: [a] -> [a]
ensureSpine l = ensureList (ensureNotFree l)
 where ensureList []     = []
       ensureList (x:xs) = x : ensureSpine xs

--- Right-associative application.
($)     :: (a -> b) -> a -> b
f $ x   = f x

--- Right-associative application with strict evaluation of its argument
--- to head normal form.
($!)    :: (a -> b) -> a -> b
($!) external
-- f $! x  = x `seq` f x

--- Right-associative application with strict evaluation of its argument
--- to normal form.
($!!)   :: (a -> b) -> a -> b
($!!) external
-- f $!! x | x=:=y = f y  where y free

--- Right-associative application with strict evaluation of its argument
--- to a non-variable term.
($#)    :: (a -> b) -> a -> b
f $# x  = f $! (ensureNotFree x)

--- Right-associative application with strict evaluation of its argument
--- to ground normal form.
($##)   :: (a -> b) -> a -> b
($##) external
-- f $## x | x=:=y = y==y `seq` f y  where y free

--- Aborts the execution with an error message.
error :: String -> _
error x = prim_error $## x

prim_error    :: String -> _
prim_error external

--- A non-reducible polymorphic function.
--- It is useful to express a failure in a search branch of the execution.
--- It could be defined by: <code>failed = head []</code>
failed :: _
failed external

-- Boolean values
-- already defined as builtin, since it is required for if-then-else
data Bool = False | True

--- Sequential conjunction on Booleans.
(&&)            :: Bool -> Bool -> Bool
True  && x      = x
False && _      = False


--- Sequential disjunction on Booleans.
(||)            :: Bool -> Bool -> Bool
True  || _      = True
False || x      = x


--- Negation on Booleans.
not             :: Bool -> Bool
not True        = False
not False       = True

--- Useful name for the last condition in a sequence of conditional equations.
otherwise       :: Bool
otherwise       = True


--- The standard conditional. It suspends if the condition is a free variable.
if_then_else           :: Bool -> a -> a -> a
if_then_else b t f = case b of True  -> t
                               False -> f

--- Equality on finite ground data terms.
(==)            :: a -> a -> Bool
(==) external

--- Disequality.
(/=)            :: a -> a -> Bool
x /= y          = not (x==y)

--- Ordering type. Useful as a result of comparison functions.
data Ordering = LT | EQ | GT

--- Comparison of arbitrary ground data terms.
--- Data constructors are compared in the order of their definition
--- in the datatype declarations and recursively in the arguments.
compare :: a -> a -> Ordering
compare x y | x == y    = EQ
            | x <= y    = LT
            | otherwise = GT

--- Less-than on ground data terms.
(<)   :: a -> a -> Bool
x < y = not (y <= x)

--- Greater-than on ground data terms.
(>)   :: a -> a -> Bool
x > y = not (x <= y)

--- Less-or-equal on ground data terms.
(<=)  :: a -> a -> Bool
(<=)  external

--- Greater-or-equal on ground data terms.
(>=)  :: a -> a -> Bool
x >= y = not (x < y)

--- Maximum of ground data terms.
max :: a -> a -> a
max x y = if x >= y then x else y

--- Minimum of ground data terms.
min :: a -> a -> a
min x y = if x <= y then x else y

-- Pairs

--++ data (a,b) = (a,b)

--- Selects the first component of a pair.
fst             :: (a,_) -> a
fst (x,_)       = x

--- Selects the second component of a pair.
snd             :: (_,b) -> b
snd (_,y)       = y


-- Unit type
--++ data () = ()


-- Lists

--++ data [a] = [] | a : [a]

--- Computes the first element of a list.
head            :: [a] -> a
head (x:_)      = x

--- Computes the remaining elements of a list.
tail            :: [a] -> [a]
tail (_:xs)     = xs

--- Is a list empty?
null            :: [_] -> Bool
null []         = True
null (_:_)      = False

--- Concatenates two lists.
--- Since it is flexible, it could be also used to split a list
--- into two sublists etc.
(++)            :: [a] -> [a] -> [a]
[]     ++ ys    = ys
(x:xs) ++ ys    = x : xs++ys

--- Computes the length of a list.
--length          :: [_] -> Int
--length []       = 0
--length (_:xs)   = 1 + length xs

length xs = len xs 0
  where
    len [] n = n
    len (_:ys) n
        = let np1 = n + 1
          in len ys $!! np1

--- List index (subscript) operator, head has index 0.
(!!)            :: [a] -> Int -> a
(x:xs) !! n | n==0      = x
            | n>0       = xs !! (n-1)

--- Map a function on all elements of a list.
map             :: (a->b) -> [a] -> [b]
map _ []        = []
map f (x:xs)    = f x : map f xs

--- Accumulates all list elements by applying a binary operator from
--- left to right. Thus,
--- <CODE>foldl f z [x1,x2,...,xn] = (...((z `f` x1) `f` x2) ...) `f` xn</CODE>
foldl            :: (a -> b -> a) -> a -> [b] -> a
foldl _ z []     = z
foldl f z (x:xs) = foldl f (f z x) xs

--- Accumulates a non-empty list from left to right.
foldl1           :: (a -> a -> a) -> [a] -> a
foldl1 f (x:xs)  = foldl f x xs

--- Accumulates all list elements by applying a binary operator from
--- right to left. Thus,
--- <CODE>foldr f z [x1,x2,...,xn] = (x1 `f` (x2 `f` ... (xn `f` z)...))</CODE>
foldr            :: (a->b->b) -> b -> [a] -> b
foldr _ z []     = z
foldr f z (x:xs) = f x (foldr f z xs)

--- Accumulates a non-empty list from right to left:
foldr1              :: (a -> a -> a) -> [a] -> a
foldr1 _ [x]        = x
foldr1 f (x1:x2:xs) = f x1 (foldr1 f (x2:xs))

--- Filters all elements satisfying a given predicate in a list.
filter            :: (a -> Bool) -> [a] -> [a]
filter _ []       = []
filter p (x:xs)   = if p x then x : filter p xs
                           else filter p xs

--- Joins two lists into one list of pairs. If one input list is shorter than
--- the other, the additional elements of the longer list are discarded.
zip               :: [a] -> [b] -> [(a,b)]
zip []     _      = []
zip (_:_)  []     = []
zip (x:xs) (y:ys) = (x,y) : zip xs ys

--- Joins three lists into one list of triples. If one input list is shorter
--- than the other, the additional elements of the longer lists are discarded.
zip3                      :: [a] -> [b] -> [c] -> [(a,b,c)]
zip3 []     _      _      = []
zip3 (_:_)  []     _      = []
zip3 (_:_)  (_:_)  []     = []
zip3 (x:xs) (y:ys) (z:zs) = (x,y,z) : zip3 xs ys zs

--- Joins two lists into one list by applying a combination function to
--- corresponding pairs of elements. Thus <CODE>zip = zipWith (,)</CODE>
zipWith                 :: (a->b->c) -> [a] -> [b] -> [c]
zipWith _ []     _      = []
zipWith _ (_:_)  []     = []
zipWith f (x:xs) (y:ys) = f x y : zipWith f xs ys

--- Joins three lists into one list by applying a combination function to
--- corresponding triples of elements. Thus <CODE>zip3 = zipWith3 (,,)</CODE>
zipWith3                        :: (a->b->c->d) -> [a] -> [b] -> [c] -> [d]
zipWith3 _ []     _      _      = []
zipWith3 _ (_:_)  []     _      = []
zipWith3 _ (_:_)  (_:_)  []     = []
zipWith3 f (x:xs) (y:ys) (z:zs) = f x y z : zipWith3 f xs ys zs

--- Transforms a list of pairs into a pair of lists.
unzip               :: [(a,b)] -> ([a],[b])
unzip []            = ([],[])
unzip ((x,y):ps)    = (x:xs,y:ys) where (xs,ys) = unzip ps

--- Transforms a list of triples into a triple of lists.
unzip3              :: [(a,b,c)] -> ([a],[b],[c])
unzip3 []           = ([],[],[])
unzip3 ((x,y,z):ts) = (x:xs,y:ys,z:zs) where (xs,ys,zs) = unzip3 ts

--- Concatenates a list of lists into one list.
concat            :: [[a]] -> [a]
concat l          = foldr (++) [] l

--- Maps a function from elements to lists and merges the result into one list.
concatMap         :: (a -> [b]) -> [a] -> [b]
concatMap f       = concat . map f

--- Infinite list of repeated applications of a function f to an element x.
--- Thus, <CODE>iterate f x = [x, f x, f (f x),...]</CODE>
iterate           :: (a -> a) -> a -> [a]
iterate f x       = x : iterate f (f x)

--- Infinite list where all elements have the same value.
--- Thus, <CODE>repeat x = [x, x, x,...]</CODE>
repeat            :: a -> [a]
repeat x          = x : repeat x

--- List of length n where all elements have the same value.
replicate         :: Int -> a -> [a]
replicate n x     = take n (repeat x)

--- Returns prefix of length n.
take              :: Int -> [a] -> [a]
take n l          = if n<=0 then [] else takep n l
   where takep _ []     = []
         takep m (x:xs) = x : take (m-1) xs

--- Returns suffix without first n elements.
drop              :: Int -> [a] -> [a]
drop n l          = if n<=0 then l else dropp n l
   where dropp _ []     = []
         dropp m (_:xs) = drop (m-1) xs

--- (splitAt n xs) is equivalent to (take n xs, drop n xs)
splitAt           :: Int -> [a] -> ([a],[a])
splitAt n l       = if n<=0 then ([],l) else splitAtp n l
   where splitAtp _ []     = ([],[])
         splitAtp m (x:xs) = let (ys,zs) = splitAt (m-1) xs in (x:ys,zs)

--- Returns longest prefix with elements satisfying a predicate.
takeWhile          :: (a -> Bool) -> [a] -> [a]
takeWhile _ []     = []
takeWhile p (x:xs) = if p x then x : takeWhile p xs else []

--- Returns suffix without takeWhile prefix.
dropWhile          :: (a -> Bool) -> [a] -> [a]
dropWhile _ []     = []
dropWhile p (x:xs) = if p x then dropWhile p xs else x:xs

--- (span p xs) is equivalent to (takeWhile p xs, dropWhile p xs)
span               :: (a -> Bool) -> [a] -> ([a],[a])
span _ []          = ([],[])
span p (x:xs)
       | p x       = let (ys,zs) = span p xs in (x:ys, zs)
       | otherwise = ([],x:xs)

--- (break p xs) is equivalent to (takeWhile (not.p) xs, dropWhile (not.p) xs).
--- Thus, it breaks a list at the first occurrence of an element satisfying p.
break              :: (a -> Bool) -> [a] -> ([a],[a])
break p            = span (not . p)

--- Breaks a string into a list of lines where a line is terminated at a
--- newline character. The resulting lines do not contain newline characters.
lines        :: String -> [String]
lines []     = []
lines (x:xs) = let (l,xs_l) = splitline (x:xs) in l : lines xs_l
 where splitline []     = ([],[])
       splitline (c:cs) = if c=='\n'
                          then ([],cs)
                          else let (ds,es) = splitline cs in (c:ds,es)

--- Concatenates a list of strings with terminating newlines.
unlines    :: [String] -> String
unlines ls = concatMap (++"\n") ls

--- Breaks a string into a list of words where the words are delimited by
--- white spaces.
words      :: String -> [String]
words s    = let s1 = dropWhile isSpace s
              in if s1=="" then []
                           else let (w,s2) = break isSpace s1
                                 in w : words s2
 where
   isSpace c = c == ' '  || c == '\t' || c == '\n' || c == '\r'

--- Concatenates a list of strings with a blank between two strings.
unwords    :: [String] -> String
unwords ws = if ws==[] then []
                       else foldr1 (\w s -> w ++ ' ':s) ws

--- Reverses the order of all elements in a list.
reverse    :: [a] -> [a]
reverse    = foldl (flip (:)) []

--- Computes the conjunction of a Boolean list.
and        :: [Bool] -> Bool
and        = foldr (&&) True

--- Computes the disjunction of a Boolean list.
or         :: [Bool] -> Bool
or         = foldr (||) False

--- Is there an element in a list satisfying a given predicate?
any        :: (a -> Bool) -> [a] -> Bool
any p      = or . map p

--- Is a given predicate satisfied by all elements in a list?
all        :: (a -> Bool) -> [a] -> Bool
all p      = and . map p

--- Element of a list?
elem       :: a -> [a] -> Bool
elem x     = any (x==)

--- Not element of a list?
notElem    :: a -> [a] -> Bool
notElem x  = all (x/=)

--- Looks up a key in an association list.
lookup            :: a -> [(a,b)] -> Maybe b
lookup _ []       = Nothing
lookup k ((x,y):xys)
      | k==x      = Just y
      | otherwise = lookup k xys

--- Generates an infinite sequence of ascending integers.
enumFrom               :: Int -> [Int]                   -- [n..]
enumFrom n             = n : enumFrom (n+1)

--- Generates an infinite sequence of integers with a particular in/decrement.
enumFromThen           :: Int -> Int -> [Int]            -- [n1,n2..]
enumFromThen n1 n2     = iterate ((n2-n1)+) n1


--- Generates a sequence of ascending integers.
enumFromTo             :: Int -> Int -> [Int]            -- [n..m]
enumFromTo n m         = if n>m then [] else n : enumFromTo (n+1) m

--- Generates a sequence of integers with a particular in/decrement.
enumFromThenTo         :: Int -> Int -> Int -> [Int]     -- [n1,n2..m]
enumFromThenTo n1 n2 m = takeWhile p (enumFromThen n1 n2)
                         where p x | n2 >= n1  = (x <= m)
                                   | otherwise = (x >= m)


--- Converts a character into its ASCII value.
ord :: Char -> Int
ord c = prim_ord $# c

prim_ord :: Char -> Int
prim_ord external

--- Converts an ASCII value into a character.
chr :: Int -> Char
chr n = prim_chr $# n

prim_chr :: Int -> Char
prim_chr external


-- Types of primitive arithmetic functions and predicates

--- Adds two integers.
(+)   :: Int -> Int -> Int
(+) external

-- x + y = (prim_Int_plus $# y) $# x
--
-- prim_Int_plus :: Int -> Int -> Int
-- prim_Int_plus external

--- Subtracts two integers.
(-)   :: Int -> Int -> Int
(-) external

-- x - y = (prim_Int_minus $# y) $# x
--
-- prim_Int_minus :: Int -> Int -> Int
-- prim_Int_minus external

--- Multiplies two integers.
(*)   :: Int -> Int -> Int
(*) external

-- x * y = (prim_Int_times $# y) $# x
--
-- prim_Int_times :: Int -> Int -> Int
-- prim_Int_times external

--- Integer division. The value is the integer quotient of its arguments
--- and always truncated towards zero.
--- Thus, the value of <code>13 `div` 5</code> is <code>2</code>,
--- and the value of <code>-15 `div` 4</code> is <code>-3</code>.
div   :: Int -> Int -> Int
div external

-- prim_Int_div :: Int -> Int -> Int
-- prim_Int_div external

--- Integer remainder. The value is the remainder of the integer division and
--- it obeys the rule <code>x `mod` y = x - y * (x `div` y)</code>.
--- Thus, the value of <code>13 `mod` 5</code> is <code>3</code>,
--- and the value of <code>-15 `mod` 4</code> is <code>-3</code>.
mod   :: Int -> Int -> Int
mod external

-- prim_Int_mod :: Int -> Int -> Int
-- prim_Int_mod external

--- Unary minus. Usually written as "- e".
negate :: Int -> Int
negate x = 0 - x

--- Unary minus on Floats. Usually written as "-e".
negateFloat :: Float -> Float
negateFloat external

-- prim_negateFloat :: Float -> Float
-- prim_negateFloat external


-- Constraints
data Success -- = Success

--- The equational constraint.
--- (e1 =:= e2) is satisfiable if both sides e1 and e2 can be
--- reduced to a unifiable data term (i.e., a term without defined
--- function symbols).
(=:=)   :: a -> a -> Success
(=:=) external

--- The always satisfiable constraint.
success :: Success
success external

--- Concurrent conjunction on constraints.
--- An expression like (c1 & c2) is evaluated by evaluating
--- the constraints c1 and c2 in a concurrent manner.
(&)     :: Success -> Success -> Success
(&) external

--- Constrained expression.
--- An expression like (c &> e) is evaluated by first solving
--- constraint c and then evaluating e.
(&>)          :: Success -> a -> a
c &> x | c = x


-- Maybe type

data Maybe a = Nothing | Just a

maybe              :: b -> (a -> b) -> Maybe a -> b
maybe n _ Nothing  = n
maybe _ f (Just x) = f x


-- Either type

data Either a b = Left a | Right b

either               :: (a -> c) -> (b -> c) -> Either a b -> c
either f _ (Left x)  = f x
either _ g (Right x) = g x


-- Monadic IO

data IO _  -- conceptually: World -> (a,World)

--- Sequential composition of actions.
--- @param a - An action
--- @param fa - A function from a value into an action
--- @return An action that first performs a (yielding result r)
---         and then performs (fa r)
(>>=)             :: IO a -> (a -> IO b) -> IO b
(>>=) external

--- The empty action that directly returns its argument.
return            :: a -> IO a
return external

--- Sequential composition of actions.
--- @param a1 - An action
--- @param a2 - An action
--- @return An action that first performs a1 and then a2
(>>)              :: IO _ -> IO b        -> IO b
a >> b            = a >>= (\_ -> b)

--- The empty action that returns nothing.
done              :: IO ()
done              = return ()

--- An action that puts its character argument on standard output.
putChar           :: Char -> IO ()
putChar c = prim_putChar $# c

prim_putChar           :: Char -> IO ()
prim_putChar external

--- An action that reads a character from standard output and returns it.
getChar           :: IO Char
getChar external

--- An action that (lazily) reads a file and returns its contents.
readFile          :: String -> IO String
readFile f = prim_readFile $## f

prim_readFile          :: String -> IO String
prim_readFile external

-- TODO ask Michael how this function was used
-- for internal implementation of readFile:
-- prim_readFileContents          :: String -> String
-- prim_readFileContents external

--- An action that writes a file.
--- @param filename - The name of the file to be written.
--- @param contents - The contents to be written to the file.
writeFile         :: String -> String -> IO ()
writeFile f s = (prim_writeFile $## f) s

prim_writeFile         :: String -> String -> IO ()
prim_writeFile external

--- An action that appends a string to a file.
--- It behaves like writeFile if the file does not exist.
--- @param filename - The name of the file to be written.
--- @param contents - The contents to be appended to the file.
appendFile        :: String -> String -> IO ()
appendFile f s = (prim_appendFile $## f) s

prim_appendFile         :: String -> String -> IO ()
prim_appendFile external

--- Action to print a string on stdout.
putStr            :: String -> IO ()
putStr []         = done
putStr (c:cs)     = putChar c >> putStr cs

--- Action to print a string with a newline on stdout.
putStrLn          :: String -> IO ()
putStrLn cs       = putStr cs >> putChar '\n'

--- Action to read a line from stdin.
getLine           :: IO String
getLine           = do c <- getChar
                       if c=='\n' then return []
                                  else do cs <- getLine
                                          return (c:cs)

-- Error handling in the I/O monad:

--- The (abstract) type of error values.
--- Currently, it contains only an error message as a string,
--- but it might be extended in the future to distinguish
--- various error situations.
data IOError = IOError String

--- A user error value is created by providing a description of the
--- error situation as a string.
userError :: String -> IOError
userError s = IOError s

--- Raises an I/O exception with a given error value.
ioError :: IOError -> IO _
ioError (IOError s) = error s

--- Shows an error values as a string.
showError :: IOError -> String
showError (IOError s) = s

--- Catches a possible error or failure during the execution of an
--- I/O action. <code>(catch act errfun)</code> executes the I/O action
--- <code>act</code>. If an exception or failure occurs
--- during this I/O action, the function <code>errfun</code> is applied
--- to the error value.
catch :: IO a -> (IOError -> IO a) -> IO a
catch external

--- Catches a possible failure during the execution of an I/O action.
--- <code>(catchFail act err)</code>:
--- apply action <code>act</code> and, if it fails or raises an exception,
--- print a corresponding error message and apply action <code>err</code>.
catchFail         :: IO a -> IO a -> IO a
catchFail external


--- Converts an arbitrary term into an external string representation.
show    :: _ -> String
show x = prim_show $## x

prim_show    :: _ -> String
prim_show external

--- Converts a term into a string and prints it.
print   :: _ -> IO ()
print t = putStrLn (show t)

--- Solves a constraint as an I/O action.
--- Note: the constraint should be always solvable in a deterministic way
doSolve :: Success -> IO ()
doSolve constraint | constraint = done


-- IO monad auxiliary functions:

--- Executes a sequence of I/O actions and collects all results in a list.
sequenceIO       :: [IO a] -> IO [a]
sequenceIO []     = return []
sequenceIO (c:cs) = do x  <- c
                       xs <- sequenceIO cs
                       return (x:xs)

--- Executes a sequence of I/O actions and ignores the results.
sequenceIO_        :: [IO _] -> IO ()
sequenceIO_         = foldr (>>) done

--- Maps an I/O action function on a list of elements.
--- The results of all I/O actions are collected in a list.
mapIO             :: (a -> IO b) -> [a] -> IO [b]
mapIO f            = sequenceIO . map f

--- Maps an I/O action function on a list of elements.
--- The results of all I/O actions are ignored.
mapIO_            :: (a -> IO _) -> [a] -> IO ()
mapIO_ f           = sequenceIO_ . map f


----------------------------------------------------------------
-- Non-determinism and free variables:

--- Non-deterministic choice <EM>par excellence</EM>.
--- The value of <EM>x ? y</EM> is either <EM>x</EM> or <EM>y</EM>.
--- @param x - The right argument.
--- @param y - The left argument.
--- @return either <EM>x</EM> or <EM>y</EM> non-deterministically.
(?)   :: a -> a -> a
(?) external
-- x ? _ = x
-- _ ? y = y


--- Evaluates to a fresh free variable.
unknown :: _
unknown = let x free in x

----------------------------------------------------------------
-- Encapsulated search:

--- Gets all values of an expression (currently, via an incomplete
--- depth-first strategy). Conceptually, all values are computed
--- on a copy of the expression, i.e., the evaluation of the expression
--- does not share any results. Moreover, the evaluation suspends
--- as long as the expression contains unbound variables.
--- Similar to Prolog's findall.
getAllValues :: a -> IO [a]
getAllValues e = return (findall (=:=e))

--- Gets a value of an expression (currently, via an incomplete
--- depth-first strategy). The expression must have a value, otherwise
--- the computation fails. Conceptually, the value is computed on a copy
--- of the expression, i.e., the evaluation of the expression does not share
--- any results. Moreover, the evaluation suspends as long as the expression
--- contains unbound variables.
getSomeValue :: a -> IO a
getSomeValue e = return (findfirst (=:=e))

--- Basic search control operator.
try     :: (a->Success) -> [a->Success]
try external

--- Inject operator which adds the application of the unary
--- procedure p to the search variable to the search goal
--- taken from Oz. p x comes before g x to enable a test+generate
--- form in a sequential implementation.
inject  :: (a->Success) -> (a->Success) -> (a->Success)
inject g p = \x -> p x & g x

--- Computes all solutions via a a depth-first strategy.
--
-- Works as the following algorithm:
--
-- solveAll g = evalResult (try g)
--         where
--           evalResult []      = []
--           evalResult [s]     = [s]
--           evalResult (a:b:c) = concatMap solveAll (a:b:c)
--
-- The following solveAll algorithm is faster.
-- For comparison we have solveAll2, which implements the above algorithm.

solveAll     :: (a->Success) -> [a->Success]
solveAll g = evalall (try g)
  where
    evalall []      = []
    evalall [a]     = [a]
    evalall (a:b:c) = evalall3 (try a) (b:c)

    evalall2 []    = []
    evalall2 (a:b) = evalall3 (try a) b

    evalall3 []      b  = evalall2 b
    evalall3 [l]     b  = l : evalall2 b
    evalall3 (c:d:e) b  = evalall3 (try c) (d:e ++b)


solveAll2  :: (a->Success) -> [a->Success]
solveAll2 g = evalResult (try g)
        where
          evalResult []      = []
          evalResult [s]     = [s]
          evalResult (a:b:c) = concatMap solveAll2 (a:b:c)


--- Gets the first solution via a depth-first strategy.
once :: (a->Success) -> (a->Success)
once g = head (solveAll g)


--- Gets the best solution via a depth-first strategy according to
--- a specified operator that can always take a decision which
--- of two solutions is better.
--- In general, the comparison operation should be rigid in its arguments!
best           :: (a->Success) -> (a->a->Bool) -> [a->Success]
best g cmp = bestHelp [] (try g) []
 where
   bestHelp [] []     curbest = curbest
   bestHelp [] (y:ys) curbest = evalY (try (constrain y curbest)) ys curbest
   bestHelp (x:xs) ys curbest = evalX (try x) xs ys curbest

   evalY []        ys curbest = bestHelp [] ys curbest
   evalY [newbest] ys _       = bestHelp [] ys [newbest]
   evalY (c:d:xs)  ys curbest = bestHelp (c:d:xs) ys curbest

   evalX []        xs ys curbest = bestHelp xs ys curbest
   evalX [newbest] xs ys _       = bestHelp [] (xs++ys) [newbest]
   evalX (c:d:e)   xs ys curbest = bestHelp ((c:d:e)++xs) ys curbest

   constrain y []        = y
   constrain y [curbest] =
       inject y (\v -> let w free in curbest w & cmp v w =:= True)


--- Gets all solutions via a depth-first strategy and unpack
--- the values from the lambda-abstractions.
--- Similar to Prolog's findall.
findall :: (a->Success) -> [a]
findall g = map unpack (solveAll g)


--- Gets the first solution via a depth-first strategy
--- and unpack the values from the search goals.
findfirst :: (a->Success) -> a
findfirst g = head (findall g)

--- Shows the solution of a solved constraint.
browse  :: (_->Success) -> IO ()
browse g = putStr (show (unpack g))

--- Unpacks solutions from a list of lambda abstractions and write
--- them to the screen.
browseList :: [_ -> Success] -> IO ()
browseList [] = done
browseList (g:gs) = browse g >> putChar '\n' >> browseList gs


--- Unpacks a solution's value from a (solved) search goal.
unpack  :: (a -> Success) -> a
unpack g | g x  = x  where x free


-- --- Identity function used by the partial evaluator
-- --- to mark expressions to be partially evaluated.
-- PEVAL   :: a -> a
-- PEVAL x = x

--- Evaluates the argument to normal form and returns it.
normalForm :: a -> a
normalForm x = id $!! x
-- normalForm x | x=:=y = y where y free

--- Evaluates the argument to ground normal form and returns it.
--- Suspends as long as the normal form of the argument is not ground.
groundNormalForm :: a -> a
groundNormalForm x = id $## x
-- groundNormalForm x | y==y = y where y = normalForm x

-- Only for internal use:
-- Represenation of higher-order applications in FlatCurry.
apply :: (a->b) -> a -> b
apply external

-- Only for internal use:
-- Representation of conditional rules in FlatCurry.
cond :: Success -> a -> a
cond external

-- -- Only for internal use:
-- -- letrec ones (1:ones) -> bind ones to (1:ones)
-- letrec :: a -> a -> Success
-- letrec external

--- Non-strict equational constraint. Experimental.
(=:<=) :: a -> a -> Success
(=:<=) external

--- Non-strict equational constraint for linear function patterns.
--- Thus, it must be ensured that the first argument is always (after evalutation
--- by narrowing) a linear pattern. Experimental.
(=:<<=) :: a -> a -> Success
(=:<<=) external

-- --- internal function to implement =:<=
-- ifVar :: _ -> a -> a -> a
-- ifVar external
--
-- --- internal operation to implement failure reporting
-- failure :: _ -> _ -> _
-- failure external

-- the end


-- ---------------------------------------------------------------------------
-- Nat
-- ---------------------------------------------------------------------------
data Nat = IHi | O Nat | I Nat

cmpNat :: Nat -> Nat -> Ordering
cmpNat IHi IHi   = EQ
cmpNat IHi (O _) = LT
cmpNat IHi (I _) = LT
cmpNat (O _) IHi = GT
cmpNat (I _) IHi = GT
cmpNat (O x) (O y) = cmpNat x y
cmpNat (I x) (I y) = cmpNat x y
cmpNat (O x) (I y) = case cmpNat x y of
  EQ    -> LT
  cmpxy -> cmpxy
cmpNat (I x) (O y) = case cmpNat x y of
  EQ    -> GT
  cmpxy -> cmpxy

succ :: Nat -> Nat
succ (O bs) = I bs
succ (I bs) = O (succ bs)
succ IHi = O IHi

pred :: Nat -> Nat
pred (O IHi)     = IHi
pred (I x)       = O x
pred (O x@(O _)) = I (pred x)
pred (O (I x))   = I (O x)

(*^) :: Nat -> Nat -> Nat
IHi   *^   y = y
(I x) *^ y = y +^ (O (x *^ y))
(O x) *^ y = O (x *^ y)

(+^) :: Nat -> Nat -> Nat
O x +^ O y = O (x +^ y)
O x +^ I y = I (x +^ y)
O x +^ IHi = I x
I x +^ O y = I (x +^ y)
I x +^ I y = O (succ x +^ y)
I x +^ IHi = O (succ x)
IHi +^ y   = succ y

(-^) :: Nat -> Nat -> Integer
IHi   -^ y     = inc (Neg y)                  -- 1-n = 1+(-n)
(O x) -^ IHi   = Pos (pred (O x))
(O x) -^ (O y) = mult2 (x -^ y)
(O x) -^ (I y) = dec (mult2 (x -^ y))
(I x) -^ IHi   = Pos (O x)
(I x) -^ (O y) = inc (mult2 (x -^ y))    -- 2*n+1 - 2*m = 1+2*(n-m)
(I x) -^ (I y) = mult2 (x -^ y)          -- 2*n+1 - (2*m+1) = 2*(n-m)

data Integer = Neg Nat | Zero | Pos Nat

lteqInteger :: Integer -> Integer -> Bool
lteqInteger x y = cmpInteger x y /= GT

cmpInteger :: Integer -> Integer -> Ordering
cmpInteger Zero    Zero    = EQ
cmpInteger Zero    (Pos _) = LT
cmpInteger Zero    (Neg _) = GT
cmpInteger (Pos _) Zero    = GT
cmpInteger (Pos x) (Pos y) = cmpNat x y
cmpInteger (Pos _) (Neg _) = GT
cmpInteger (Neg _) Zero    = LT
cmpInteger (Neg _) (Pos _) = LT
cmpInteger (Neg x) (Neg y) = cmpNat y x

inc :: Integer -> Integer
inc Zero = Pos IHi
inc (Pos n) = Pos (succ n)
inc (Neg IHi) = Zero
inc (Neg (O n)) = Neg (pred (O n))
inc (Neg (I n)) = Neg (O n)

dec :: Integer -> Integer
dec Zero = Neg IHi
dec (Neg n) = Neg (succ n)
dec (Pos IHi) = Zero
dec (Pos (O n)) = Pos (pred (O n))
dec (Pos (I n)) = Pos (O n)

--- Adds two integers.
(+#)   :: Integer -> Integer -> Integer
Pos x +# Pos y = Pos ((+^) x y)
Neg x +# Neg y = Neg ((+^) x y)
Pos x +# Neg y = x -^ y
Neg x +# Pos y = y -^ x
Zero  +# x     = x
x@(Pos _) +# Zero = x
x@(Neg _) +# Zero = x

--- Subtracts two integers.
(-#)   :: Integer -> Integer -> Integer
x -# Neg y = x +# Pos y
x -# Pos y = x +# Neg y
x -# Zero  = x

--- Multiplies two integers.
(*#)   :: Integer -> Integer -> Integer
Pos x *# Pos y = Pos ((*^) x y)
Pos x *# Neg y = Neg ((*^) x y)
Neg x *# Neg y = Pos ((*^) x y)
Neg x *# Pos y = Neg ((*^) x y)
Zero  *# _     = Zero
Pos _ *# Zero  = Zero
Neg _ *# Zero  = Zero

mult2 :: Integer -> Integer
mult2 (Pos n) = Pos (O n)
mult2 Zero    = Zero
mult2 (Neg n) = Neg (O n)

div2 :: Nat -> Nat
div2 (O x) = x
div2 (I x) = x

mod2 :: Nat -> Integer
mod2 (O _) = Zero
mod2 (I _) = Pos IHi

divmodNat :: Nat -> Nat -> (Integer,Integer)
divmodNat x y
  | y==IHi    = (Pos x,Zero)
  | otherwise = case cmpNat x y of
    EQ -> (Pos IHi,Zero)
    LT -> (Zero, Pos x)
    GT -> case divmodNat (div2 x) y of
      (Zero,_)      -> (Pos IHi,x -^ y)
      (Pos d,Zero)  -> (Pos (O d),mod2 x)
      (Pos d,Pos m) -> case divmodNat (shift x m) y of
        (Zero,m')   -> (Pos (O d),m')
        (Pos d',m') -> (Pos (O d +^ d'),m')
  where
    shift (O _) n = O n
    shift (I _) n = I n

--- Integer division. The value is the integer quotient of its arguments
--- and always truncated towards zero.
--- Thus, the value of <code>13 `div` 5</code> is <code>2</code>,
--- and the value of <code>-15 `div` 4</code> is <code>-3</code>.
--- Integer remainder. The value is the remainder of the integer division and
--- it obeys the rule <code>x `mod` y = x - y * (x `div` y)</code>.
--- Thus, the value of <code>13 `mod` 5</code> is <code>3</code>,
--- and the value of <code>-15 `mod` 4</code> is <code>-3</code>.

divMod :: Integer -> Integer -> (Integer, Integer)
divMod Zero    _       = (Zero, Zero)
divMod (Pos _) Zero    = failed -- error "division by 0"
divMod (Pos x) (Pos y) = divmodNat x y
divMod (Pos x) (Neg y) = let (d,m) = divmodNat x y in (neg d,m)
divMod (Neg _) Zero    = failed -- error "division by 0"
divMod (Neg x) (Pos y) = let (d,m) = divmodNat x y in (neg d,neg m)
divMod (Neg x) (Neg y) = let (d,m) = divmodNat x y in (d,neg m)

divInteger :: Integer -> Integer -> Integer
x `divInteger` y = fst (divMod x y)

modInteger :: Integer -> Integer -> Integer
x `modInteger` y = snd (divMod x y)

--- Unary minus. Usually written as "- e".
neg :: Integer -> Integer
neg Zero    = Zero
neg (Pos x) = Neg x
neg (Neg x) = Pos x
