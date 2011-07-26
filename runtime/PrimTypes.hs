{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
module PrimTypes where

import System.IO (Handle)

import ID
import Types

-- BinInt

data BinInt
     = Neg Nat
     | Zero
     | Pos Nat
     | Choice_BinInt ID BinInt BinInt
     | Choices_BinInt ID ([BinInt])
     | Fail_BinInt
     | Guard_BinInt ([Constraint]) BinInt

instance Show BinInt where
  showsPrec d (Choice_BinInt i x y) = showsChoice d i x y
  showsPrec d (Choices_BinInt i xs) = showsChoices d i xs
  showsPrec d (Guard_BinInt c e) = showsGuard d c e
  showsPrec _ Fail_BinInt = showChar '!'
  showsPrec _ (Neg x1) = (showString "(Neg") . ((showChar ' ') . ((shows x1) . (showChar ')')))
  showsPrec _ Zero = showString "Zero"
  showsPrec _ (Pos x1) = (showString "(Pos") . ((showChar ' ') . ((shows x1) . (showChar ')')))


instance Read BinInt where
  readsPrec d s = (readParen (d > 10) (\r -> [ (Neg x1,r1) | (_,r0) <- readQualified "Prelude" "Neg" r, (x1,r1) <- readsPrec 11 r0]) s) ++ ((readParen False (\r -> [ (Zero,r0) | (_,r0) <- readQualified "Prelude" "Zero" r]) s) ++ (readParen (d > 10) (\r -> [ (Pos x1,r1) | (_,r0) <- readQualified "Prelude" "Pos" r, (x1,r1) <- readsPrec 11 r0]) s))


instance NonDet BinInt where
  choiceCons = Choice_BinInt
  choicesCons = Choices_BinInt
  failCons = Fail_BinInt
  guardCons = Guard_BinInt
  try (Choice_BinInt i x y) = tryChoice i x y
  try (Choices_BinInt i xs) = tryChoices i xs
  try Fail_BinInt = Fail
  try (Guard_BinInt c e) = Guard c e
  try x = Val x
  match f _ _ _ _ _ (Choice_BinInt i x y) = f i x y
  match _ f _ _ _ _ (Choices_BinInt i@(NarrowedID _ _) xs) = f i xs
  match _ _ f _ _ _ (Choices_BinInt i@(FreeID _ _) xs) = f i xs
  match _ _ _ _ _ _ (Choices_BinInt i@(ChoiceID _) _) = error ("Prelude.BinInt.match: Choices with ChoiceID " ++ (show i))
  match _ _ _ f _ _ Fail_BinInt = f
  match _ _ _ _ f _ (Guard_BinInt cs e) = f cs e
  match _ _ _ _ _ f x = f x


instance Generable BinInt where
  generate s = Choices_BinInt (freeID [1,0,1] s) [(Neg (generate (leftSupply s))),Zero,(Pos (generate (leftSupply s)))]


instance NormalForm BinInt where
  ($!!) cont (Neg x1) = (\y1 -> cont (Neg y1)) $!! x1
  ($!!) cont Zero = cont Zero
  ($!!) cont (Pos x1) = (\y1 -> cont (Pos y1)) $!! x1
  ($!!) cont (Choice_BinInt i x y) = nfChoice cont i x y
  ($!!) cont (Choices_BinInt i xs) = nfChoices cont i xs
  ($!!) cont (Guard_BinInt c x) = guardCons c (cont $!! x)
  ($!!) _ Fail_BinInt = failCons
  ($##) cont (Neg x1) = (\y1 -> cont (Neg y1)) $## x1
  ($##) cont Zero = cont Zero
  ($##) cont (Pos x1) = (\y1 -> cont (Pos y1)) $## x1
  ($##) cont (Choice_BinInt i x y) = gnfChoice cont i x y
  ($##) cont (Choices_BinInt i xs) = gnfChoices cont i xs
  ($##) cont (Guard_BinInt c x) = guardCons c (cont $## x)
  ($##) _ Fail_BinInt = failCons
  ($!<) cont (Neg x1) = (\y1 -> cont (Neg y1)) $!< x1
  ($!<) cont Zero = cont Zero
  ($!<) cont (Pos x1) = (\y1 -> cont (Pos y1)) $!< x1
  ($!<) cont (Choice_BinInt i x y) = nfChoiceIO cont i x y
  ($!<) cont (Choices_BinInt i xs) = nfChoicesIO cont i xs
  ($!<) cont x = cont x
  searchNF search cont (Neg x1) = search (\y1 -> cont (Neg y1)) x1
  searchNF _      cont Zero = cont Zero
  searchNF search cont (Pos x1) = search (\y1 -> cont (Pos y1)) x1
  searchNF _ _ x = error ("Prelude.BinInt.searchNF: no constructor: " ++ (show x))


instance Unifiable BinInt where
  (=.=) (Neg x1) (Neg y1) = x1 =:= y1
  (=.=) Zero Zero = C_Success
  (=.=) (Pos x1) (Pos y1) = x1 =:= y1
  (=.=) _ _ = Fail_C_Success
  (=.<=) (Neg x1) (Neg y1) = x1 =:<= y1
  (=.<=) Zero Zero = C_Success
  (=.<=) (Pos x1) (Pos y1) = x1 =:<= y1
  (=.<=) _ _ = Fail_C_Success
  bind i (Neg x2) = ((i :=: (ChooseN 0 1)):(concat [(bind (leftID i) x2)]))
  bind i Zero = ((i :=: (ChooseN 1 0)):(concat []))
  bind i (Pos x2) = ((i :=: (ChooseN 2 1)):(concat [(bind (leftID i) x2)]))
  bind i (Choice_BinInt j l r) = [(ConstraintChoice j (bind i l) (bind i r))]
  bind i (Choices_BinInt j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  bind i (Choices_BinInt j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (bind i) xs))]
  bind _ (Choices_BinInt i@(ChoiceID _) _) = error ("Prelude.BinInt.bind: Choices with ChoiceID: " ++ (show i))
  bind _ Fail_BinInt = [Unsolvable]
  bind i (Guard_BinInt cs e) = cs ++ (bind i e)
  lazyBind i (Neg x2) = [(i :=: (ChooseN 0 1)),((leftID i) :=: (LazyBind (lazyBind (leftID i) x2)))]
  lazyBind i Zero = [(i :=: (ChooseN 1 0))]
  lazyBind i (Pos x2) = [(i :=: (ChooseN 2 1)),((leftID i) :=: (LazyBind (lazyBind (leftID i) x2)))]
  lazyBind i (Choice_BinInt j l r) = [(ConstraintChoice j (lazyBind i l) (lazyBind i r))]
  lazyBind i (Choices_BinInt j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  lazyBind i (Choices_BinInt j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (lazyBind i) xs))]
  lazyBind _ (Choices_BinInt i@(ChoiceID _) _) = error ("Prelude.BinInt.lazyBind: Choices with ChoiceID: " ++ (show i))
  lazyBind _ Fail_BinInt = [Unsolvable]
  lazyBind i (Guard_BinInt cs e) = cs ++ [(i :=: (LazyBind (lazyBind i e)))]

-- Nats

data Nat
     = IHi
     | O Nat
     | I Nat
     | Choice_Nat ID Nat Nat
     | Choices_Nat ID ([Nat])
     | Fail_Nat
     | Guard_Nat ([Constraint]) Nat

instance Show Nat where
  showsPrec d (Choice_Nat i x y) = showsChoice d i x y
  showsPrec d (Choices_Nat i xs) = showsChoices d i xs
  showsPrec d (Guard_Nat c e) = showsGuard d c e
  showsPrec _ Fail_Nat = showChar '!'
  showsPrec _ IHi = showString "IHi"
  showsPrec _ (O x1) = (showString "(O") . ((showChar ' ') . ((shows x1) . (showChar ')')))
  showsPrec _ (I x1) = (showString "(I") . ((showChar ' ') . ((shows x1) . (showChar ')')))


instance Read Nat where
  readsPrec d s = (readParen False (\r -> [ (IHi,r0) | (_,r0) <- readQualified "Prelude" "IHi" r]) s) ++ ((readParen (d > 10) (\r -> [ (O x1,r1) | (_,r0) <- readQualified "Prelude" "O" r, (x1,r1) <- readsPrec 11 r0]) s) ++ (readParen (d > 10) (\r -> [ (I x1,r1) | (_,r0) <- readQualified "Prelude" "I" r, (x1,r1) <- readsPrec 11 r0]) s))


instance NonDet Nat where
  choiceCons = Choice_Nat
  choicesCons = Choices_Nat
  failCons = Fail_Nat
  guardCons = Guard_Nat
  try (Choice_Nat i x y) = tryChoice i x y
  try (Choices_Nat i xs) = tryChoices i xs
  try Fail_Nat = Fail
  try (Guard_Nat c e) = Guard c e
  try x = Val x
  match f _ _ _ _ _ (Choice_Nat i x y) = f i x y
  match _ f _ _ _ _ (Choices_Nat i@(NarrowedID _ _) xs) = f i xs
  match _ _ f _ _ _ (Choices_Nat i@(FreeID _ _) xs) = f i xs
  match _ _ _ _ _ _ (Choices_Nat i@(ChoiceID _) _) = error ("Prelude.Nat.match: Choices with ChoiceID " ++ (show i))
  match _ _ _ f _ _ Fail_Nat = f
  match _ _ _ _ f _ (Guard_Nat cs e) = f cs e
  match _ _ _ _ _ f x = f x


instance Generable Nat where
  generate s = Choices_Nat (freeID [0,1,1] s) [IHi,(O (generate (leftSupply s))),(I (generate (leftSupply s)))]


instance NormalForm Nat where
  ($!!) cont IHi = cont IHi
  ($!!) cont (O x1) = (\y1 -> cont (O y1)) $!! x1
  ($!!) cont (I x1) = (\y1 -> cont (I y1)) $!! x1
  ($!!) cont (Choice_Nat i x y) = nfChoice cont i x y
  ($!!) cont (Choices_Nat i xs) = nfChoices cont i xs
  ($!!) cont (Guard_Nat c x) = guardCons c (cont $!! x)
  ($!!) _ Fail_Nat = failCons
  ($##) cont IHi = cont IHi
  ($##) cont (O x1) = (\y1 -> cont (O y1)) $## x1
  ($##) cont (I x1) = (\y1 -> cont (I y1)) $## x1
  ($##) cont (Choice_Nat i x y) = gnfChoice cont i x y
  ($##) cont (Choices_Nat i xs) = gnfChoices cont i xs
  ($##) cont (Guard_Nat c x) = guardCons c (cont $## x)
  ($##) _ Fail_Nat = failCons
  ($!<) cont IHi = cont IHi
  ($!<) cont (O x1) = (\y1 -> cont (O y1)) $!< x1
  ($!<) cont (I x1) = (\y1 -> cont (I y1)) $!< x1
  ($!<) cont (Choice_Nat i x y) = nfChoiceIO cont i x y
  ($!<) cont (Choices_Nat i xs) = nfChoicesIO cont i xs
  ($!<) cont x = cont x
  searchNF _      cont IHi = cont IHi
  searchNF search cont (O x1) = search (\y1 -> cont (O y1)) x1
  searchNF search cont (I x1) = search (\y1 -> cont (I y1)) x1
  searchNF _ _ x = error ("Prelude.Nat.searchNF: no constructor: " ++ (show x))


instance Unifiable Nat where
  (=.=) IHi IHi = C_Success
  (=.=) (O x1) (O y1) = x1 =:= y1
  (=.=) (I x1) (I y1) = x1 =:= y1
  (=.=) _ _ = Fail_C_Success
  (=.<=) IHi IHi = C_Success
  (=.<=) (O x1) (O y1) = x1 =:<= y1
  (=.<=) (I x1) (I y1) = x1 =:<= y1
  (=.<=) _ _ = Fail_C_Success
  bind i IHi = ((i :=: (ChooseN 0 0)):(concat []))
  bind i (O x2) = ((i :=: (ChooseN 1 1)):(concat [(bind (leftID i) x2)]))
  bind i (I x2) = ((i :=: (ChooseN 2 1)):(concat [(bind (leftID i) x2)]))
  bind i (Choice_Nat j l r) = [(ConstraintChoice j (bind i l) (bind i r))]
  bind i (Choices_Nat j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  bind i (Choices_Nat j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (bind i) xs))]
  bind _ (Choices_Nat i@(ChoiceID _) _) = error ("Prelude.Nat.bind: Choices with ChoiceID: " ++ (show i))
  bind _ Fail_Nat = [Unsolvable]
  bind i (Guard_Nat cs e) = cs ++ (bind i e)
  lazyBind i IHi = [(i :=: (ChooseN 0 0))]
  lazyBind i (O x2) = [(i :=: (ChooseN 1 1)),((leftID i) :=: (LazyBind (lazyBind (leftID i) x2)))]
  lazyBind i (I x2) = [(i :=: (ChooseN 2 1)),((leftID i) :=: (LazyBind (lazyBind (leftID i) x2)))]
  lazyBind i (Choice_Nat j l r) = [(ConstraintChoice j (lazyBind i l) (lazyBind i r))]
  lazyBind i (Choices_Nat j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  lazyBind i (Choices_Nat j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (lazyBind i) xs))]
  lazyBind _ (Choices_Nat i@(ChoiceID _) _) = error ("Prelude.Nat.lazyBind: Choices with ChoiceID: " ++ (show i))
  lazyBind _ Fail_Nat = [Unsolvable]
  lazyBind i (Guard_Nat cs e) = cs ++ [(i :=: (LazyBind (lazyBind i e)))]

-- Higher Order Funcs

-- BEGIN GENERATED FROM PrimTypes.curry
data Func t0 t1
     = Func (t0 -> IDSupply -> t1)
     | Choice_Func ID (Func t0 t1) (Func t0 t1)
     | Choices_Func ID ([Func t0 t1])
     | Fail_Func
     | Guard_Func ([Constraint]) (Func t0 t1)

instance Show (Func a b) where show = error "show for Func"

instance Read (Func a b) where readsPrec = error "readsPrec for Func"

instance NonDet (Func t0 t1) where
  choiceCons = Choice_Func
  choicesCons = Choices_Func
  failCons = Fail_Func
  guardCons = Guard_Func
  try (Choice_Func i x y) = tryChoice i x y
  try (Choices_Func i xs) = tryChoices i xs
  try Fail_Func = Fail
  try (Guard_Func c e) = Guard c e
  try x = Val x
  match f _ _ _ _ _ (Choice_Func i x y) = f i x y
  match _ f _ _ _ _ (Choices_Func i@(NarrowedID _ _) xs) = f i xs
  match _ _ f _ _ _ (Choices_Func i@(FreeID _ _) xs) = f i xs
  match _ _ _ _ _ _ (Choices_Func i@(ChoiceID _) _) = error ("Prelude.Func.match: Choices with ChoiceID " ++ (show i))
  match _ _ _ f _ _ Fail_Func = f
  match _ _ _ _ f _ (Guard_Func cs e) = f cs e
  match _ _ _ _ _ f x = f x

instance Generable (Func a b) where generate _ = error "generate for Func"

instance (NormalForm t0,NormalForm t1) => NormalForm (Func t0 t1) where
  ($!!) cont f@(Func _) = cont f
  ($!!) cont (Choice_Func i x y) = nfChoice cont i x y
  ($!!) cont (Choices_Func i xs) = nfChoices cont i xs
  ($!!) cont (Guard_Func c x) = guardCons c (cont $!! x)
  ($!!) _ Fail_Func = failCons
  ($##) cont f@(Func _) = cont f
  ($##) cont (Choice_Func i x y) = gnfChoice cont i x y
  ($##) cont (Choices_Func i xs) = gnfChoices cont i xs
  ($##) cont (Guard_Func c x) = guardCons c (cont $## x)
  ($##) _ Fail_Func = failCons
  ($!<) cont (Choice_Func i x y) = nfChoiceIO cont i x y
  ($!<) cont (Choices_Func i xs) = nfChoicesIO cont i xs
  ($!<) cont x = cont x
  searchNF search cont (Func x1) = search (\y1 -> cont (Func y1)) x1
  searchNF _ _ x = error ("Prelude.Func.searchNF: no constructor: " ++ (show x))

instance (Unifiable t0,Unifiable t1) => Unifiable (Func t0 t1) where
  (=.=) _ _ = Fail_C_Success
  (=.<=) _ _ = Fail_C_Success
  bind _ (Func _) = error "can not bind a Func"
  bind i (Choice_Func j l r) = [(ConstraintChoice j (bind i l) (bind i r))]
  bind i (Choices_Func j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  bind i (Choices_Func j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (bind i) xs))]
  bind _ (Choices_Func i@(ChoiceID _) _) = error ("Prelude.Func.bind: Choices with ChoiceID: " ++ (show i))
  bind _ Fail_Func = [Unsolvable]
  bind i (Guard_Func cs e) = cs ++ (bind i e)
  lazyBind _ (Func _) = error "can not lazily bind a Func"
  lazyBind i (Choice_Func j l r) = [(ConstraintChoice j (lazyBind i l) (lazyBind i r))]
  lazyBind i (Choices_Func j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  lazyBind i (Choices_Func j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (lazyBind i) xs))]
  lazyBind _ (Choices_Func i@(ChoiceID _) _) = error ("Prelude.Func.lazyBind: Choices with ChoiceID: " ++ (show i))
  lazyBind _ Fail_Func = [Unsolvable]
  lazyBind i (Guard_Func cs e) = cs ++ [(i :=: (LazyBind (lazyBind i e)))]
-- END GENERATED FROM PrimTypes.curry

-- BEGIN GENERATED FROM PrimTypes.curry
data C_IO t0
     = C_IO (IO t0)
     | Choice_C_IO ID (C_IO t0) (C_IO t0)
     | Choices_C_IO ID ([C_IO t0])
     | Fail_C_IO
     | Guard_C_IO Constraints (C_IO t0)

instance Show (C_IO a) where show = error "show for C_IO"

instance Read (C_IO a) where readsPrec = error "readsPrec for C_IO"

instance NonDet (C_IO t0) where
  choiceCons = Choice_C_IO
  choicesCons = Choices_C_IO
  failCons = Fail_C_IO
  guardCons = Guard_C_IO
  try (Choice_C_IO i x y) = tryChoice i x y
  try (Choices_C_IO i xs) = tryChoices i xs
  try Fail_C_IO = Fail
  try (Guard_C_IO c e) = Guard c e
  try x = Val x
  match f _ _ _ _ _ (Choice_C_IO i x y) = f i x y
  match _ f _ _ _ _ (Choices_C_IO i@(NarrowedID _ _) xs) = f i xs
  match _ _ f _ _ _ (Choices_C_IO i@(FreeID _ _) xs) = f i xs
  match _ _ _ _ _ _ (Choices_C_IO i@(ChoiceID _) _) = error ("Prelude.IO.match: Choices with ChoiceID " ++ (show i))
  match _ _ _ f _ _ Fail_C_IO = f
  match _ _ _ _ f _ (Guard_C_IO cs e) = f cs e
  match _ _ _ _ _ f x = f x

instance Generable (C_IO a) where generate _ = error "generate for C_IO"

instance (NormalForm t0) => NormalForm (C_IO t0) where
  ($!!) cont io@(C_IO _) = cont io
  ($!!) cont (Choice_C_IO i x y) = nfChoice cont i x y
  ($!!) cont (Choices_C_IO i xs) = nfChoices cont i xs
  ($!!) cont (Guard_C_IO c x) = guardCons c (cont $!! x)
  ($!!) _ Fail_C_IO = failCons
  ($##) cont io@(C_IO _) = cont io
  ($##) cont (Choice_C_IO i x y) = gnfChoice cont i x y
  ($##) cont (Choices_C_IO i xs) = gnfChoices cont i xs
  ($##) cont (Guard_C_IO c x) = guardCons c (cont $## x)
  ($##) _ Fail_C_IO = failCons
  ($!<) cont (Choice_C_IO i x y) = nfChoiceIO cont i x y
  ($!<) cont (Choices_C_IO i xs) = nfChoicesIO cont i xs
  ($!<) cont x = cont x
  searchNF _ cont io@(C_IO _) = cont io
  searchNF _ _ x = error ("Prelude.IO.searchNF: no constructor: " ++ (show x))

instance Unifiable t0 => Unifiable (C_IO t0) where
  (=.=) _ _ = Fail_C_Success
  (=.<=) _ _ = Fail_C_Success
  bind _ (C_IO _) = error "can not bind IO"
  bind i (Choice_C_IO j l r) = [(ConstraintChoice j (bind i l) (bind i r))]
  bind i (Choices_C_IO j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  bind i (Choices_C_IO j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (bind i) xs))]
  bind _ (Choices_C_IO i@(ChoiceID _) _) = error ("Prelude.IO.bind: Choices with ChoiceID: " ++ (show i))
  bind _ Fail_C_IO = [Unsolvable]
  bind i (Guard_C_IO cs e) = cs ++ (bind i e)
  lazyBind _ (C_IO _) = error "can not lazily bind IO"
  lazyBind i (Choice_C_IO j l r) = [(ConstraintChoice j (lazyBind i l) (lazyBind i r))]
  lazyBind i (Choices_C_IO j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  lazyBind i (Choices_C_IO j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (lazyBind i) xs))]
  lazyBind _ (Choices_C_IO i@(ChoiceID _) _) = error ("Prelude.IO.lazyBind: Choices with ChoiceID: " ++ (show i))
  lazyBind _ Fail_C_IO = [Unsolvable]
  lazyBind i (Guard_C_IO cs e) = cs ++ [(i :=: (LazyBind (lazyBind i e)))]
-- END GENERATED FROM PrimTypes.curry

-- ---------------------------------------------------------------------------
-- Primitive data that is built-in (e.g., Handle, IORefs,...)
-- ---------------------------------------------------------------------------

-- BEGIN GENERATED FROM PrimTypes.curry
data PrimData t0
     = PrimData t0
     | Choice_PrimData ID (PrimData t0) (PrimData t0)
     | Choices_PrimData ID ([PrimData t0])
     | Fail_PrimData
     | Guard_PrimData ([Constraint]) (PrimData t0)

instance Show (PrimData a) where show = error "show for PrimData"

instance Read (PrimData a) where readsPrec = error "readsPrec for PrimData"

instance NonDet (PrimData t0) where
  choiceCons = Choice_PrimData
  choicesCons = Choices_PrimData
  failCons = Fail_PrimData
  guardCons = Guard_PrimData
  try (Choice_PrimData i x y) = tryChoice i x y
  try (Choices_PrimData i xs) = tryChoices i xs
  try Fail_PrimData = Fail
  try (Guard_PrimData c e) = Guard c e
  try x = Val x
  match f _ _ _ _ _ (Choice_PrimData i x y) = f i x y
  match _ f _ _ _ _ (Choices_PrimData i@(NarrowedID _ _) xs) = f i xs
  match _ _ f _ _ _ (Choices_PrimData i@(FreeID _ _) xs) = f i xs
  match _ _ _ _ _ _ (Choices_PrimData i@(ChoiceID _) _) = error ("Prelude.PrimData.match: Choices with ChoiceID " ++ (show i))
  match _ _ _ f _ _ Fail_PrimData = f
  match _ _ _ _ f _ (Guard_PrimData cs e) = f cs e
  match _ _ _ _ _ f x = f x

instance Generable (PrimData a) where generate _ = error "generate for PrimData"

instance NormalForm (PrimData a) where
  ($!!) cont p@(PrimData _) = cont p
  ($!!) cont (Choice_PrimData i x y) = nfChoice cont i x y
  ($!!) cont (Choices_PrimData i xs) = nfChoices cont i xs
  ($!!) cont (Guard_PrimData c x) = guardCons c (cont $!! x)
  ($!!) _ Fail_PrimData = failCons
  ($##) cont p@(PrimData _) = cont p
  ($##) cont (Choice_PrimData i x y) = gnfChoice cont i x y
  ($##) cont (Choices_PrimData i xs) = gnfChoices cont i xs
  ($##) cont (Guard_PrimData c x) = guardCons c (cont $## x)
  ($##) _ Fail_PrimData = failCons
  ($!<) cont (Choice_PrimData i x y) = nfChoiceIO cont i x y
  ($!<) cont (Choices_PrimData i xs) = nfChoicesIO cont i xs
  ($!<) cont x = cont x
  -- no search inside argument of PrimData since it is primitive:
  searchNF _ cont (PrimData x) = cont (PrimData x)
  searchNF _ _ x = error ("Prelude.PrimData.searchNF: no constructor: " ++ (show x))

instance Unifiable (PrimData t0) where
  (=.=) _ _ = Fail_C_Success
  (=.<=) _ _ = Fail_C_Success
  bind _ (PrimData _) = error "can not bind PrimData"
  bind i (Choice_PrimData j l r) = [(ConstraintChoice j (bind i l) (bind i r))]
  bind i (Choices_PrimData j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  bind i (Choices_PrimData j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (bind i) xs))]
  bind _ (Choices_PrimData i@(ChoiceID _) _) = error ("Prelude.PrimData.bind: Choices with ChoiceID: " ++ (show i))
  bind _ Fail_PrimData = [Unsolvable]
  bind i (Guard_PrimData cs e) = cs ++ (bind i e)
  lazyBind _ (PrimData _) = error "can not lazily bind PrimData"
  lazyBind i (Choice_PrimData j l r) = [(ConstraintChoice j (lazyBind i l) (lazyBind i r))]
  lazyBind i (Choices_PrimData j@(FreeID _ _) _) = [(i :=: (BindTo j))]
  lazyBind i (Choices_PrimData j@(NarrowedID _ _) xs) = [(ConstraintChoices j (map (lazyBind i) xs))]
  lazyBind _ (Choices_PrimData i@(ChoiceID _) _) = error ("Prelude.PrimData.lazyBind: Choices with ChoiceID: " ++ (show i))
  lazyBind _ Fail_PrimData = [Unsolvable]
  lazyBind i (Guard_PrimData cs e) = cs ++ [(i :=: (LazyBind (lazyBind i e)))]
-- END GENERATED FROM PrimTypes.curry

instance ConvertCurryHaskell (PrimData a) a where -- needs FlexibleInstances
  fromCurry (PrimData a) = a
  fromCurry _            = error "PrimData with no ground term occurred"
  toCurry a = PrimData a

-- --------------------------------------------------------------------------
-- Our own implemenation of file handles (put here since used in various
-- libraries)
-- --------------------------------------------------------------------------

-- since the operation IOExts.connectToCmd uses one handle for reading and
-- writing, we implement handles either as a single handle or two handles:
data CurryHandle = OneHandle Handle | InOutHandle Handle Handle

inputHandle :: CurryHandle -> Handle
inputHandle (OneHandle h)     = h
inputHandle (InOutHandle h _) = h

outputHandle :: CurryHandle -> Handle
outputHandle (OneHandle h)     = h
outputHandle (InOutHandle _ h) = h