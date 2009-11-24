{-# LANGUAGE ForeignFunctionInterface #-}
--------------------------------------------------------------------------------
-- |
-- Module    : Foreign.CUDA.Driver.Context
-- Copyright : (c) 2009 Trevor L. McDonell
-- License   : BSD
--
-- Context management for low-level driver interface
--
--------------------------------------------------------------------------------

module Foreign.CUDA.Driver.Context
  (
    Context, ContextFlags(..),
    create, attach, detach, destroy, current, pop, push, sync
  )
  where

#include <cuda.h>
{# context lib="cuda" #}

-- Friends
import Foreign.CUDA.Driver.Device
import Foreign.CUDA.Driver.Error
import Foreign.CUDA.Internal.C2HS

-- System
import Foreign
import Foreign.C
import Foreign.ForeignPtr
import Control.Monad                    (liftM)


--------------------------------------------------------------------------------
-- Data Types
--------------------------------------------------------------------------------

{# pointer *CUcontext as Context foreign newtype #}
withContext :: Context -> (Ptr Context -> IO a) -> IO a

newContext :: IO Context
newContext = Context `fmap` mallocForeignPtrBytes (sizeOf (undefined :: Ptr ()))


-- |
-- Context creation flags
--
{# enum CUctx_flags as ContextFlags
    { underscoreToCase }
    with prefix="CU_CTX" deriving (Eq, Show) #}


--------------------------------------------------------------------------------
-- Context management
--------------------------------------------------------------------------------

-- |
-- Create a new CUDA context and associate it with the calling thread
--
create :: Device -> [ContextFlags] -> IO (Either String Context)
create dev flags =
  newContext              >>= \ctx -> withContext ctx $ \p ->
  cuCtxCreate p flags dev >>= \rv  ->
    return $ case nothingIfOk rv of
      Nothing -> Right ctx
      Just e  -> Left  e

{# fun unsafe cuCtxCreate
  { id              `Ptr Context'
  , combineBitMasks `[ContextFlags]'
  , useDevice       `Device'         } -> `Status' cToEnum #}


-- |
-- Increments the usage count of the context
--
attach :: Context -> IO (Maybe String)
attach ctx = withContext ctx $ \p -> (nothingIfOk `fmap` cuCtxAttach p 0)

{# fun unsafe cuCtxAttach
  { id     `Ptr Context'
  ,        `Int'         } -> `Status' cToEnum #}


-- |
-- Detach the context, and destroy if no longer used
--
detach :: Context -> IO (Maybe String)
detach ctx = withContext ctx $ \p -> (nothingIfOk `fmap` cuCtxDetach p)

{# fun unsafe cuCtxDetach
  { castPtr `Ptr Context' } -> `Status' cToEnum #}


-- |
-- Destroy the specified context. This fails if the context is more than a
-- single attachment (including that from initial creation).
--
destroy :: Context -> IO (Maybe String)
destroy ctx = withContext ctx $ \p -> (nothingIfOk `fmap` cuCtxDestroy p)

{# fun unsafe cuCtxDestroy
  { castPtr `Ptr Context' } -> `Status' cToEnum #}


-- |
-- Return the device of the currently active context
--
current :: IO (Either String Device)
current = resultIfOk `fmap` cuCtxGetDevice

{# fun unsafe cuCtxGetDevice
  { alloca- `Device' dev* } -> `Status' cToEnum #}
  where dev = liftM Device . peekIntConv


-- |
-- Pop the current CUDA context from the CPU thread. The context must have a
-- single usage count (matching calls to attach/detach). If successful, the new
-- context is returned, and the old may be attached to a different CPU.
--
pop :: IO (Either String Context)
pop =
  newContext        >>= \ctx -> withContext ctx $ \p ->
  cuCtxPopCurrent p >>= \rv  ->
    return $ case nothingIfOk rv of
      Nothing -> Right ctx
      Just e  -> Left  e

{# fun unsafe cuCtxPopCurrent
  { id `Ptr Context' } -> `Status' cToEnum #}


-- |
-- Push the given context onto the CPU's thread stack of current contexts. The
-- context must be floating (via `pop'), i.e. not attached to any thread.
--
push :: Context -> IO (Maybe String)
push ctx = withContext ctx $ \p -> (nothingIfOk `fmap` cuCtxPushCurrent p)

{# fun unsafe cuCtxPushCurrent
  { castPtr `Ptr Context' } -> `Status' cToEnum #}


-- |
-- Block until the device has completed all preceding requests
--
sync :: IO (Maybe String)
sync = nothingIfOk `fmap` cuCtxSynchronize

{# fun unsafe cuCtxSynchronize
  { } -> `Status' cToEnum #}
