#ifndef HSVERSIONS_H
#define HSVERSIONS_H

#if 0

IMPORTANT!  If you put extra tabs/spaces in these macro definitions,
you will screw up the layout where they are used in case expressions!

(This is cpp-dependent, of course)

#endif

#ifdef __GLASGOW_HASKELL__
#define GLOBAL_VAR(name,value,ty)  \
name = Util.global (value) :: IORef (ty); \
{-# NOINLINE name #-}
#endif

#define COMMA ,

#ifdef DEBUG
#define ASSERT(e) if (not (e)) then (assertPanic __FILE__ __LINE__) else
#define ASSERT2(e,msg) if (not (e)) then (assertPprPanic __FILE__ __LINE__ (msg)) else
#define WARN( e, msg ) (warnPprTrace (e) __FILE__ __LINE__ (msg))
#else
#define ASSERT(e)
#define ASSERT2(e,msg)
#define WARN(e,msg)
#endif

-- temporary usage assertion control KSW 2000-10
#ifdef DO_USAGES
#define UASSERT(e) ASSERT(e)
#define UASSERT2(e,msg) ASSERT2(e,msg)
#else
#define UASSERT(e)
#define UASSERT2(e,msg)
#endif

#if __GLASGOW_HASKELL__ >= 23

-- This #ifndef lets us switch off the "import FastString"
-- when compiling FastString itself
#ifndef COMPILING_FAST_STRING
-- 
import qualified FastString 
#endif

# define USE_FAST_STRINGS 1
# define FAST_STRING	FastString.FastString
# define SLIT(x)	(FastString.mkFastCharString# (x#))
# define FSLIT(x)	(FastString.mkFastString# (x#))
# define _NULL_		FastString.nullFastString
# define _NIL_		(FastString.mkFastString "")
# define _CONS_		FastString.consFS
# define _HEAD_		FastString.headFS
# define _HEAD_INT_	FastString.headIntFS
# define _TAIL_		FastString.tailFS
# define _LENGTH_	FastString.lengthFS
# define _PK_		FastString.mkFastString
# define _UNPK_		FastString.unpackFS
# define _UNPK_INT_	FastString.unpackIntFS
# define _APPEND_	`FastString.appendFS`
#else
# error I think that FastString is now always used. If not, fix this.
# define FAST_STRING String
# define SLIT(x)      (x)
# define _CMP_STRING_ cmpString
# define _NULL_	      null
# define _NIL_	      ""
# define _CONS_	      (:)
# define _HEAD_	      head
# define _TAIL_	      tail
# define _LENGTH_     length
# define _PK_	      (\x->x)
# define _UNPK_	      (\x->x)
# define _SUBSTR_     substr{-from Utils-}
# define _APPEND_     ++
#endif

#endif
