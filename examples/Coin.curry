data List a = Nil | Cons a (List a)

coin = True ? False

selfEq x = iff x x

iff True  y = y
iff False y = mynot y

mynot True  = False
mynot False = True

goal0 = selfEq coin

