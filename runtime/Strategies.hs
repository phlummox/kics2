{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE MagicHash, UnboxedTuples #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Strategies
  ( bfsSearch, dfsSearch, parSearch, fairSearch, conSearch
  , idsSearch, idsDefaultDepth, idsDefaultIncr
  , splitAll, splitLimitDepth, splitAlternating, splitPower
  , splitAll'
  , bfsParallel, bfsParallel'
  , fairSearch', fairSearch''
  , dfsBag, fdfsBag, bfsBag, fairBag, getAllResults, getResult
  , dfsBagLazy, fdfsBagLazy, bfsBagLazy, fairBagLazy
  ) where

import System.IO (hPutStr, stderr)
import Control.Monad.SearchTree
import Control.Parallel.TreeSearch (parSearch)
import Control.Parallel.Strategies
import Data.IORef (newIORef, mkWeakIORef, IORef, writeIORef)
import Data.List (delete)
import Data.Typeable (Typeable)
import Control.Monad (liftM, void)
import Control.Exception (Exception, uninterruptibleMask_, throwTo, catch, catches, try, evaluate, Handler (..))
import Control.Concurrent (forkIO, myThreadId, ThreadId, killThread, forkIOWithUnmask)
import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent.Bag.TaskBuffer
  ( TaskBufferSTM
  , SplitFunction
  , BufferType (..) )
import Control.Concurrent.Bag.Task
  ( TaskIO
  , addTaskIO
  , Interruptible (..) )
import qualified Control.Concurrent.Bag.Implicit as Implicit
  ( newTaskBag
  , newInterruptibleBag
  , newInterruptingBag )
import Control.Concurrent.Bag.Safe
  ( newTaskBag
  , newInterruptingBag
  , newInterruptibleBag
  , BagT
  , getAllResults
  , getResult )
import Control.Concurrent.STM (TChan)
import Control.Concurrent.STM.TStack (TStack)
import Control.Monad.IO.Class
import System.Mem.Weak

import MonadSearch
import MonadList

instance MonadSearch SearchTree where
  constrainMSearch _ _ x = x
  var              x _   = x

dfsBag :: MonadIO m => Maybe (SplitFunction r) -> SearchTree r -> BagT r m a -> m a
dfsBag split = (newTaskBag Stack split) . (:[]) . dfsTask

dfsBagLazy :: Maybe (SplitFunction r) -> SearchTree r -> IO [r]
dfsBagLazy split = (Implicit.newTaskBag Stack split) . (:[]) . dfsTask

-- | Fake depth-first search
--   Real depth-first search would use a stack instead of a queue for
--   the task bag.
fdfsBag :: MonadIO m => Maybe (SplitFunction r) -> SearchTree r -> BagT r m a -> m a
fdfsBag split = (newTaskBag Queue split) . (:[]) . dfsTask

fdfsBagLazy :: Maybe (SplitFunction r) -> SearchTree r -> IO [r]
fdfsBagLazy split = (Implicit.newTaskBag Queue split) . (:[]) . dfsTask

dfsTask :: SearchTree a -> TaskIO a (Maybe a)
dfsTask None         = return   Nothing
dfsTask (One v)      = return $ Just v
dfsTask (Choice l r) = do
  addTaskIO $ dfsTask r
  dfsTask l

bfsBagLazy :: Maybe (SplitFunction r) -> SearchTree r -> IO [r]
bfsBagLazy split = (Implicit.newInterruptibleBag Queue split) . (:[]) . bfsTask

bfsBag :: MonadIO m => Maybe (SplitFunction r) -> SearchTree r -> BagT r m a -> m a
bfsBag split = (newInterruptibleBag Queue split) . (:[]) . bfsTask

bfsTask None         = NoResult
bfsTask (One v)      = OneResult v
bfsTask (Choice l r) = AddInterruptibles [bfsTask l, bfsTask r]

fairBagLazy :: Maybe (SplitFunction r) -> SearchTree r -> IO [r]
fairBagLazy split = (Implicit.newInterruptingBag Queue split) . (:[]) . bfsTask

fairBag :: MonadIO m => Maybe (SplitFunction r) -> SearchTree r -> BagT r m a -> m a
fairBag split = (newInterruptingBag Queue split) . (:[]) . bfsTask

-- | Parallel Breadth-first search
bfsParallel :: SearchTree a -> [a]
bfsParallel t = bfs [t]
 where
  bfs :: [SearchTree a] -> [a]
  bfs [] = []
  bfs xs = runEval $ do
    rs <- evalList rpar $ xs
    return $ values rs ++ (bfs $ children rs)

bfsParallel' :: SearchTree a -> [a]
bfsParallel' t =
  bfsSearch (t `using` parTree)

parTree :: SearchTree a -> Eval (SearchTree a)
parTree t = do
  t' <- rseq t
  case t' of
    Choice l r -> do
      l' <- (rpar `dot` parTree) l
      r' <- (rpar `dot` parTree) r
      return (Choice l' r')
    _          -> r0 t

splitAll :: SearchTree a -> [a]
splitAll None         = []
splitAll (One x )     = [x]
splitAll (Choice l r) = runEval $ do
  rs <- rpar $ splitAll r
  ls <- rseq $ splitAll l
  return $ ls ++ rs

splitAll' :: SearchTree a -> [a]
splitAll' t = dfsSearch (t `using` parTree)

splitLimitDepth :: Int -> SearchTree a -> [a]
splitLimitDepth _ None           = []
splitLimitDepth _ (One x)        = [x]
splitLimitDepth 0 c@(Choice _ _) = dfsSearch c
splitLimitDepth i   (Choice l r) = runEval $ do
  rs <- rpar $ splitLimitDepth (i-1) r
  ls <- rseq $ splitLimitDepth (i-1) l
  return $ ls ++ rs

splitAlternating :: Int -> SearchTree a -> [a]
splitAlternating n = splitAlternating' 1 n
 where
  splitAlternating' :: Int -> Int -> SearchTree a -> [a]
  splitAlternating' _ _ None         = []
  splitAlternating' _ _ (One x)      = [x]
  splitAlternating' 1 n (Choice l r) = runEval $ do
    rs <- rpar $ splitAlternating' n n l
    ls <- rseq $ splitAlternating' n n r
    return $ ls ++ rs
  splitAlternating' i n (Choice l r) =
    let ls = splitAlternating' (i-1) n l
        rs = splitAlternating' (i-1) n r
    in ls ++ rs

splitPower :: SearchTree a -> [a]
splitPower = splitPower' 1 2
 where
  splitPower' _ _ None = []
  splitPower' _ _ (One x) = [x]
  splitPower' 1 n (Choice l r) = runEval $ do
    rs <- rpar $ splitPower' n (n*2) r
    ls <- rseq $ splitPower' n (n*2) l
    return $ ls ++ rs
  splitPower' i n (Choice l r) =
    let ls = splitPower' (i-1) n l
        rs = splitPower' (i-1) n r
    in ls ++ rs

fairSearch :: SearchTree a -> MList IO a
fairSearch = conSearch (-1)

data ExecutionState = Stopped
                 -- number of threads left / running threads
                  | Executing Int [ThreadId]

data ThreadResult a = ThreadStopped ThreadId
                    | Value         a

-- | A parallel search implemented with concurrent Haskell
conSearch :: Int         -- ^ The maximum number of threads to use
         -> SearchTree a -- ^ The search tree to search in
         -> MList IO a
conSearch i tree = do
  threadVar <- newMVar $ Executing i []
  resultChan <- newChan

  -- The following dummy IORef is just used to have a trigger for the
  -- finalizer to kill remaining threads.
  -- The naive implementation, using a weak reference on the Chan does not work
  -- as expected. The problem is the following:
  --   The threads need to be killed when there is no reference on the IOList
  --   anymore. This will be done in the finalizer "killThreads threadVar".
  --   Setting this as a finalizer for the result Chan requires using weak
  --   references to the Chan in the search threads. The GHC runtime now detects
  --   that there is only one reference to the Chan, the reference in
  --   handleResults. Here the program wants to read from the Chan and the GHC
  --   runtime detects that this will be never successful (as there is no
  --   reference to the Chan in another thread). The GHC runtime stops the
  --   waiting thread, the last reference to the Chan is removed, the garbage
  --   collector fires the finalizer and all search threads are killed.
  dummyRef <- newIORef ()
  _ <- mkWeakIORef dummyRef $ killThreads threadVar

  startSearchThread threadVar resultChan tree
  handleResults dummyRef threadVar resultChan
 where
  removeThread :: ThreadId -> ExecutionState -> ExecutionState
  removeThread tid Stopped = Stopped
  removeThread tid (Executing n tids) =
    Executing (n+1) $ delete tid tids

  killThreads :: MVar ExecutionState -> IO ()
  killThreads threadVar = do
    executeState <- takeMVar threadVar
    case executeState of
      Stopped ->
        hPutStr stderr "Execution already stopped!"
      Executing _ tids ->
        mapM_ (forkIO . killThread) tids
    putMVar threadVar Stopped

  handleResults :: IORef () -> MVar ExecutionState -> Chan (ThreadResult a) -> MList IO a
  handleResults dummyRef threadVar resultChan = do
     -- this is for the optimizer not to optimize out the dummyRef
    writeIORef dummyRef ()
    result <- readChan resultChan
    case result of
      ThreadStopped tid -> do
        state <- modifyMVar threadVar $ return . (\a -> (a,a)) . (removeThread tid)
        case state of
          Executing _ (_:_) ->
            handleResults dummyRef threadVar resultChan
          _ ->
            mnil
      Value a  ->
        mcons a $ handleResults dummyRef threadVar resultChan

  startSearchThread :: MVar ExecutionState -> Chan (ThreadResult a) -> SearchTree a -> IO ()
  startSearchThread threadVar chan tree = do
    executeState <- takeMVar threadVar
    case executeState of
      Stopped -> do
        putMVar threadVar executeState
      Executing 0 tids -> do
        putMVar threadVar executeState
        searchThread threadVar chan tree
      Executing n tids -> do
        newTid <- forkIO $ do
          searchThread threadVar chan tree
          tid <- myThreadId
          writeChan chan $ ThreadStopped tid
        putMVar threadVar $ Executing (n-1) $ newTid:tids

  searchThread :: MVar ExecutionState -> Chan (ThreadResult a) -> SearchTree a -> IO ()
  searchThread threadVar resultChan tree =
    case tree of
      None  ->
        return ()
      One x -> do
        writeChan resultChan $ Value x
      Choice x y -> do
        startSearchThread threadVar resultChan y
        searchThread      threadVar resultChan x

data Stop = Stop
  deriving (Typeable, Show)

instance Exception Stop

fairSearch' :: SearchTree a -> MList IO a
fairSearch' tree = do
  chan  <- newChan
  root  <- uninterruptibleMask_ $ forkIOWithUnmask (\restore -> searchThread restore chan tree)
  dummy <- newIORef ()
  _     <- mkWeakIORef dummy $ void $ forkIO $ throwTo root Stop
  handleResults chan dummy
 where
  handleResults chan dummy = do
    ans <- readChan chan
    case ans of
      ThreadStopped _ -> do
        writeIORef dummy ()
        mnil
      Value v         -> mcons v $ handleResults chan dummy

  fin parent = do
    tid <- myThreadId
    writeChan parent $ ThreadStopped tid

  searchThread :: (forall a. IO a -> IO a) -> Chan (ThreadResult b) -> SearchTree b -> IO ()
  searchThread restore parent tree = do
    tree' <- restore (evaluate tree) `catch` (\Stop -> return None)
    case tree' of
      None  ->
        fin parent
      One v -> do
        writeChan parent $ Value v
        fin parent
      Choice l r -> do
        chan <- newChan
        t1   <- forkIO $ searchThread restore chan l
        t2   <- forkIO $ searchThread restore chan r
        listenChan restore [t1,t2] chan parent
   where
    listenChan _       []  _    parent = do
      fin parent
    listenChan restore ts chan parent = do
      ans <- restore (liftM Just $ readChan chan) `catch` (\Stop -> do
        mapM_ (\t -> throwTo t Stop) ts
        return Nothing)
      case ans of
        Just (ThreadStopped t) -> listenChan restore (delete t ts) chan parent
        Just value             -> do
          writeChan parent value
          listenChan restore ts chan parent
        Nothing                -> return ()

data ThreadResult' a = Value' a
                     | AllStopped

data StoppedSearch = StoppedSearch ThreadId
  deriving (Typeable, Show)

instance Exception StoppedSearch

fairSearch'' :: SearchTree a -> MList IO a
fairSearch'' tree = do
  chan <- newChan
  root <- uninterruptibleMask_ $ forkIOWithUnmask $ \restore -> searchThread restore (writeChan chan AllStopped) chan [] tree
  dummy <- newIORef ()
  _     <- mkWeakIORef dummy $ throwTo root Stop
  handleResults chan dummy
 where
  handleResults chan dummy = do
    ans <- readChan chan
    case ans of
      AllStopped ->
        writeIORef dummy () >> mnil
      Value' v   ->
        mcons v $ handleResults chan dummy

  fin :: (forall a. IO a -> IO a) -> IO () -> [ThreadId] -> IO ()
  fin restore end []      =
    end
  fin restore end threads = do
    m <- newEmptyMVar
    restore (void $ takeMVar m) `catches`
      [Handler (\Stop        -> stopChildren end threads),
       Handler (\(StoppedSearch tid) -> fin restore end (tid `delete` threads))]

  stopChildren :: IO () -> [ThreadId] -> IO ()
  stopChildren end threads = mapM_ (\t -> throwTo t Stop) threads >> end

  searchThread :: (forall a. IO a -> IO a) -> IO () -> Chan (ThreadResult' b) -> [ThreadId] -> SearchTree b -> IO ()
  searchThread restore end chan threads tree = do
    r <- try (try (restore $ evaluate tree))
    case r of
      Left Stop                  -> stopChildren end threads
      Right (Left (StoppedSearch tid)) -> searchThread restore end chan (tid `delete` threads) tree
      Right (Right t)            ->
        case t of
          None  -> fin restore end threads
          One v -> do
            -- v is already normal form
            tr <- try (restore $ writeChan chan $ Value' v)
            case tr of
              Left  Stop -> stopChildren end threads
              Right ()   -> fin restore end threads
          Choice l r -> do
            tid <- myThreadId
            child <- forkIO $ searchThread restore (myThreadId >>= (throwTo tid) . StoppedSearch) chan [] r
            searchThread restore end chan (child:threads) l

-- |Breadth-first search
bfsSearch :: SearchTree a -> [a]
bfsSearch t = bfs [t]
  where
  bfs [] = []
  bfs ts = values ts ++ bfs (children ts)

values :: [SearchTree a] -> [a]
values []           = []
values (One x : ts) = x : values ts
values (_     : ts) = values ts

children :: [SearchTree a] -> [SearchTree a]
children []                = []
children (Choice x y : ts) = x : y : children ts
children (_          : ts) = children ts

-- |Depth first search
dfsSearch :: SearchTree a -> [a]
dfsSearch None         = []
dfsSearch (One      x) = [x]
dfsSearch (Choice x y) = dfsSearch x ++ dfsSearch y

idsDefaultDepth :: Int
idsDefaultDepth = 100

idsDefaultIncr :: Int -> Int
idsDefaultIncr = (*2)

-- |Return all values in a search tree via iterative-deepening search.
-- The first argument is the initial depth bound and
-- the second argument is a function to increase the depth in each
-- iteration.
idsSearch :: Int -> (Int -> Int) -> SearchTree a -> [a]
idsSearch initdepth incr st = iterIDS initdepth (collectBounded 0 initdepth st)
  where
  iterIDS _ Nil         = []
  iterIDS n (Cons x xs) = x : iterIDS n xs
  iterIDS n Abort       = let newdepth = incr n
                          in  iterIDS newdepth (collectBounded n newdepth st)

-- |Collect solutions within some level bounds in a tree.
collectBounded :: Int -> Int -> SearchTree a -> AbortList a
collectBounded oldbound newbound st = collectLevel newbound st
  where
  collectLevel _ None          = Nil
  collectLevel d (One      x)
    | d <= newbound - oldbound = x `Cons` Nil
    | otherwise                = Nil
  collectLevel d (Choice x y)
    | d > 0     = collectLevel (d-1) x +! collectLevel (d-1) y
    | otherwise = Abort

-- |List containing 'Abort's to implement the iterative depeening strategy
data AbortList a = Nil | Cons a (AbortList a) | Abort

-- |Concatenation on abort lists where aborts are moved to the right
(+!) :: AbortList a -> AbortList a -> AbortList a
(+!) Abort       Abort       = Abort
(+!) Abort       Nil         = Abort
(+!) Abort       (Cons x xs) = x `Cons` (Abort +! xs)
(+!) Nil         ys          = ys
(+!) (Cons x xs) ys          = x `Cons` (xs +! ys)
