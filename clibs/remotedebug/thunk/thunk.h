#pragma once

#include <stdint.h>
#include <stddef.h>

struct thunk;
thunk* thunk_create_hook(intptr_t dbg, intptr_t hook);
thunk* thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic);

#if defined(_WIN32) || defined(__linux__) || defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#	define thunk_bind(...)
struct thunk {
	void*  data = 0;
	size_t size = 0;
	bool create(size_t s);
	bool write(void* buf);
	~thunk();
};
#else
struct thunk {
	void*  data = 0;
	intptr_t dbg = 0;
	intptr_t func1 = 0;
	intptr_t func2 = 0;
};
void thunk_bind(intptr_t L, intptr_t dbg);
#endif
