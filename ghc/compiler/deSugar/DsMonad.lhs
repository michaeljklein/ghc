%
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1998
%
\section[DsMonad]{@DsMonad@: monadery used in desugaring}

\begin{code}
module DsMonad (
	DsM,
	initDs, returnDs, thenDs, andDs, mapDs, listDs,
	mapAndUnzipDs, zipWithDs, foldlDs,
	uniqSMtoDsM,
	newTyVarsDs, cloneTyVarsDs,
	duplicateLocalDs, newSysLocalDs, newSysLocalsDs,
	newFailLocalDs,
	getSrcLocDs, putSrcLocDs,
	getModuleDs,
	getUniqueDs, getUniquesDs,
	getDOptsDs,
	dsLookupGlobalValue,

	dsWarn, 
	DsWarnings,
	DsMatchContext(..)
    ) where

#include "HsVersions.h"

import TcHsSyn		( TypecheckedPat, TypecheckedMatchContext )
import Bag		( emptyBag, snocBag, Bag )
import ErrUtils 	( WarnMsg )
import Id		( mkSysLocal, setIdUnique, Id )
import Module		( Module )
import Var		( TyVar, setTyVarUnique )
import Outputable
import SrcLoc		( noSrcLoc, SrcLoc )
import Type             ( Type )
import UniqSupply	( initUs_, splitUniqSupply, uniqFromSupply, uniqsFromSupply,
			  UniqSM, UniqSupply )
import Unique		( Unique )
import Name		( Name )
import CmdLineOpts	( DynFlags )

infixr 9 `thenDs`
\end{code}

Now the mondo monad magic (yes, @DsM@ is a silly name)---carry around
a @UniqueSupply@ and some annotations, which
presumably include source-file location information:
\begin{code}
type DsM result =
	DynFlags
	-> UniqSupply
        -> (Name -> Id)		-- Lookup well-known Ids
	-> SrcLoc		-- to put in pattern-matching error msgs
	-> Module       	-- module: for SCC profiling
	-> DsWarnings
	-> (result, DsWarnings)

type DsWarnings = Bag WarnMsg           -- The desugarer reports matches which are
					-- completely shadowed or incomplete patterns

{-# INLINE andDs #-}
{-# INLINE thenDs #-}
{-# INLINE returnDs #-}

-- initDs returns the UniqSupply out the end (not just the result)

initDs  :: DynFlags
	-> UniqSupply
	-> (Name -> Id)
	-> Module   -- module name: for profiling
	-> DsM a
	-> (a, DsWarnings)

initDs dflags init_us lookup mod action
  = action dflags init_us lookup noSrcLoc mod emptyBag

thenDs :: DsM a -> (a -> DsM b) -> DsM b
andDs  :: (a -> a -> a) -> DsM a -> DsM a -> DsM a

thenDs m1 m2 dflags us genv loc mod warns
  = case splitUniqSupply us		    of { (s1, s2) ->
    case (m1 dflags s1 genv loc mod warns)  of { (result, warns1) ->
    m2 result dflags s2 genv loc mod warns1}}

andDs combiner m1 m2 dflags us genv loc mod warns
  = case splitUniqSupply us		    of { (s1, s2) ->
    case (m1 dflags s1 genv loc mod warns)  of { (result1, warns1) ->
    case (m2 dflags s2 genv loc mod warns1) of { (result2, warns2) ->
    (combiner result1 result2, warns2) }}}

returnDs :: a -> DsM a
returnDs result dflags us genv loc mod warns = (result, warns)

listDs :: [DsM a] -> DsM [a]
listDs []     = returnDs []
listDs (x:xs)
  = x		`thenDs` \ r  ->
    listDs xs	`thenDs` \ rs ->
    returnDs (r:rs)

mapDs :: (a -> DsM b) -> [a] -> DsM [b]

mapDs f []     = returnDs []
mapDs f (x:xs)
  = f x		`thenDs` \ r  ->
    mapDs f xs	`thenDs` \ rs ->
    returnDs (r:rs)

foldlDs :: (a -> b -> DsM a) -> a -> [b] -> DsM a

foldlDs k z []     = returnDs z
foldlDs k z (x:xs) = k z x `thenDs` \ r ->
		     foldlDs k r xs

mapAndUnzipDs :: (a -> DsM (b, c)) -> [a] -> DsM ([b], [c])

mapAndUnzipDs f []     = returnDs ([], [])
mapAndUnzipDs f (x:xs)
  = f x		    	`thenDs` \ (r1, r2)  ->
    mapAndUnzipDs f xs	`thenDs` \ (rs1, rs2) ->
    returnDs (r1:rs1, r2:rs2)

zipWithDs :: (a -> b -> DsM c) -> [a] -> [b] -> DsM [c]

zipWithDs f []	   ys = returnDs []
zipWithDs f (x:xs) (y:ys)
  = f x y		`thenDs` \ r  ->
    zipWithDs f xs ys	`thenDs` \ rs ->
    returnDs (r:rs)
\end{code}

And all this mysterious stuff is so we can occasionally reach out and
grab one or more names.  @newLocalDs@ isn't exported---exported
functions are defined with it.  The difference in name-strings makes
it easier to read debugging output.

\begin{code}
newSysLocalDs, newFailLocalDs :: Type -> DsM Id
newSysLocalDs ty dflags us genv loc mod warns
  = case uniqFromSupply us of { assigned_uniq ->
    (mkSysLocal FSLIT("ds") assigned_uniq ty, warns) }

newSysLocalsDs tys = mapDs newSysLocalDs tys

newFailLocalDs ty dflags us genv loc mod warns
  = case uniqFromSupply us of { assigned_uniq ->
    (mkSysLocal FSLIT("fail") assigned_uniq ty, warns) }
	-- The UserLocal bit just helps make the code a little clearer

getUniqueDs :: DsM Unique
getUniqueDs dflags us genv loc mod warns
  = (uniqFromSupply us, warns)

getUniquesDs :: DsM [Unique]
getUniquesDs dflags us genv loc mod warns
  = (uniqsFromSupply us, warns)

getDOptsDs :: DsM DynFlags
getDOptsDs dflags us genv loc mod warns
  = (dflags, warns)

duplicateLocalDs :: Id -> DsM Id
duplicateLocalDs old_local dflags us genv loc mod warns
  = case uniqFromSupply us of { assigned_uniq ->
    (setIdUnique old_local assigned_uniq, warns) }

cloneTyVarsDs :: [TyVar] -> DsM [TyVar]
cloneTyVarsDs tyvars dflags us genv loc mod warns
  = (zipWith setTyVarUnique tyvars (uniqsFromSupply us), warns)
\end{code}

\begin{code}
newTyVarsDs :: [TyVar] -> DsM [TyVar]
newTyVarsDs tyvar_tmpls dflags us genv loc mod warns
  = (zipWith setTyVarUnique tyvar_tmpls (uniqsFromSupply us), warns)
\end{code}

We can also reach out and either set/grab location information from
the @SrcLoc@ being carried around.
\begin{code}
uniqSMtoDsM :: UniqSM a -> DsM a

uniqSMtoDsM u_action dflags us genv loc mod warns
  = (initUs_ us u_action, warns)

getSrcLocDs :: DsM SrcLoc
getSrcLocDs dflags us genv loc mod warns
  = (loc, warns)

putSrcLocDs :: SrcLoc -> DsM a -> DsM a
putSrcLocDs new_loc expr dflags us genv old_loc mod warns
  = expr dflags us genv new_loc mod warns

dsWarn :: WarnMsg -> DsM ()
dsWarn warn dflags us genv loc mod warns = ((), warns `snocBag` warn)

\end{code}

\begin{code}
getModuleDs :: DsM Module
getModuleDs dflags us genv loc mod warns = (mod, warns)
\end{code}

\begin{code}
dsLookupGlobalValue :: Name -> DsM Id
dsLookupGlobalValue name dflags us genv loc mod warns
  = (genv name, warns)
\end{code}


%************************************************************************
%*									*
\subsection{Type synonym @EquationInfo@ and access functions for its pieces}
%*									*
%************************************************************************

\begin{code}
data DsMatchContext
  = DsMatchContext TypecheckedMatchContext [TypecheckedPat] SrcLoc
  | NoMatchContext
  deriving ()
\end{code}
