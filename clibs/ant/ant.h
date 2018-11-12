#pragma once

#if defined(__cplusplus)
extern "C" {
#endif

struct lua_State;

int ant_searcher_c(lua_State *L);
int ant_searcher_init(lua_State *L);

#if defined(__cplusplus)
}
#endif
