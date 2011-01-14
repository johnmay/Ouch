{-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Module      :  Ouch.Property.Extrinsic.FingerPrint
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

module Ouch.Property.Extrinsic.Fingerprint (
    atomBits_OUCH
  , bondBits_OUCH
  , molBits_OUCH
  , molBits_N
  , molBits_ID
  , pathBits
  , findPaths
  , allPaths
  , longestPaths
  , longestLeastPath
  , longestLeastAnchoredPath
  , writeCanonicalPath
  , writeCanonicalPathWithStyle
  , (.||.)
  , (.|||.)


) where

import Data.Binary.Get as G
import Data.ByteString.Lazy as L
import Data.Binary.Builder as B
import Data.Bits
import Data.Word
import Ouch.Structure.Atom
import Ouch.Structure.Bond
import {-# SOURCE #-} Ouch.Structure.Molecule
import Ouch.Enumerate.Method
import Ouch.Property.Ring
import Ouch.Data.Atom
import Ouch.Data.Bond
import Ouch.Structure.Marker
import Ouch.Input.Smiles
import Data.Maybe
import Data.Set as Set
import Data.List as List
import Data.Map as Map
--import Debug.Trace (trace)

data Fingerprint = SimpleFingerPrint

{------------------------------------------------------------------------------}
atomBits_OUCH :: Molecule
              -> Atom
              -> Builder
atomBits_OUCH m a = let
  n = fromIntegral $ numberBondsToHeavyAtomsAtIndex m $ fromJust $ getIndexForAtom a
  i = fromInteger $ atomicNumber a
  in case a of
    Element {} ->  B.putWord64le ((bit (mod i 64)) :: Word64)
         `B.append` B.singleton ((bit n) :: Word8)
    Open {}    ->  B.putWord64le ((bit 63) :: Word64)
         `B.append` B.singleton ((bit n) :: Word8)
    _          -> B.putWord64le (0 :: Word64)
         `B.append` B.singleton (0 :: Word8)
{------------------------------------------------------------------------------}
atomBits_RECURSIVE :: Int
                   -> Molecule
                   -> Atom
                   -> Builder
atomBits_RECURSIVE depth  m a =  let
  i = fromJust $ getIndexForAtom a
  f_pb = pathBits atomBits_OUCH bondBits_OUCH
  paths = findPaths depth (PGraph m []) i
  in List.foldr (\p b -> f_pb p .||. b) B.empty paths



{------------------------------------------------------------------------------}
bondBits_OUCH :: Molecule
              -> Bond
              -> Builder
bondBits_OUCH m b = B.singleton (bit $ bondKey b::Word8)


{------------------------------------------------------------------------------}
molBits_N :: Int
          -> Molecule
          -> Builder
molBits_N depth m = B.append (sizeBits_OUCH m)
                             (moleculeBits atomBits_OUCH bondBits_OUCH depth m)


{------------------------------------------------------------------------------}
molBits_ID :: Int
           -> Molecule
           -> Builder
molBits_ID depth m = B.append (sizeBits_OUCH m)
                              (moleculeBits atomBits_R bondBits_OUCH depth m)
  where atomBits_R = atomBits_RECURSIVE depth



{------------------------------------------------------------------------------}
molBits_OUCH :: Molecule
             -> Builder
molBits_OUCH m = B.append (sizeBits_OUCH m)
                          (moleculeBits atomBits_OUCH bondBits_OUCH 7 m)


{------------------------------------------------------------------------------}
sizeBits_OUCH :: Molecule
              -> Builder
sizeBits_OUCH m = B.singleton (n::Word8)
  where n = fromIntegral $ Map.size $ atomMap m


{------------------------------------------------------------------------------}
moleculeBits :: (Molecule -> Atom -> Builder)
             -> (Molecule -> Bond -> Builder)
             -> Int
             -> Molecule
             -> Builder
moleculeBits atomB bondB depth m = let
  pathBits_OUCH = pathBits atomB bondB
  paths = allPaths depth m
  in List.foldr (\p b -> b .||. pathBits_OUCH p) B.empty paths


{------------------------------------------------------------------------------}
pathBits :: (Molecule -> Atom -> Builder)
         -> (Molecule -> Bond -> Builder)
         -> PGraph
         -> Builder
pathBits atomB bondB p@PGraph {molecule=m, vertexList=[]} = B.empty
pathBits atomB bondB p@PGraph {molecule=m, vertexList=x:[]} = let
  atom = fromJust $ getAtomAtIndex m x
  atomBits = atomB m atom
  in atomBits
pathBits atomB bondB p@PGraph {molecule=m, vertexList=x:xs} = let
  atom = fromJust $ getAtomAtIndex m x
  bond = Set.findMax $ Set.filter (\b -> (bondsTo b) == List.head xs)
                                  $ atomBondSet atom
  atomBits = atomB m atom
  bondBits = bondB m bond
  bits = B.append atomBits bondBits
  in B.append bits $ pathBits atomB bondB p {vertexList=xs}


-- Logical OR where bytes expand to the length of the longest pair
{------------------------------------------------------------------------------}
(.||.) :: Builder
       -> Builder
       -> Builder
(.||.) b1 b2 = let
  bytes1 = L.unpack $ B.toLazyByteString b1
  bytes2 = L.unpack $ B.toLazyByteString b2
  l1 = List.length bytes1
  l2 = List.length bytes2
  bytes1' | l1 > l2 = bytes1
          | otherwise = bytes1 ++ (List.replicate (l2 - l1) (0::Word8))
  bytes2' | l2 > l1 = bytes2
          | otherwise = bytes2 ++ (List.replicate (l1 - l2) (0::Word8))
  zipped = List.zip bytes1' bytes2'
  logicalOrList = List.map (\(a1, a2) -> a1 .|. a2) zipped
  in  B.fromLazyByteString $ L.pack logicalOrList

-- Logical OR where list contracts to the length of the shortest pair
{------------------------------------------------------------------------------}
(.|||.) :: Builder
        -> Builder
        -> Builder
(.|||.) b1 b2 = let
  bytes1 = L.unpack $ B.toLazyByteString b1
  bytes2 = L.unpack $ B.toLazyByteString b2
  l1 = List.length bytes1
  l2 = List.length bytes2
  zipped = List.zip bytes1 bytes2
  logicalOrList = List.map (\(a1, a2) -> a1 .|. a2) zipped
  in  B.fromLazyByteString $ L.pack logicalOrList

-- Logical OR where list expands to the length of the RIGHT argument
(.||>.) :: Builder
        -> Builder
        -> Builder
(.||>.) b1 b2 = let
  bytes1 = L.unpack $ B.toLazyByteString b1
  bytes2 = L.unpack $ B.toLazyByteString b2
  l1 = List.length bytes1
  l2 = List.length bytes2
  bytes1' | l1 > l2 = bytes1
          | otherwise = bytes1 ++ (List.replicate (l2 - l1) (0::Word8))
  zipped = List.zip bytes1' bytes2
  logicalOrList = List.map (\(a1, a2) -> a1 .|. a2) zipped
  in  B.fromLazyByteString $ L.pack logicalOrList

{------------------------------------------------------------------------------}
{-- allPaths --}
-- Returns all paths up to a given depth.  Always an even numbered list.
allPaths :: Int
         -> Molecule
         -> [PGraph]
allPaths depth m = List.foldr (\i p -> p `seq` p ++ findPaths depth (PGraph m []) i)
                              [] indexList
  where indexList = Map.keys $ atomMap m

{------------------------------------------------------------------------------}
{-- longestPaths --}
-- Returns the longest paths found in a molecule.  Because paths can go
-- in either direction, this will always be an even numbered list.
longestPaths :: Molecule
             -> [PGraph]
longestPaths m = let
  depth = Map.size (atomMap m)
  paths = allPaths depth m
  maxLength = List.maximum $ List.map pathLength paths
  longest = List.filter ((==maxLength) . pathLength) paths
  in longest

{------------------------------------------------------------------------------}
-- | Takes a molecule and a starting position that is connected to the
-- first PGraph and finds the longest chain of connections in the molecule
-- choosing only atoms that are NOT in the first PGraph.  If more than
-- one exists, returns the LONGEST LEAST of these.
longestLeastAnchoredPath :: PGraph
                         -> Int
                         -> PGraph
longestLeastAnchoredPath exclude@PGraph{vertexList=l} anchor = let
  depth = fromIntegral $ pathLength exclude
  paths = findPathsExcluding (Set.fromList l) depth (exclude {vertexList=[]}) anchor
  nonExcludedPaths = List.filter (\a -> False == hasOverlap exclude a) paths
  output | List.length nonExcludedPaths == 0 = exclude {vertexList=[]}
         | otherwise = findLongestLeastPath nonExcludedPaths 0
  in output

{------------------------------------------------------------------------------}
-- | Takes a list of paths of the same length and from the same molecule and
-- returns the "least" path according to atom ordering rules.  Used in selecting a
-- path for canonicalization.
-- Not used directly.
findLongestLeastPath :: [PGraph]   -- ^ The paths to select from
                     -> Int        -- ^ The current index being compared
                     -> PGraph     -- ^ The longest least path from starting list
--findLongestLeastPath gs i | (trace $ show gs) False = undefined
--findLongestLeastPath gs i | (trace $ "#Paths: " ++ (show $ List.length gs)) False = undefined
findLongestLeastPath [] i = PGraph emptyMolecule []
findLongestLeastPath gs i = let
  gsL = pLongest gs
  mol = molecule (gs!!0)
  ranks r acc | acc==LT            = LT
              | acc==EQ && r  ==LT = LT
              | acc==EQ && r  ==GT = GT
              | acc==EQ && r  ==EQ = EQ
              | acc==GT            = GT
  foldRanks g = List.foldr (\a acc -> ranks (ordAtom g a i) acc ) EQ gsL
  mapRanks = List.map (\a -> foldRanks a) gsL
  leastRank = List.minimum mapRanks
  gs' = List.filter ((==leastRank) . foldRanks) gsL
  output | List.length gsL == 0 =  PGraph emptyMolecule []
         | List.length gsL == 1     = gsL!!0
         | pathLength (gsL!!0) <= (fromIntegral i) = gsL!!0
         | otherwise = gs' `seq` findLongestLeastPath gs' (i+1)
  in  output



comparePaths :: PGraph
             -> PGraph
             -> Ordering
comparePaths p1 p2 |  False = undefined
comparePaths p1 p2 = let
  mol = molecule p1
  ranks r acc | acc==LT            = LT
              | acc==EQ && (r==LT) = LT
              | acc==EQ && (r==GT) = GT
              | acc==EQ && (r==EQ) = EQ
              | acc==GT            = GT
  rankMap = List.map (\i -> ordAtom p1 p2 i) [0..fromInteger ((pathLength p1) -1 )]
  output = List.foldr (\a acc -> ranks a acc) EQ rankMap
  in output


{------------------------------------------------------------------------------}
-- | Finds the longest least path in a molecule.  Used for canonicalization.
longestLeastPath :: Molecule  -- ^ The Molecule
                 -> PGraph    -- ^ The longest least path
longestLeastPath m = let
  paths = longestPaths m
  in paths `seq` findLongestLeastPath paths 0


-- | A comparison utility for ordAtom (below) that does the recursive path
-- comparison at a given index position
ordByPath :: PGraph   -- ^ The first path to compare
          -> PGraph   -- ^ The second path to compare
          -> Int      -- ^ The index to compare
          -> Ordering -- ^ The Ord result
-- ordByPath p1 p2 i | (trace $ "Index:" ++ (show i) ++ " Length A:" ++ (show $ pathLength p1) ++ " Length B:" ++ (show $ pathLength p2)) False = undefined
ordByPath p1@PGraph {molecule=m1, vertexList=l1}
          p2@PGraph {molecule=m2, vertexList=l2}
          index = ordPathList (branchPaths p1 index) (branchPaths p2 index)


bondIndexSet p p_i = Set.map (\a -> bondsTo a) $ atomBondSet $ fromJust $
                                 getAtomAtIndex (molecule p) (pathIndex p p_i)
pathIndexSet p = Set.fromList $ vertexList p
validIndexList p p_i = Set.toList $ Set.difference (bondIndexSet p p_i) (pathIndexSet p)
pLongest ps = List.filter (\p -> longest == pathLength p) ps
                  where longest = List.maximum $ (List.map pathLength ps)
branchPaths p p_i = pLongest $ List.map (\a -> longestLeastAnchoredPath p a) (validIndexList p p_i)
llBranch p p_i = findLongestLeastPath (branchPaths p p_i) 0
otherPaths p p_i = List.delete (llBranch p p_i) (branchPaths p p_i)


ordPathList :: [PGraph] -> [PGraph] -> Ordering
--ordPathList p1 p2 | (trace $ "OrdPath Compare-- A: " ++ (show p1) ++ (show p2))  False = undefined
ordPathList [] [] = EQ
ordPathList [] p = LT
ordPathList p [] = GT
ordPathList ps1 ps2 = let
  ll1 = findLongestLeastPath ps1 0
  ll2 = findLongestLeastPath ps2 0
  xp1 = List.delete ll1 ps1
  xp2 = List.delete ll2 ps2
  comp = comparePaths ll1 ll2
  output | comp /= EQ = comp
         | otherwise = ordPathList xp1 xp2
  in output

pathIndex p p_i =  (vertexList p)!!p_i



{------------------------------------------------------------------------------}
-- | Orders atoms in a path to aid in path selection.  An ugly utility to affect
-- Ord for paths.  This function assumes the molecules in both paths are the same
-- It cannot check for this because such a check implcitly relies on this function.
-- Naturally, this is never used directly.
ordAtom :: PGraph   -- ^ The first path to compare
        -> PGraph   -- ^ The second path to compare
        -> Int      -- ^ The index to compare
        -> Ordering -- ^ The Ord result
ordAtom p1 p2 p_i = let
  m = molecule p1
  i1 = pathIndex p1 p_i
  i2 = pathIndex p2 p_i
  atom1 = fromJust $ getAtomAtIndex m i1
  atom2 = fromJust $ getAtomAtIndex m i2
  atoms = Map.size $ atomMap m
  byNumber = compare (atomicNumber atom1) (atomicNumber atom2)
  byIsotope = compare (neutronNumber atom1) (neutronNumber atom2)
  byVertex = compare (Set.size $ atomBondSet atom1) (Set.size $ atomBondSet atom2)
  byPath = ordByPath p1 p2 p_i
  fAtom d = compared
    where test = compare (B.toLazyByteString $ atomBits_RECURSIVE d m atom1)
                         (B.toLazyByteString $ atomBits_RECURSIVE d m atom2)
          compared | d >= (Map.size $ atomMap m) = test
                   | test == EQ = fAtom (d+1)
                   | otherwise = test
  output = case atom1 of
            Element {} -> case atom2 of
              Element {} -> ordElements
              _  -> GT
            _  -> case atom2 of
              Element {} -> LT
              _ -> compare i1 i2

  ordElements
           -- The atoms are the same index in the molecule
          | i1 == i2     = EQ

         -- The atoms are the same element
          | byNumber    /= EQ =  byNumber

         -- Atoms are the same isotope
          | byIsotope   /= EQ = byIsotope

         -- Atoms have the same number of connections
          | byVertex    /= EQ = byVertex

          -- | fAtom atoms  /= EQ = fAtom atoms

          | byPath      /= EQ = byPath

         -- If all of the above are EQ, then the atoms REALLY ARE chemically equivalent
         -- and cannot be distinguished.
         | otherwise         = EQ
  in output


{------------------------------------------------------------------------------}
-- | Find all paths starting from a given index, but excluding traversal through
-- the indices in the given exclusion set.
-- This is a utility function, not used directly.
findPathsExcluding :: Set Int  -- ^ The atom index set to exclude from paths
                   -> Int      -- ^ The maximum depth to recursively add to path
                   -> PGraph   -- ^ The path we are recursively adding to
                   -> Int      -- ^ The atom index to add to the growing path
                   -> [PGraph] -- ^ The new paths created after terminal recursion
findPathsExcluding exclude depth path@PGraph {molecule=m, vertexList=l} index = let
  path' = path {vertexList=(l ++ [index])}
  bondIndexSet = Set.map (\a -> bondsTo a) $ atomBondSet $ fromJust
                                           $ getAtomAtIndex m index
  pathIndexSet = Set.union exclude $ Set.fromList l
  validIndexSet = Set.difference bondIndexSet pathIndexSet
  accPath i p = p `seq` p ++ (findPathsExcluding exclude depth path' i)
  paths | Set.size validIndexSet == 0      = [path']
        | List.length l > depth            = [path']
        | otherwise = Set.fold accPath [] validIndexSet
  in paths


{------------------------------------------------------------------------------}
-- | Find all possible paths starting from an atom index up to specified depth.
-- This is a utility function, not used directly.
findPaths :: Int      -- ^ The maximum depth
          -> PGraph   -- ^ The path we are building up
          -> Int      -- ^ The atom indices to add to the growing path
          -> [PGraph] -- ^ The new paths created after terminal recursion
findPaths depth path@PGraph {molecule=m, vertexList=l} index = let
  path' = path {vertexList=(l ++ [index])}
  bondIndexSet = Set.map (\a -> bondsTo a) $ atomBondSet $ fromJust
                                           $ getAtomAtIndex m index
  pathIndexSet = Set.fromList l
  validIndexSet = Set.difference bondIndexSet pathIndexSet
  accPath i p = p `seq` p ++ (findPaths depth path' i)
  paths | Set.size validIndexSet == 0      = [path']
        | List.length l > depth            = [path']
        | otherwise = Set.fold accPath [] validIndexSet
  in paths


{------------------------------------------------------------------------------}
-- | Writes the SMILES string for a given molecule
writeCanonicalPath :: Molecule -> String
writeCanonicalPath m = writeCanonicalPathWithStyle writeAtomOnly m


{------------------------------------------------------------------------------}
-- | Writes the SMILES string for a given molecule with specified atom rendering function
writeCanonicalPathWithStyle :: (PGraph -> Int -> String)  -- ^ The method used to render atoms to text
                            -> Molecule                   -- ^ The molecule to process
                            -> String                     -- ^ The output string
writeCanonicalPathWithStyle style m = let
  backbone = longestLeastPath m
  in writePath style [] backbone 0 False


{------------------------------------------------------------------------------}
-- | Writes the SMILES string for a given path with a provided atom rendering function
writePath :: (PGraph -> Int -> String)    -- ^ The method used to render atoms to text
          -> [PGraph]                     -- ^ The list of subgraphs we've already traversed
          -> PGraph                       -- ^ The subgraph we are currently traversing
          -> Int                          -- ^ The position in our current subgraph
          -> Bool                         -- ^ Are we part of a SMILES substructure
          -> String                       -- ^ The string being rendered
writePath style gx g@PGraph {molecule=m, vertexList=l} i subStructure = let
  s = style g i
  endOfPath = i >= (fromInteger $ pathLength g)
  hasNext = i + 1 < (fromInteger $ pathLength g)
  nb | hasNext = writeBond (bondBetweenIndices m  (l!!i) $ l!!(i+1) )
     | otherwise = ""
  output | endOfPath && subStructure = ")"
         | endOfPath = ""
         | otherwise =  s ++ writeSubpath style gx g i
                          ++ nb ++ writePath style gx g (i+1) subStructure
  in output


{------------------------------------------------------------------------------}
-- | Writes the SMILES strings for all subpaths (if any exist) at position i in a
-- given path g, excluding travesal through any atoms in the paths gx
writeSubpath :: (PGraph -> Int -> String) -- ^ The method used to render atoms to text
             -> [PGraph]                  -- ^ The list of subgraphs we've already traversed
             -> PGraph                    -- ^ The subgraph we are currently traversing
             -> Int                       -- ^ The position in our current subgraph
             -> String                    -- ^ The string being rendered
writeSubpath outputStyle gx g@PGraph {molecule=m, vertexList=l} i = let
  bondIndexSet = Set.map (\a -> bondsTo a) $ atomBondSet $ fromJust
                                           $ getAtomAtIndex m (l!!i)
  pathIndexSet = List.foldr (\a acc -> Set.union acc $ Set.fromList $ vertexList a)
                            Set.empty (g:gx)
  validIndexList = Set.toList $ Set.difference bondIndexSet pathIndexSet
  pathIndexList = Set.toList pathIndexSet
  branchPaths = List.map (\a -> longestLeastAnchoredPath g {vertexList=pathIndexList} a)
                         validIndexList
  nextBranch =  findLongestLeastPath branchPaths 0
  s = outputStyle g i
  output | (pathLength nextBranch) > 0 =  "(" ++ writePath outputStyle (g:gx) nextBranch 0 True
                                              ++ writeSubpath outputStyle (nextBranch:gx) g i
         | otherwise =  ""
  in output


{------------------------------------------------------------------------------}
-- | Writes atom information from position i in a path.   A debugging render
-- function.
writeAtomOnly :: PGraph   -- ^ The path
              -> Int      -- ^ The path position to render
              -> String   -- ^ The output String
writeAtomOnly g i = let
  mol = molecule g
  atom = fromJust $ getAtomAtIndex mol ((vertexList g)!!i)
  in atomicSymbolForAtom atom

bip :: PGraph
         -> Int
         -> String
bip  _ _ = "*"

writeBip :: Molecule -> String
writeBip m = writeCanonicalPathWithStyle bip m'
  where m':_ = [m] >#> stripMol

{------------------------------------------------------------------------------}
-- | Basic rendering of bond information for SMILES.  Similar to Show.
writeBond :: NewBond  -- ^ The bond to render
          -> String   -- ^ The rendered string
writeBond nb = case nb of
  Single -> ""
  Double -> "="
  Triple -> "#"
  NoBond -> "."

