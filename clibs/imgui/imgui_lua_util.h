#pragma once

#include <lua.hpp>

namespace imgui_lua::util {

lua_Integer field_tointeger(lua_State* L, int idx, lua_Integer i);
lua_Number  field_tonumber(lua_State* L, int idx, lua_Integer i);
bool        field_toboolean(lua_State* L, int idx, lua_Integer i);
const char* format(lua_State* L, int idx);

void init(lua_State* L);

}
