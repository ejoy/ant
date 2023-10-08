#pragma once

struct lua_State;

namespace luadebug::table {
    unsigned int array_size(const void* t);
    unsigned int hash_size(const void* t);
    bool array_base_zero();
    bool get_hash_kv(lua_State* L, const void* tv, unsigned int i);
    bool get_hash_k(lua_State* L, const void* tv, unsigned int i);
    bool get_hash_v(lua_State* L, const void* tv, unsigned int i);
    bool set_hash_v(lua_State* L, const void* tv, unsigned int i);
    bool get_array(lua_State* L, const void* tv, unsigned int i);
    bool set_array(lua_State* L, const void* tv, unsigned int i);
}
