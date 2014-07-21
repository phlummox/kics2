{-# LANGUAGE ExistentialQuantification #-}

module Solver.Control (solve) where

import Debug
import Solver.Constraints (FDConstraint)
import Solver.EquationSolver (equationSolver)
import Solver.EQSolver.EQSolver (eqSolver)
import Solver.Interface (Solution, processWith)
import Solver.Overton.OvertonUtils (overtonSolver)
import Types

data Solver m a = forall c . (WrappableConstraint c) 
  => Solver (Cover -> c -> a -> Solution m a)

-- list of supported solvers
solvers :: (Store m, NonDet a) => [Solver m a]
solvers = [Solver equation, Solver overton, Solver eq]

trySolver :: (Store m, NonDet a) => Cover -> [Solver m a] -> WrappedConstraint -> a -> Solution m a
trySolver _  []                         wc _   = internalError $ 
  "Constraint not solvable with supported solvers: " ++ (show wc)
trySolver cd ((Solver process):solvers) wc val = case unwrapCs wc of
  Nothing -> trySolver cd solvers wc val
  Just c  -> do c' <- updateVars cd c
                process cd c' val

solve :: (Store m, NonDet a) => Cover -> WrappedConstraint -> a -> Solution m a
solve cd = trySolver cd solvers

overton :: (Store m, NonDet a) => Cover -> FDConstraint -> a -> Solution m a
overton = processWith overtonSolver

equation :: (Store m, NonDet a) => Cover -> EquationConstraints -> a -> Solution m a
equation = processWith equationSolver

eq :: (Store m, NonDet a) => Cover -> EQConstraints -> a -> Solution m a
eq = processWith eqSolver