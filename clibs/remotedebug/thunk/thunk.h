#pragma once

#include <stdint.h>
#include <stddef.h>

struct thunk;
thunk* thunk_create_hook(intptr_t dbg, intptr_t hook);
thunk* thunk_create_allocf(intptr_t dbg, intptr_t allocf);

#if defined(_WIN32)
#	define THUNK_JIT 1
#else
#	if defined(__ia64__)
#		define THUNK_JIT 1
#	endif
#endif

#if defined(THUNK_JIT)
#include "thunk_jit.h"
#else
#include "thunk_nojit.h"
#endif
