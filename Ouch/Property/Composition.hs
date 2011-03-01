{-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Module      :  Ouch.Property.Composition
--  Maintainer  :  Orion Jankowski
--  Stability   :  Unstable
--  Portability :


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

--------------------------------------------------------------------------------
-------------------------------------------------------------------------------}

module Ouch.Property.Composition
  (
   molecularWeight
 , molecularFormula
 , exactMass
 , atomCount
 , heavyAtomCount
 , hBondAcceptorCount
 , hBondDonorCount
 , netCharge
  ) where



import Ouch.Structure.Atom
import Ouch.Structure.Bond
import Ouch.Structure.Molecule
import Ouch.Data.Atom
import Ouch.Property.Builder


import Data.Maybe
import Data.Set as Set
import Data.List as List
import Data.Map as Map


{------------------------------------------------------------------------------}
{-------------------------------Functions--------------------------------------}
{------------------------------------------------------------------------------}




exactMass :: Property
exactMass = undefined




heavyAtomCount :: Property
heavyAtomCount =  prop
  where num m = fromIntegral $ Map.size $ Map.filter isHeavyAtom $ atomMap m
        prop = Property {propertyKey = "HEAVY"
                       , value = Right $ IntegerValue . num
                       }

atomCount :: Property
atomCount =  prop
  where num m = fromIntegral $ Map.size $ Map.filter isElement $ atomMap $ fillMoleculeValence m
        prop = Property {propertyKey = "COUNT"
                       , value = Right $ IntegerValue . num
                       }


hBondAcceptorCount :: Molecule -> Maybe Property
hBondAcceptorCount m = Just undefined


hBondDonorCount :: Molecule -> Maybe Property
hBondDonorCount m = Just undefined


netCharge :: Molecule -> Maybe Property
netCharge m = Just undefined


--molecularWeight
{------------------------------------------------------------------------------}
molecularWeight :: Property
molecularWeight = prop
  where mw m = foldl (+) 0.0 $ List.map atomMW $ Map.fold (\a -> (++) [a]) [] 
                                                          (atomMap $ fillMoleculeValence m)
        prop = Property {propertyKey = "MOLWT"
                       , value = Right $ DoubleValue . mw
                        }


--molecularFormula
{------------------------------------------------------------------------------}
molecularFormula :: Property
molecularFormula = prop
        where startMap = Map.empty
              endMap m = List.foldr (updateMap) startMap $ List.map snd $ Map.toList (atomMap m)
              -- Use foldr to accumulate and count atoms
              updateMap a m | Map.notMember (atomicSymbolForAtom a) m = Map.insert (atomicSymbolForAtom a)  1 m
                            | otherwise                               = Map.adjust (+ 1) (atomicSymbolForAtom a) m
              -- Convert the map to a list of just the elements present, and in IUPAC order
              finalList m = catMaybes $ List.map (\e -> lookupPair e $ endMap m) molecularFormulaElements
              --  Build the final output string from the map
              molFm m = List.foldr (\(e,n) -> if n>1 then ((e ++  (show n))++) else (e ++ ))  "" (finalList $ fillMoleculeValence m)
              -- simple little utility function which, strangely, is not already defined in Data.Map
              lookupPair k m = case v of
                  Just val -> Just (k, val)
                  Nothing -> Nothing
                  where v = Map.lookup k m
              prop = Property {propertyKey = "MOLFORM"
                             , value = Right $ StringValue . molFm
                              }















