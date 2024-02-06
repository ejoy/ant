#include "imgui_lua_util.h"
#include "backend/imgui_impl_bgfx.h"
#include <bee/nonstd/unreachable.h>
#include <stdint.h>

namespace imgui_lua::wrap_ImGuiInputTextCallbackData {
    void pointer(lua_State* L, ImGuiInputTextCallbackData& v);
}

namespace imgui_lua::util {

static lua_CFunction str_format = NULL;

lua_Integer field_tointeger(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checkinteger(L, -1);
    lua_pop(L, 1);
    return v;
}

lua_Number field_tonumber(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

bool field_toboolean(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    bool v = !!lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

ImTextureID get_texture_id(lua_State* L, int idx) {
    int lua_handle = (int)luaL_checkinteger(L, idx);
    if (auto id = ImGui_ImplBgfx_GetTextureID(lua_handle)) {
        return *id;
    }
    luaL_error(L, "Invalid handle type TEXTURE");
    std::unreachable();
}

const char* format(lua_State* L, int idx) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, idx);
    lua_call(L, lua_gettop(L) - idx, 1);
    return lua_tostring(L, -1);
}

static void* editbuf_realloc(lua_State *L, void *ptr, size_t osize, size_t nsize) {
    void *ud;
    lua_Alloc allocator = lua_getallocf(L, &ud);
    return allocator(ud, ptr, osize, nsize);
}

static int editbuf_tostring(lua_State* L) {
    auto ebuf = (ImEditBuf*)lua_touserdata(L, 1);
    lua_pushstring(L, ebuf->buf);
    return 1;
}

static int editbuf_release(lua_State* L) {
    auto ebuf = (ImEditBuf*)lua_touserdata(L, 1);
    editbuf_realloc(L, ebuf->buf, ebuf->size, 0);
    ebuf->buf = NULL;
    ebuf->size = 0;
    return 0;
}

int editbuf_callback(ImGuiInputTextCallbackData* data) {
    auto ebuf = (ImEditBuf*)data->UserData;
    lua_State* L = ebuf->L;
    lua_pushvalue(L, ebuf->callback);
    wrap_ImGuiInputTextCallbackData::pointer(L, *data);
    if (lua_pcall(ebuf->L, 1, 1, 0) != LUA_OK) {
        return 1;
    }
    lua_Integer retval = lua_tointeger(L, -1);
    lua_pop(L, 1);
    return (int)retval;
}

ImEditBuf* editbuf_create(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    int t = lua_geti(L, idx, 1);
    if (t == LUA_TSTRING || t == LUA_TNIL) {
        size_t sz;
        const char* text = lua_tolstring(L, -1, &sz);
        if (text == NULL) {
            sz = 64;    // default buf size 64
        } else {
            ++sz;
        }
        auto ebuf = (ImEditBuf*)lua_newuserdatauv(L, sizeof(ImEditBuf), 0);
        ebuf->buf = (char *)editbuf_realloc(L, NULL, 0, sz);
        if (ebuf->buf == NULL)
            luaL_error(L, "Edit buffer oom %u", (unsigned)sz);
        ebuf->size = sz;
        if (text) {
            memcpy(ebuf->buf, text, sz);
        } else {
            ebuf->buf[0] = 0;
        }
        if (luaL_newmetatable(L, "IMGUI_EDITBUF")) {
            lua_pushcfunction(L, editbuf_tostring);
            lua_setfield(L, -2, "__tostring");
            lua_pushcfunction(L, editbuf_release);
            lua_setfield(L, -2, "__gc");
        }
        lua_setmetatable(L, -2);
        lua_replace(L, -2);
        lua_pushvalue(L, -1);
        lua_seti(L, idx, 1);
    }
    auto ebuf = (ImEditBuf*)luaL_checkudata(L, -1, "IMGUI_EDITBUF");
    lua_pop(L, 1);
    ebuf->L = L;
    return ebuf;
}

void create_table(lua_State* L, std::span<TableInteger> l) {
    lua_createtable(L, 0, (int)l.size());
    for (auto const& e : l) {
        lua_pushinteger(L, e.value);
        lua_setfield(L, -2, e.name);
    }
}

void set_table(lua_State* L, std::span<TableAny> l) {
    for (auto const& e : l) {
        e.value(L);
        lua_setfield(L, -2, e.name);
    }
}

static void set_table(lua_State* L, std::span<luaL_Reg> l, int nup) {
    luaL_checkstack(L, nup, "too many upvalues");
    for (auto const& e : l) {
        for (int i = 0; i < nup; i++) {
            lua_pushvalue(L, -nup);
        }
        lua_pushcclosure(L, e.func, nup);
        lua_setfield(L, -(nup + 2), e.name);
    }
    lua_pop(L, nup);
}

static int make_flags(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    int i, t;
    lua_Integer r = 0;
    for (i = 1; (t = lua_geti(L, 1, i)) != LUA_TNIL; i++) {
        if (t != LUA_TSTRING)
            luaL_error(L, "Flag name should be string, it's %s", lua_typename(L, t));
        if (lua_gettable(L, lua_upvalueindex(1)) != LUA_TNUMBER) {
            lua_geti(L, 1, i);
            luaL_error(L, "Invalid flag %s.%s", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, -1));
        }
        lua_Integer v = lua_tointeger(L, -1);
        lua_pop(L, 1);
        r |= v;
    }
    lua_pushinteger(L, r);
    return 1;
}

void struct_gen(lua_State* L, const char* name, std::span<luaL_Reg> funcs, std::span<luaL_Reg> setters, std::span<luaL_Reg> getters) {
    lua_newuserdatauv(L, sizeof(uintptr_t), 0);
    int ud = lua_gettop(L);
    lua_newtable(L);
    if (!setters.empty()) {
        static lua_CFunction setter_func = +[](lua_State* L) {
            lua_pushvalue(L, 2);
            if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {
                return luaL_error(L, "%s.%s is invalid.", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, 2));
            }
            lua_pushvalue(L, 3);
            lua_call(L, 1, 0);
            return 0;
        };
        lua_createtable(L, 0, (int)setters.size());
        lua_pushvalue(L, ud);
        set_table(L, setters, 1);
        lua_pushstring(L, name);
        lua_pushcclosure(L, setter_func, 2);
        lua_setfield(L, -2, "__newindex");
    }
    if (!funcs.empty()) {
        lua_createtable(L, 0, (int)funcs.size());
        lua_pushvalue(L, ud);
        set_table(L, funcs, 1);
        lua_newtable(L);
    }
    static lua_CFunction getter_func = +[](lua_State* L) {
        lua_pushvalue(L, 2);
        if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {
            return luaL_error(L, "%s.%s is invalid.", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, 2));
        }
        lua_call(L, 0, 1);
        return 1;
    };
    lua_createtable(L, 0, (int)getters.size());
    lua_pushvalue(L, ud);
    set_table(L, getters, 1);
    lua_pushstring(L, name);
    lua_pushcclosure(L, getter_func, 2);
    lua_setfield(L, -2, "__index");
    if (!funcs.empty()) {
        lua_setmetatable(L, -2);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
}

void flags_gen(lua_State* L, const char* name) {
    lua_pushstring(L, name);
    lua_pushcclosure(L, make_flags, 2);
}

void init(lua_State* L) {
    luaopen_string(L);
    lua_getfield(L, -1, "format");
    str_format = lua_tocfunction(L, -1);
    lua_pop(L, 2);
}

}
