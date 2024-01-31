#pragma once

#include <imgui.h>
#include <lua.hpp>
#include <span>

namespace imgui_lua::util {

struct TableInteger {
    const char* name;
    lua_Integer value;
};

using GenerateAny = void (*) (lua_State* L);
struct TableAny {
    const char* name;
    GenerateAny value;
};

lua_Integer field_tointeger(lua_State* L, int idx, lua_Integer i);
lua_Number  field_tonumber(lua_State* L, int idx, lua_Integer i);
bool        field_toboolean(lua_State* L, int idx, lua_Integer i);
ImTextureID get_texture_id(lua_State* L, int idx);
const char* format(lua_State* L, int idx);

void        create_table(lua_State* L, std::span<TableInteger> l);
void        set_table(lua_State* L, std::span<TableAny> l);
void        init(lua_State* L);

}
