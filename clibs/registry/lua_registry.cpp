#include <bee/lua/binding.h>
#include <bee/registry.h>
#include <lua.hpp>

namespace bee::lua_registry {
    using namespace bee::registry;

    namespace rkey {
        key_w* newuserdata(lua_State* L);

        key_w& get(lua_State* L, int idx) {
            return *static_cast<key_w*>(getObject(L, idx, "registry::key"));
        }

        key_w& create(lua_State* L, const key_w& key) {
            key_w* self = newuserdata(L);
            new (self) key_w(key);
            return *self;
        }

        key_w& create(lua_State* L, const std::wstring& key) {
            key_w* self = newuserdata(L);
            new (self) key_w(key);
            return *self;
        }

        key_w& getEx(lua_State* L, int idx) {
            if (lua_type(L, 1) == LUA_TSTRING) {
                key_w& res = create(L, lua::to_string(L, idx));
                lua_replace(L, idx);
                return res;
            }
            return get(L, idx);
        }

        int push_value(lua_State* L, key_w::value_type& value) {
            switch (value.type()) {
            case REG_DWORD:
                lua_pushinteger(L, value.get_uint32_t());
                return 1;
            case REG_QWORD:
                lua_pushinteger(L, value.get_uint64_t());
                return 1;
            case REG_SZ:
            case REG_MULTI_SZ:
            case REG_EXPAND_SZ:
                lua::push_string(L, value.get_string());
                return 1;
            case REG_BINARY: {
                std::dynarray<uint8_t> blob = value.get_binary();
                lua_pushlstring(L, (const char*)blob.data(), blob.size());
                return 1;
            }
            default:
                return luaL_error(L, "Unknown REG type(%d).", value.type());
            }
        }

        int mt_index(lua_State* L) {
            try {
                key_w&             self = get(L, 1);
                std::wstring       key = lua::to_string(L, 2);
                key_w::value_type& value = self.value(key);
                push_value(L, value);
            }
            catch (const std::exception&) {
            }
            lua_pushnil(L);
            return 1;
        }

        int mt_newindex(lua_State* L) {
            LUA_TRY;
            key_w&             self = get(L, 1);
            std::wstring       key = lua::to_string(L, 2);
            key_w::value_type& value = self.value(key);
            switch (lua_type(L, 3)) {
            case LUA_TSTRING:
                value.set(lua::to_string(L, 3));
                return 0;
            case LUA_TNUMBER:
                value.set_uint32_t((uint32_t)luaL_checkinteger(L, 3));
                return 0;
            case LUA_TTABLE: {
                lua_geti(L, 3, 1);
                switch (luaL_checkinteger(L, -1)) {
                case REG_DWORD:
                    lua_geti(L, 3, 2);
                    value.set_uint32_t((uint32_t)luaL_checkinteger(L, -1));
                    break;
                case REG_QWORD:
                    lua_geti(L, 3, 2);
                    value.set_uint64_t(luaL_checkinteger(L, -1));
                    break;
                case REG_EXPAND_SZ:
                case REG_SZ:
                    lua_geti(L, 3, 2);
                    value.set(lua::to_string(L, -1));
                    break;
                case REG_MULTI_SZ: {
                    lua_Integer  len = luaL_len(L, 3);
                    std::wstring str = L"";
                    for (lua_Integer i = 2; i <= len; ++i) {
                        lua_geti(L, 3, i);
                        str += lua::to_string(L, -1);
                        str.push_back(L'\0');
                        lua_pop(L, 1);
                    }
                    str.push_back(L'\0');
                    value.set(REG_MULTI_SZ, str.c_str(), str.size() * sizeof(wchar_t));
                    break;
                }
                case REG_BINARY: {
                    lua_geti(L, 3, 2);
                    size_t      len = 0;
                    const char* buf = luaL_checklstring(L, -1, &len);
                    value.set((const void*)buf, len);
                    break;
                }
                default:
                    return luaL_error(L, "Unknown REG type(%d).", luaL_checkinteger(L, -1));
                }
                return 0;
            default:
                return luaL_error(L, "Set value's type must be integer, string or table.");
            }
            }
            LUA_TRY_END;
        }

        int mt_div(lua_State* L) {
            LUA_TRY;
            key_w&       self = get(L, 1);
            std::wstring rht = lua::to_string(L, 2);
            create(L, self / rht);
            return 1;
            LUA_TRY_END;
        }

        int mt_gc(lua_State* L) {
            key_w& self = get(L, 1);
            self.~key_w();
            return 0;
        }

        key_w* newuserdata(lua_State* L) {
            key_w* storage = (key_w*)lua_newuserdatauv(L, sizeof(key_w), 0);
            if (newObject(L, "registry::key")) {
                luaL_Reg mt[] = {
                    {"__index", rkey::mt_index},
                    {"__newindex", rkey::mt_newindex},
                    {"__div", rkey::mt_div},
                    {"__gc", rkey::mt_gc},
                    {NULL, NULL},
                };
                luaL_setfuncs(L, mt, 0);
                lua_pushvalue(L, -1);
                lua_setfield(L, -2, "__index");
            }
            lua_setmetatable(L, -2);
            return storage;
        }
    }

    static int open(lua_State* L) {
        LUA_TRY;
        rkey::create(L, lua::to_string(L, 1));
        return 1;
        LUA_TRY_END;
    }

    static int del(lua_State* L) {
        LUA_TRY;
        key_w& self = rkey::getEx(L, 1);
        lua_pushboolean(L, self.del() ? 1 : 0);
        return 1;
        LUA_TRY_END;
    }

    static int pairs_keys(lua_State* L) {
        LUA_TRY;
        key_w&      self = rkey::get(L, 1);
        lua_Integer n = lua_tointeger(L, lua_upvalueindex(1));
        lua_Integer i = lua_tointeger(L, lua_upvalueindex(2));
        if (i >= n) {
            return 0;
        }
        lua_pushinteger(L, i + 1);
        lua_replace(L, lua_upvalueindex(2));
        wchar_t* data = (wchar_t*)lua_touserdata(L, lua_upvalueindex(3));
        size_t   size = 1 + (size_t)lua_tointeger(L, lua_upvalueindex(4));
        key_w    key = self.key((uint32_t)i, data, &size);
        lua::push_string(L, lua::string_type(data, size));
        rkey::create(L, key);
        return 2;
        LUA_TRY_END;
    }

    static int keys(lua_State* L) {
        LUA_TRY;
        key_w&   self = rkey::getEx(L, 1);
        uint32_t nums = 0;
        size_t   maxname = 0;
        self.enum_keys(&nums, &maxname);
        lua_pushinteger(L, nums);
        lua_pushinteger(L, 0);
        lua_newuserdatauv(L, (maxname + 1) * sizeof(wchar_t), 0);
        lua_pushinteger(L, maxname);
        lua_pushcclosure(L, pairs_keys, 4);
        lua_pushvalue(L, 1);
        return 2;
        LUA_TRY_END;
    }

    static int pairs_values(lua_State* L) {
        LUA_TRY;
        key_w&      self = rkey::get(L, 1);
        lua_Integer n = lua_tointeger(L, lua_upvalueindex(1));
        lua_Integer i = lua_tointeger(L, lua_upvalueindex(2));
        if (i >= n) {
            return 0;
        }
        lua_pushinteger(L, i + 1);
        lua_replace(L, lua_upvalueindex(2));
        wchar_t*           data = (wchar_t*)lua_touserdata(L, lua_upvalueindex(3));
        size_t             size = 1 + (size_t)lua_tointeger(L, lua_upvalueindex(4));
        key_w::value_type& value = self.value((uint32_t)i, data, &size);
        lua::push_string(L, lua::string_type(data, size));
        rkey::push_value(L, value);
        return 2;
        LUA_TRY_END;
    }

    static int values(lua_State* L) {
        LUA_TRY;
        key_w&   self = rkey::getEx(L, 1);
        uint32_t nums = 0;
        size_t   maxname = 0;
        self.enum_values(&nums, &maxname);
        lua_pushinteger(L, nums);
        lua_pushinteger(L, 0);
        lua_newuserdatauv(L, (maxname + 1) * sizeof(wchar_t), 0);
        lua_pushinteger(L, maxname);
        lua_pushcclosure(L, pairs_values, 4);
        lua_pushvalue(L, 1);
        return 2;
        LUA_TRY_END;
    }

    int luaopen(lua_State* L) {
        static luaL_Reg func[] = {
            {"open", open},
            {"del", del},
            {"keys", keys},
            {"values", values},
            {NULL, NULL},
        };
        luaL_newlibtable(L, func);
        luaL_setfuncs(L, func, 0);

#define LUA_PUSH_CONST(L, val) \
    lua_pushinteger(L, (val)); \
    lua_setfield(L, -2, #val);

        LUA_PUSH_CONST(L, REG_DWORD);
        LUA_PUSH_CONST(L, REG_QWORD);
        LUA_PUSH_CONST(L, REG_SZ);
        LUA_PUSH_CONST(L, REG_EXPAND_SZ);
        LUA_PUSH_CONST(L, REG_MULTI_SZ);
        LUA_PUSH_CONST(L, REG_BINARY);
        LUA_PUSH_CONST(L, KEY_WOW64_32KEY);
        LUA_PUSH_CONST(L, KEY_WOW64_64KEY);

#undef LUA_PUSH_CONST
        return 1;
    }
}

DEFINE_LUAOPEN(registry)
