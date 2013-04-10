{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module ExternalSolver where

import Types

-- ---------------------------------------------------------------------------
-- Integration of external fd constraint solvers
-- ---------------------------------------------------------------------------

-- By implementing this type class, one can integrate fd constraint solvers in KiCS2:
-- @type variable s - fd constraint solver
-- @type variable c - wrappable fd constraints, which can be solved by the given solver

class WrappableConstraint c => ExternalFDSolver s c where
  -- instance specific types helping with translating and solving the wrappable constraints:

  -- |Type for representing the constraint modeling language of a specific solver
  data SolverModel s c :: *
  -- |Type for representing labeling information collected in the translation progress
  -- like the chosen labeling strategy or the labeling variables
  data LabelInfo s c :: *
  -- |Type for representing the solutions provided by a specific solver
  data Solutions s c :: *

  -- |Run a specific solver on a list of wrappable constraints
  -- The default implementation first updates the constraint variables
  -- regarding bindings introduced by (=:=).
  -- Then the constraints are translated into a solver specific modeling language
  -- which is solved afterwards.
  -- Finally the solutions provided by the specific solver are
  -- transformed into (constraint) variable bindings
  -- (i.e. by constructing guard expressions with binding constraints
  -- calling bindSolution)
  runSolver :: (Store m, NonDet a) => s -> [c] -> a -> m a
  runSolver solver wcs e = do updatedCs <- mapM updateVars wcs
                              let (solverCs,info) = translate solver updatedCs
                                  solutions       = solveWith solver solverCs info
                              return $ makeCsSolutions solver solutions e

  -- |Translate given list of wrappable constraints into the modeling language of
  -- a specific solver and collect labeling information
  translate :: s -> [c] -> (SolverModel s c, LabelInfo s c)

  -- |Solve the given solver model using the collected labeling information
  solveWith :: s -> SolverModel s c -> LabelInfo s c -> Solutions s c

  -- |Transform solutions provided by a specific solver into bindings for
  -- the occurring constraint variables
  makeCsSolutions :: NonDet a => s -> Solutions s c -> a  -> a