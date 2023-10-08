#include "thunk.h"

#if defined(THUNK_JIT)
#    include "thunk_jit.inl"
#else
#    include "thunk_nojit.inl"
#endif
