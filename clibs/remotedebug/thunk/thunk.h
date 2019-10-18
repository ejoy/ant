#pragma once

#include <stdint.h>
#include <stddef.h>

struct thunk;
thunk* thunk_create_hook(intptr_t dbg, intptr_t hook);
thunk* thunk_create_panic(intptr_t dbg, intptr_t panic);

#if defined(_WIN32) || defined(__linux__) || defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
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
struct lua_State;
intptr_t thunk_get(lua_State* L, void* key);
void     thunk_set(lua_State* L, void* key, intptr_t v);
#define RDEBUG_DISABLE_THUNK 1
#endif
