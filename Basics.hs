{-# LANGUAGE MagicHash #-}

module Basics where

import ID
import qualified Data.Map
import System.IO
import Control.Monad
import Control.Parallel.TreeSearch
import GHC.Exts (Int#, Char#, chr#)

nonAsciiChr :: Int# -> Char#
nonAsciiChr i = chr# i

data Constraint = ID :=: Choice
 deriving Show

data Try a
  = Val a
  | Fail
  | Choice ID a a
  | Free ID a a
  | Guard [Constraint] a
  deriving Show

tryChoice :: ID -> a -> a -> Try a
tryChoice i@(ID _)     = Choice i
tryChoice i@(FreeID _) = Free i

-- ---------------------------------------------------------------------------
-- Non-determinism
-- ---------------------------------------------------------------------------

-- Class for data that support nondeterministic values
class NonDet a where
  choiceCons :: ID -> a -> a -> a
  failCons   :: a
  guardCons  :: [Constraint] -> a -> a
  try        :: a -> Try a
                                         -- matching for:
  match      :: (a -> b)                 -- Head Normal Forms
             -> b                        -- Failures
             -> (ID -> a -> a -> b)      -- Choices
             -> (ID -> a -> a -> b)      -- Free Variables
             -> ([Constraint] -> a -> b) -- Constraints
             -> a
             -> b

  match = error "match: not implemented yet"

narrow :: NonDet a => ID -> a -> a -> a
narrow id = choiceCons $! narrowID id

-- Class for data that support generators
class NonDet a => Generable a where
  generate :: IDSupply -> a

-- ---------------------------------------------------------------------------
-- Computations to normal form
-- ---------------------------------------------------------------------------

-- Class for data that supports normal form computations.
-- The normal form computation is combined with a continuation to be
-- applied to the normal form.
class NonDet a => NormalForm a where
  ($!!) :: NonDet b => (a -> b) -> a -> b
  ($!<) :: (a -> IO b) -> a -> IO b


-- Auxilary function to extend $!< for non-determinism
($$!<) :: (NormalForm a) => (a -> IO b) -> a -> IO b
cont $$!< x = nf (try x)
  where
    nf (Val v)        = cont $!< v
    nf Fail           = cont failCons
    nf (Choice i x y) = nfChoiceIO cont i x y
    nf (Free i x y)   = nfChoiceIO cont i x y
    nf (Guard c e)    = cont (guardCons c e)

-- Auxilary Function to create a Choice and apply a continuation to
-- the normal forms of its alternatives
nfChoice :: (NormalForm a, NonDet b) => (a -> b) -> ID -> a -> a -> b
nfChoice cont i@(FreeID _) x1 x2 = cont (choiceCons i x1 x2)
nfChoice cont i x1 x2 = choiceCons i (cont $!! x1) (cont $!! x2)


nfChoiceIO :: (NormalForm a,NonDet a) => (a -> IO b) -> ID -> a -> a -> IO b
nfChoiceIO cont i@(FreeID _) x1 x2 = lookupChoice i >>= choose where
   choose (ChooseLeft _)  = cont $!< x1
   choose (ChooseRight _) = cont $!< x2
   choose NoChoice    = cont (choiceCons i x1 x2)
nfChoiceIO cont i x1 x2 = do
  x1' <- return $!< x1
  x2' <- return $!< x2
  cont (choiceCons i x1' x2')


-- Apply a function to the head normal form
d_dollar_bang :: (NonDet a, NonDet b) => (a -> b) -> a -> b
d_dollar_bang f x = hnf (try x)
  where
   hnf (Val v)        = f v -- d_apply f v
   hnf Fail           = failCons
   hnf (Choice i a b) = choiceCons i (hnf (try a)) (hnf (try b))
   hnf (Free i a b)   = f (choiceCons i a b)
   hnf (Guard c e)    = guardCons c (hnf (try e))


-- Apply a non-deterministic function to the head normal form
nd_dollar_bang :: (NonDet a, NonDet b) => (Func a b) -> a -> IDSupply -> b
nd_dollar_bang f x s = hnf (try x)
  where
   hnf (Val v)        = nd_apply f v s
   hnf Fail           = failCons
   -- TODO Do we have to use leftSupply and rightSupply?
   hnf (Choice i a b) = choiceCons i (hnf (try a)) (hnf (try b))
   hnf (Free i a b)   = nd_apply f (choiceCons i a b) s
   hnf (Guard c e)    = guardCons c (hnf (try e))


-- TODO: test implementation for $! replace if more efficient
d_dollar_bang_test :: (NonDet a, NonDet b) => (a -> b) -> a -> b
d_dollar_bang_test f x = match f failCons choiceF freeF guardF x
  where
    choiceF i a b = choiceCons i (f `d_dollar_bang_test` a)
                                 (f `d_dollar_bang_test` b)
    freeF i a b   = f (choiceCons i a b)
    guardF c e    = guardCons c (f  `d_dollar_bang_test` e)


-- ---------------------------------------------------------------------------
-- Unification
-- ---------------------------------------------------------------------------

-- Class for data that support unification
class (NonDet a, NormalForm a) => Unifiable a where
  (=.=) :: a -> a -> C_Success
  bind :: ID -> a -> [Constraint]

(=:=) :: Unifiable a => a -> a -> C_Success
x =:= y = unify (try x) (try y)
  where
    unify Fail _    = failCons
    unify _    Fail = failCons

    unify (Choice i x1 x2) y =
       choiceCons i (unify (try x1) y) (unify (try x2) y)

    unify x (Choice i x1 x2) =
       choiceCons i (unify x (try x1)) (unify x (try x2))

    unify (Guard c e) y = guardCons c (unify (try e) y)
    unify x (Guard c e) = guardCons c (unify x (try e))

    unify (Val vx) (Val vy) = vx =.= vy

    unify (Val v)      (Free j _ _) =
      (\ v' -> guardCons (bind j v') C_Success) $!! v

    unify (Free i _ _) (Val v)      =
      (\ v' -> guardCons (bind i v') C_Success) $!! v

    unify (Free i _ _) (Free j _ _)      =
      guardCons [i :=: BindTo j] C_Success


(&) :: C_Success -> C_Success -> C_Success
x & y = const y $!! x

-- ---------------------------------------------------------------------------
-- Built-in types
-- ---------------------------------------------------------------------------

-- The implementation of the Success type must be added here since it is used
-- in the class Unifiable.
data C_Success
  = C_Success
  | Choice_C_Success ID C_Success C_Success
  | Fail_C_Success
  | Guard_C_Success [Constraint] C_Success

instance Show C_Success where
  showsPrec d C_Success = showString "success"
  showsPrec d (Choice_C_Success i x y) = showsChoice d i x y
  showsPrec d Fail_C_Success = showChar '!'

instance Read C_Success where
  readsPrec = error "read for Success is undefined"

instance NonDet C_Success where
  choiceCons = Choice_C_Success
  failCons   = Fail_C_Success
  guardCons  = Guard_C_Success
  try (Choice_C_Success i x y) = tryChoice i x y
  try Fail_C_Success           = Fail
  try (Guard_C_Success c e)    = Guard c e
  try x = Val x

instance Generable C_Success where
  generate _ = C_Success

instance NormalForm C_Success where
  cont $!! s@C_Success = cont s
  cont $!! Choice_C_Success i x y = nfChoice cont i x y
  cont $!! Guard_C_Success c x = guardCons c (cont $!! x)
  _    $!! Fail_C_Success      = failCons

  cont $!< Choice_C_Success i x y = nfChoiceIO cont i x y
  cont $!< x = cont x

instance Unifiable C_Success where
  C_Success =.= C_Success = C_Success
  _         =.= _         = Fail_C_Success
  bind i C_Success                           = []
  bind i (Choice_C_Success j _ _) = [i :=: (BindTo j)]

-- Higher Order Funcs

data Func a b = Func (a -> IDSupply -> b)
              | Func_Choice ID (Func a b) (Func a b)
              | Func_Fail
              | Func_Guard [Constraint] (Func a b)

instance Show (Func a b) where
  show = error "show for Func is undefined"

instance Read (Func a b) where
  readsPrec = error "read for Func is undefined"

instance NonDet (Func a b) where
  choiceCons = Func_Choice
  failCons = Func_Fail
  guardCons = Func_Guard
  try (Func_Choice i x1 x2) = Choice i x1 x2
  try (Func_Fail) = Fail
  try v = Val v

instance Generable (Func a b) where
  generate = error "generate for Func is undefined"

instance NormalForm (Func a b) where
  cont $!! f@(Func _)          = cont f
  cont $!! Func_Choice i f1 f2 = nfChoice cont i f1 f2
  cont $!! Func_Guard c f      = guardCons c (cont $!! f)
  _    $!! Func_Fail           = failCons

  cont $!< Func_Choice i f1 f2 = nfChoiceIO cont i f1 f2
  cont $!< f                   = cont f

instance Unifiable (Func a b) where
  (=.=) = error "(=.=) for Func is undefined"
  bind = error "bind for Func is undefined"

-- Higher Order functions

instance Show (a -> b) where
  show = error "show for function is undefined"

instance Read (a -> b) where
  readsPrec = error "read for function is undefined"

instance NonDet (a -> b) where
  choiceCons = undefined
  failCons = undefined
  guardCons = undefined
  try = undefined

instance Generable (a -> b) where
  generate = error "generate for function is undefined"

instance NormalForm (a -> b) where
  cont $!! f = cont f
  cont $!< f = cont f

instance Unifiable (a -> b) where
  (=.=) = error "(=.=) for function is undefined"
  bind = error "bind for function is undefined"

-- ---------------------------------------------------------------------------
-- IO
-- ---------------------------------------------------------------------------

-- TODO: reason about IO and non-determinism

data C_IO a
     = Choice_C_IO ID (C_IO a) (C_IO a)
     | Fail_C_IO
     | Guard_C_IO [Constraint] (C_IO a)
     | C_IO (IO a)

instance Show (C_IO a) where
  show = error "show for C_IO"

instance Read (C_IO a) where
  readsPrec = error "read for C_IO"

instance NonDet (C_IO a) where
  choiceCons = Choice_C_IO
  failCons = Fail_C_IO
  guardCons = Guard_C_IO
  try (Choice_C_IO i x y) = tryChoice i x y
  try Fail_C_IO = Fail
  try (Guard_C_IO c e) = Guard c e
  try x = Val x

instance Generable (C_IO a) where
  generate _ = error "generate for C_IO"

instance NormalForm (C_IO a) where
  cont $!! io@(C_IO _) = cont io
  cont $!! Choice_C_IO i io1 io2 = nfChoice cont i io1 io2
  cont $!! Guard_C_IO c io = guardCons c (cont $!! io)
  _    $!! Fail_C_IO = failCons

  cont $!< Choice_C_IO i io1 io2 = nfChoiceIO cont i io1 io2
  cont $!< io                    = cont io

instance Unifiable (C_IO a) where
  (=.=) _ _ = error "(=.=) for C_IO"
  bind i (Choice_C_IO j _ _) = [i :=: (BindTo j)]

toIO :: C_IO a -> IO a
toIO (C_IO io) = io

fromIO :: IO a -> C_IO a
fromIO io = C_IO io

-- ---------------------------------------------------------------------------
-- Auxiliaries for Show and Read
-- ---------------------------------------------------------------------------

showsChoice :: Show a => Int -> ID -> a -> a -> ShowS
showsChoice d i@(FreeID _) _ _ = shows i
showsChoice d r x1 x2 =
  showChar '(' .
  showsPrec d x1 .
  showString " ?" . shows r . showChar ' ' .
  showsPrec d x2 .
  showChar ')'

showsGuard :: (Show a, Show b) => Int -> a -> b -> ShowS
showsGuard d c e = showsPrec d c . showString " &> " . showsPrec d e

-- Reads a possibly qualified name
readQualified :: String -> String -> ReadS ()
readQualified mod name r =  [((),s)  | (name',s)  <- lex r, name' == name]
                         ++ [((),s3) | (mod',s1)  <- lex r
                                     , mod' == mod
                                     , (".",s2)   <- lex s1
                                     , (name',s3) <- lex s2
                                     , name' == name]

-- ---------------------------------------------------------------------------
-- Auxiliaries for non-determinism
-- ---------------------------------------------------------------------------

-- make a deterministic function non-deterministic
nd :: (a -> b) -> a -> IDSupply -> b
nd f a _ = f a

wrapDX :: (c -> b) -> (a -> c) -> Func a b
wrapDX wrap f = wrapNX wrap (nd f)

wrapNX :: (c -> b) -> (a -> IDSupply -> c) -> Func a b
wrapNX wrap f = Func (\a s -> wrap $ f a s)

eval :: Show a => (IDSupply -> a) -> IO ()
eval goal = initSupply >>= print . goal

evalD :: Show a => a -> IO ()
evalD goal = print goal

evalIO :: Show a => (IDSupply -> C_IO a) -> IO ()
evalIO goal = initSupply >>= \s -> toIO (goal s) >>= print

evalDIO :: Show a => C_IO a -> IO ()
evalDIO goal = toIO goal >>= print

d_apply :: (a -> b) -> a -> b
d_apply f a = f a

-- TODO: Support non-deterministic Funcs
nd_apply :: NonDet b => Func a b -> a -> IDSupply -> b
nd_apply fun a s = (\(Func f) -> f a s) `d_dollar_bang` fun


----------------------------------------------------------------------
-- Printing all results of a computation in a depth-first manner
----------------------------------------------------------------------

-- Evaluate a nondeterministic expression and show all results
-- in depth-first order
prdfs :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
prdfs mainexp = initSupply >>= \s -> printValsDFS False (try (id $!! (mainexp s)))

printValsDFS :: (Show a,NonDet a, NormalForm a) => Bool -> Try a -> IO ()
printValsDFS _  Fail           = return ()
printValsDFS _  (Val v)        = print v
printValsDFS fb (Free i x y)   = lookupChoice i >>= choose
  where
   choose (ChooseLeft _)  = (printValsDFS fb . try) $!< x
   choose (ChooseRight _) = (printValsDFS fb . try) $!< y
   -- we need some more deref if we really want to rely on this output
   choose NoChoice    = print i

printValsDFS fb (Choice i x y) = lookupChoice i >>= choose
 where
   choose (ChooseLeft _)  = printValsDFS fb (try x)
   choose (ChooseRight _) = printValsDFS fb (try y)
   choose NoChoice    = if fb
                          then do
                            newChoice (ChooseLeft errChoice) x
                            newChoice (ChooseRight errChoice) y
                          else do
                            newChoice (ChooseLeft errChoice) x
                            setChoice i (ChooseRight errChoice)
                            printValsDFS False (try y)

   newChoice j a = do
    setChoice i j
    printValsDFS True (try a)
    setChoice i NoChoice

   errChoice = error "propagation number used within non-free Choice"

printValsDFS fb (Guard cs e) = do
  mreset <- solves cs
  case mreset of
    Nothing    -> return ()
    Just reset -> if fb then (printValsDFS fb . try) $!< e >> reset
                        else (printValsDFS fb . try) $!< e

solves :: [Constraint] -> Solved
solves [] = solved
solves (c:cs) = do
  mreset <- solve c
  case mreset of
    Nothing    -> return Nothing
    Just reset -> do
      mreset' <- solves cs
      case mreset' of
        Nothing -> reset >> return Nothing
        Just reset' -> return (Just (reset >> reset'))

type Solved = IO (Maybe (IO ()))

solved :: Solved
solved = return (Just (return ()))

unsolvable :: Solved
unsolvable = return Nothing

solve :: Constraint -> Solved
solve (i :=: cc) = lookupChoice i >>= choose cc
  where
    choose (BindTo j) ci       = lookupChoice j >>= check j ci
    choose c          NoChoice = setUnsetChoice i c
    choose c          x | c==x = solved
    choose c          ci       = unsolvable

    check j NoChoice NoChoice = setUnsetChoice i (BindTo j)

    check _ NoChoice y        = setUnsetChoice i y
    check j x        NoChoice = setUnsetChoice j x

    check _ x        y | x==y = solved

    check _ _ _               = unsolvable


----------------------------------------------------------------------
-- Data structures and operations to collect and show results
-- w.r.t. various search strategies
----------------------------------------------------------------------

-- Monadic lists as a general representation of values obtained
-- in a mondic manner. The additional constructor Abort
-- represents an incomplete list due to reaching the depth-bound in
-- iterative deepening. The constructor (WithReset lis act) represents
-- a list lis where the monadic action act has to be performed at the
-- end of the list.
data MList m a = MCons a (m (MList m a))
               | MNil
               | Abort
               | WithReset (m (MList m a)) (m ())

-- Construct an empty monadic list
mnil :: Monad m => m (MList m a)
mnil = return MNil

-- Construct a non-empty monadic list
mcons :: Monad m => a -> m (MList m a) -> m (MList m a)
mcons x xs = return (MCons x xs)

-- Aborts a monadic list due to reaching the search depth (in iter. deepening)
abort :: Monad m => m (MList m a)
abort = return Abort

-- Concatenate two monadic lists
(+++) :: Monad m => m (MList m a) -> m (MList m a) -> m (MList m a)
get +++ getYs = withReset get (return ())
 where
  withReset getList reset = do
   l <- getList
   case l of
     WithReset getList' reset' -> withReset getList' (reset >> reset')
     MNil -> reset >> getYs -- perform action before going to next list
     Abort -> reset >> abortEnd getYs
     MCons x getXs -> mcons x (withReset getXs reset) -- move action down to end

  abortEnd getYs = do -- move Abort down to end of second list
   ys <- getYs
   case ys of
     WithReset getYs' reset' -> abortEnd getYs' |< reset'
     MNil -> return Abort -- replace end of second list by Abort
     Abort  -> return Abort
     MCons z getZs -> mcons z (abortEnd getZs)

-- Add a monadic action of with result type () to the end of a monadic list.
-- Used to reset a choice made via a dfs strategy.
(|<) :: Monad m => m (MList m a) ->  m () -> m (MList m a)
l |< r = return (WithReset l r)
{-getXs |< reset = do
  xs <- getXs
  case xs of
    MCons x getTail -> mcons x (getTail |< reset)
    end -> reset >> return end
-}

-- For convencience, we define a monadic list for the IO monad:
type IOList a = MList IO a

-- Count and print the number of elements of a IO monad list:
countVals :: IOList a -> IO ()
countVals x = putStr "Number of Solutions: " >> count 0 x >>= print
  where
    count i MNil = return i
    count i (WithReset l _) = l >>= count i
    count i (MCons _ cont) = do
          let !i' = i+1
          cont >>= count i'

-- Print the first value of a IO monad list:
printOneValue :: Show a => IOList a -> IO ()
printOneValue MNil              = putStrLn "No solution"
printOneValue (MCons x getRest) = print x
printOneValue (WithReset l _) = l >>= printOneValue

-- Print all values of a IO monad list:
printAllValues :: Show a => IOList a -> IO ()
printAllValues MNil              = putStrLn "No more solutions"
printAllValues (MCons x getRest) = print x >> getRest >>= printAllValues
printAllValues (WithReset l _) = l >>= printAllValues

askKey = do
  putStr "Hit any key to terminate..."
  hFlush stdout
  hSetBuffering stdin NoBuffering
  getChar
  return ()

-- Print all values of a IO monad list on request by the user:
printValsOnDemand :: Show a => IOList a -> IO ()
printValsOnDemand = printValsInteractive True

printValsInteractive st MNil = putStrLn "No more solutions" >> askKey
printValsInteractive st (MCons x getRest) = print x >> askUser st getRest
printValsInteractive st (WithReset l _) = l >>= printValsInteractive st

-- ask the user for more values
askUser :: Show a => Bool -> IO (IOList a) -> IO ()
askUser st getrest = if not st then getrest >>= printValsInteractive st else do
  putStr "More solutions? [y(es)/n(o)/A(ll)] "
  hFlush stdout
  hSetBuffering stdin NoBuffering
  c <- getChar
  if c== '\n' then return () else putChar '\n'
  case c of
    'y'  -> getrest >>= printValsInteractive st
    'n'  -> return ()
    'a'  -> getrest >>= printValsInteractive False
    '\n' -> getrest >>= printValsInteractive False
    _    -> askUser st getrest

----------------------------------------------------------------------
-- Depth-first search into a monadic list
----------------------------------------------------------------------

-- Print all values of an expression in a depth-first manner:
printDFS :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printDFS mainexp = computeWithDFS mainexp >>= printAllValues

-- Print one value of an expression in a depth-first manner:
printDFS1 :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printDFS1 mainexp = computeWithDFS mainexp >>= printOneValue

-- Print all values on demand of an expression in a depth-first manner:
printDFSi :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printDFSi mainexp = computeWithDFS mainexp >>= printValsOnDemand

-- Compute all values of a non-deterministic goal in a depth-first manner:
computeWithDFS :: NormalForm a => (IDSupply -> a) -> IO (IOList a)
computeWithDFS mainexp =
  initSupply >>= \s -> searchDFS (try (id $!! (mainexp s)))

searchDFS :: NormalForm a => Try a -> IO (IOList a)
searchDFS Fail             = mnil

searchDFS (Free i x1 x2)   = lookupChoice i >>= choose
  where
    choose (ChooseLeft _)  = (searchDFS . try) $!< x1
    choose (ChooseRight _) = (searchDFS . try) $!< x2
    choose NoChoice    = mcons (choiceCons i x1 x2) mnil

searchDFS (Val v)          = mcons v mnil
searchDFS (Choice i x1 x2) = lookupChoice i >>= choose
  where
    choose (ChooseLeft _)  = searchDFS (try x1)
    choose (ChooseRight _) = searchDFS (try x2)
    choose NoChoice        = newChoice ChooseLeft x1 +++ newChoice ChooseRight x2

    newChoice c x = do setChoice i (c errChoice)
                       searchDFS (try x) |< setChoice i NoChoice

    errChoice = error "propagation number used within non-free Choice"

searchDFS (Guard cs e) = do
  mreset <- solves cs
  case mreset of
    Nothing    -> mnil
    Just reset -> ((searchDFS . try) $!< e) |< reset


----------------------------------------------------------------------
-- Breadth-first search into a monadic list
----------------------------------------------------------------------

-- Print all values of a non-deterministic goal in a breadth-first manner:
printBFS :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printBFS mainexp = computeWithBFS mainexp >>= printAllValues

-- Print first value of a non-deterministic goal in a breadth-first manner:
printBFS1 :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printBFS1 mainexp = computeWithBFS mainexp >>= printOneValue

-- Print all values of a non-deterministic goal in a breadth-first manner:
printBFSi :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printBFSi mainexp = computeWithBFS mainexp >>= printValsOnDemand

-- Compute all values of a non-deterministic goal in a breadth-first manner:
computeWithBFS :: NormalForm a => (IDSupply -> a) -> IO (IOList a)
computeWithBFS mainexp =
  initSupply >>= \s -> searchBFS (try (id $!! (mainexp s)))

searchBFS :: NonDet a => Try a -> IO (IOList a)
searchBFS x = bfs [] [] (return ()) (return ()) x
  where
    bfs xs ys _   reset Fail           = reset >> next xs ys
    bfs xs ys _   reset (Val v)        = reset >> mcons v (next xs ys)
    bfs xs ys set reset (Choice i x y) = set   >> lookupChoice i >>= choose

     where
        choose (ChooseLeft _)  = bfs xs ys (return ()) reset (try x)
        choose (ChooseRight _) = bfs xs ys (return ()) reset (try y)
        choose NoChoice        = do
          reset
          next xs ((newSet ChooseLeft , newReset, x) :
                   (newSet ChooseRight, newReset, y) : ys)

        newSet c = set   >> setChoice i (c errChoice)
        newReset = reset >> setChoice i NoChoice
        errChoice = error "propagation number used within non-free Choice"

    --TODO: cases for Free, Guard

    next []  []                 = mnil
    next []  ((set,reset,y):ys) = bfs ys [] set reset (try y)
    next ((set,reset,x):xs) ys  = bfs xs ys set reset (try x)

----------------------------------------------------------------------
-- Iterative depth-first search into a monadic list
----------------------------------------------------------------------

-- The initial depth size for the iterative deepening strategy:
initDepth4IDFS = 100

-- A function to increase the depth for the iterative deepening strategy:
incrDepth4IDFS n = n*2

-- Print all values of an expression with iterative deepening:
printIDS :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printIDS mainexp = computeWithIDS mainexp >>= printAllValues

-- Print one value of an expression with iterative deepening:
printIDS1 :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printIDS1 mainexp = computeWithIDS mainexp >>= printOneValue

-- Print all values on demand of an expression with iterative deepening:
printIDSi :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printIDSi mainexp = computeWithIDS mainexp >>= printValsOnDemand

-- Compute all values of a non-deterministic goal with a iterative
-- deepening strategy:
computeWithIDS :: (NormalForm a, Show a) => (IDSupply -> a) -> IO (IOList a)
--computeWithIDS goal = initSupply >>= \s -> iter s 0
--  where iter s n = startIDS (id $!! goal s) stepIDFS n ++++ iter s (n+stepIDFS)
computeWithIDS goal = initSupply >>= \s -> iter s 0 initDepth4IDFS
 where
   iter s olddepth newdepth = startIDS (id $!! goal s) olddepth newdepth
                              ++++ iter s newdepth (incrDepth4IDFS newdepth)

-- Concatenate two monadic lists if the first ends with an Abort
(++++) :: Monad m => m (MList m a) -> m (MList m a) -> m (MList m a)
get ++++ getYs = withReset get (return ())
  where
    withReset getList reset = do
     l <- getList
     case l of
       WithReset getList' reset' -> withReset getList' (reset >> reset')
       MNil -> reset >> mnil
       Abort -> reset >> getYs -- ignore Abort when concatenating further vals
       MCons x getXs -> mcons x (withReset getXs reset)

-- start iterative deepening for a given depth intervall
startIDS :: (Show a,NonDet a) => a -> Int -> Int -> IO (IOList a)
startIDS exp olddepth newdepth = idsHNF newdepth exp
 where
 idsHNF n x = case try x of
  Val v -> if n<newdepth-olddepth then mcons x mnil else mnil
  Fail  -> mnil
  Choice i x1 x2 -> do
    c <- lookupChoice i
    case c of
      (ChooseLeft _)  -> idsHNF n x1
      (ChooseRight _) -> idsHNF n x2
      NoChoice -> if n > 0
                  then choose ChooseLeft x1 +++ choose ChooseRight x2
                  else abort
     where
      choose c x = do
       setChoice i (c errChoice)
       idsHNF (n - 1) x |< setChoice i NoChoice
      errChoice = error "propagation number used within non-free Choice"


----------------------------------------------------------------------
-- Parallel search by mapping search results into monadic structure
----------------------------------------------------------------------

-- Print all values of an expression in a parallel manner:
printPar :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printPar mainexp = computeWithPar mainexp >>= printAllValues

-- Print one value of an expression in a parallel manner:
printPar1 :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printPar1 mainexp = computeWithPar mainexp >>= printOneValue

-- Print all values on demand of an expression in a parallel manner:
printPari :: (NormalForm a, Show a) => (IDSupply -> a) -> IO ()
printPari mainexp = computeWithPar mainexp >>= printValsOnDemand

list2iolist :: [a] -> IO (IOList a)
list2iolist [] = mnil
list2iolist (x:xs) = mcons x (list2iolist xs)

-- Compute all values of a non-deterministic goal in a parallel manner:
computeWithPar :: NormalForm a => (IDSupply -> a) -> IO (IOList a)
computeWithPar mainexp = do
  s <- initSupply
  list2iolist
    (parSearch (searchMPlus Data.Map.empty (try (id $!! (mainexp s)))))

type SetOfChoices = Data.Map.Map Integer Choice

lookupChoice' :: SetOfChoices -> ID -> Choice
lookupChoice' set r =
  maybe NoChoice id (Data.Map.lookup (mkInt r) set)

setChoice' :: SetOfChoices -> ID -> Choice -> SetOfChoices
setChoice' set r c = Data.Map.insert (mkInt r) c set

-- Collect results of a non-deterministic computation in a monadic structure.
searchMPlus :: (NonDet a, MonadPlus m) => SetOfChoices -> Try a -> m a
searchMPlus _   Fail           = mzero
searchMPlus _   (Val v)        = return v
searchMPlus set (Choice i x y) = choose (lookupChoice' set i)
  where
    choose (ChooseLeft _)  = searchMPlus set (try x)
    choose (ChooseRight _) = searchMPlus set (try y)
    choose NoChoice    = searchMPlus (pick ChooseLeft)  (try x)
                 `mplus` searchMPlus (pick ChooseRight) (try y)

    pick c = setChoice' set i (c errChoice)
    errChoice = error "propagation number used within non-free Choice"

----------------------------------------------------------------------
