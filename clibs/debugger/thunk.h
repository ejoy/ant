#pragma once

#include <stdint.h>

struct thunk;
thunk* thunk_create_hook(intptr_t dbg, intptr_t hook);
thunk* thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic);

#if defined(_WIN32) || defined(__linux__)
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
};
void thunk_bind(intptr_t L, intptr_t dbg);
#endif
