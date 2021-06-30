#ifndef LUA_SERI_H
#define LUA_SERI_H

#include <lua.h>

int threadseri_unpackptr(lua_State *L, void * buffer);
int threadseri_unpack(lua_State *L);
void * threadseri_pack(lua_State *L, int from, int *sz);
void * threadseri_packstring(const char * str, int sz);

#endif
