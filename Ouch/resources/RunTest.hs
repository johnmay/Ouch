{------------------------------------------------------------------------------
-------------------------------------------------------------------------------
    Main - an executable test module

    Copyright (c) 2010 Orion D. Jankowski


    This file is part of Ouch, a chemical informatics toolkit
    written entirely in Haskell.

    Ouch is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ouch is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Ouch.  If not, see <http://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------
------------------------------------------------------------------------------}
-- ghc --make -O2 -fforce-recomp -prof -auto-all -caf-all Main.hs -o a.out
-- ghc --make -O2 -fforce-recomp Main.hs -o a.out
-- time ./a.out tests.txt +RTS -sstderr -p -K100M
--
{-# LANGUAGE ForeignFunctionInterface, CPP, Generics #-}


import Ouch.Test.Methods
import Ouch.Structure.Molecule
import Ouch.Structure.Atom
import Ouch.Structure.Bond
import Ouch.Structure.Marker
import Ouch.Input.Smiles
import Ouch.Data.Atom
import Ouch.Property.Property
import Ouch.Property.Ring
import System.IO
import System.Environment
import Data.Time.Clock
import Data.Either
import Data.Maybe
import Data.List as List
import Data.Map as Map
import Data.Set as Set



-------------------------------------------------------------------------------
main = do
    (n:_) <- getArgs
    input <- readFile n
    let tests = List.map makeTestFromString $ lines input
    let (summary, errorLog) = performTests tests
    time1 <- getCurrentTime
    putStrLn $ performTests tests `seq` summary
    time2 <- getCurrentTime

    putStrLn $ "\t" ++ (show $ diffUTCTime time2 time1)
            ++ " seconds."
    writeFile "errorLog.txt" errorLog

-------------------------------------------------------------------------------

