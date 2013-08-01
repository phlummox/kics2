{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE CPP #-}

module SolverControl where

import ExternalSolver
import FDData (FDConstraint, BConstraint)
import OvertonSolver (OvertonSolver)
import SatSolver (SatSolver)
import Types

#ifdef GECODE
import GecodeSolver (GecodeSolver)
#endif

data Solver = forall c s. (WrappableConstraint c, ExternalSolver s) 
  => Solver ([c] -> s Constraints)

-- filter heterogenous wrapped constraint list for constraints of a given type
filterCs :: WrappableConstraint c => [WrappedConstraint] 
         -> ([c],[WrappedConstraint])
filterCs [] = ([],[])
filterCs (wc:wcs) = let (cs,wcs') = filterCs wcs
                    in case unwrapCs wc of Just c  -> (c:cs,wcs')
                                           Nothing -> (cs,wc:wcs')

-- list of supported constraint solvers
solvers :: [Solver]
#ifdef GECODE
solvers = [Solver gecode, Solver overton, Solver sat]
#else
solvers = [Solver overton, Solver sat]
#endif

-- try to solve all constraints of the heterogenous list of wrappable
-- constraints by filtering the list for constraints of the supported solvers
-- if constraints of supported type are found, run the corresponding solver
-- otherwise try the next solver in the list
solveAll :: (Store m, NonDet a) => [WrappedConstraint] -> [Solver] -> a -> m a
solveAll wcs []                        _ = error $ 
  "SolverControl.solveAll: Not solvable with supported solvers: " ++ show wcs
solveAll wcs ((Solver solver):solvers) e = case filterCs wcs of 
  ([],[])   -> return $ failCons 0 defFailInfo
  ([],wcs') -> solveAll wcs' solvers e
  (cs,[])   -> do updatedCs <- mapM updateVars cs
                  let bindings = run $ solver updatedCs
                  return $ guardCons defCover bindings e
  (cs,wcs') -> do updatedCs <- mapM updateVars cs
                  let bindings = run $ solver updatedCs
                  e' <- solveAll wcs' solvers e
                  return $ guardCons defCover bindings e'

#ifdef GECODE
-- Run the Gecode-Solver provided by the MCP framework
gecode :: [FDConstraint] -> GecodeSolver Constraints
gecode = eval
#endif

-- Run the Overton-Solver provided by the MCP framework
overton :: [FDConstraint] -> OvertonSolver Constraints
overton = eval

-- Run the SAT-Solver by Sebastian Fischer
sat :: [BConstraint] -> SatSolver Constraints
sat = eval