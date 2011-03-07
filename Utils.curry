--- --------------------------------------------------------------------------
--- Various utility functions
---
--- This module should be further divided if it contains too much unrelated
--- things.
---
--- @author  Björn Peemöller
--- @version February 2011
--- --------------------------------------------------------------------------
module Utils where

import List (intersperse)

foldIO :: (a -> b -> IO a) -> a -> [b] -> IO a
foldIO _ a []      =  return a
foldIO f a (x:xs)  =  f a x >>= \fax -> foldIO f fax xs

liftIO :: (a -> b) -> IO a -> IO b
liftIO f m = m >>= return . f

intercalate :: [a] -> [[a]] -> [a]
intercalate xs xss = concat (intersperse xs xss)

mapFst :: (a -> b) -> (a, c) -> (b, c)
mapFst f (a, c) = (f a, c)

mapSnd :: (a -> b) -> (c, a) -> (c, b)
mapSnd f (c, a) = (c, f a)