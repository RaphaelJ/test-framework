module Test.Framework.QuickCheck (
        PropertyResult(..), propertySucceeded,
        runProperty,
        
        -- Re-exports from QuickCheck
        Testable(..)
    ) where

import Test.Framework.Options
import Test.Framework.Seed
import Test.Framework.Utilities

import Test.QuickCheck

import Data.List

import System.Random


-- | The failure information from the run of a property
data PropertyResult = PropertyOK Int                   -- ^ The property is true as far as we could check it, passing the given number of tests.
                    | PropertyArgumentsExhausted Int   -- ^ The property may be true, but we ran out of arguments to try it out on.
                                                       -- We were only able to try the given number of tests.
                    | PropertyFalsifiable Int [String] -- ^ The property was not true. The @Int@ is the number of tests required to
                                                       -- discover this, and the list of strings are the arguments inducing failure.

instance Show PropertyResult where
    show (PropertyOK ntest)                     = "OK, passed " ++ show ntest ++ " tests"
    show (PropertyArgumentsExhausted ntest)     = "Arguments exhausted after " ++ show ntest ++ " tests"
    show (PropertyFalsifiable ntests test_args) = "Falsifiable, after " ++ show ntests ++ " tests:\n" ++ unlinesConcise test_args

propertySucceeded :: PropertyResult -> Bool
propertySucceeded (PropertyOK _)                 = True
propertySucceeded (PropertyArgumentsExhausted _) = True
propertySucceeded _                              = False


runProperty :: Testable a => CompleteTestOptions -> a -> IO PropertyResult
runProperty topts testable = do
    gen <- newSeededStdGen (unK $ topt_seed topts)
    myCheck (unK $ topt_quickcheck_options topts) gen testable

-- The following somewhat ripped out of the QuickCheck source code so that
-- I can customise the random number generator used to do the checking etc
myCheck :: (Testable a) => CompleteQuickCheckOptions -> StdGen -> a -> IO PropertyResult
myCheck qcoptions rnd a = myTests qcoptions (evaluate a) rnd 0 0 []

myTests :: CompleteQuickCheckOptions -> Gen Result -> StdGen -> Int -> Int -> [[String]] -> IO PropertyResult
myTests qcoptions gen rnd0 ntest nfail stamps
  | ntest == unK (qcopt_maximum_tests qcoptions)    = do return (PropertyOK ntest)
  | nfail == unK (qcopt_maximum_failures qcoptions) = do return (PropertyArgumentsExhausted ntest)
  | otherwise               =
      do case ok result of
           Nothing    ->
             myTests qcoptions gen rnd1 ntest (nfail + 1) stamps
           Just True  ->
             myTests qcoptions gen rnd1 (ntest + 1) nfail (stamp result:stamps)
           Just False -> do
             return $ PropertyFalsifiable ntest (arguments result)
  where
    result       = generate (configSize defaultConfig ntest) rnd2 gen
    (rnd1, rnd2) = split rnd0