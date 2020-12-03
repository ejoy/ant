#include "pch.h"
#define LUA_LIB
#include "particle.h"
#include "transforms.h"
#include "random.h"

#include "attributes.h"

#include "quadcache.h"
#include "lua2struct.h"

#include "lua.hpp"

#define EXPORT_BGFX_INTERFACE
#include "bgfx/bgfx_interface.h"

static int
leffect_init(lua_State *L){
    particle_mgr::create();
    return 0;
}

static int
leffect_shutdown(lua_State *L){
    particle_mgr::destroy();
    return 0;
}

static int
leffect_create_emitter(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_struct::unpack(L, 1, particle_mgr::get().get_rd());

    if (LUA_TUSERDATA == lua_getfield(L, 1, "quadcache")){
        auto qc = (quad_cache*)luaL_checkudata(L, -1, "QUADCACHE_MT");
        particle_mgr::get().set_quadcache(qc);
    } else {
        luaL_error(L, "invalid quadinfo");
    }

    if (LUA_TTABLE == lua_getfield(L, 1, "emitter")){
        comp_ids ids;
        ids.push_back(ID_TAG_emitter);

        for(lua_pushnil(L); lua_next(L, -2); lua_pop(L, 1)){
           if (LUA_TSTRING == lua_type(L, -2)){
               const std::string key = lua_tostring(L, -2);
               auto reader = find_attrib_reader(key);
               reader(L, -1, ids);
           }
        }

        if (ids.end() == std::find(ids.begin(), ids.end(), ID_spawn)){
            particle_mgr::get().pop_back(ids);
            luaL_error(L, "invalid emitter without 'spawn' info");
        }
        particle_mgr::get().add(ids);
    } else {
        luaL_error(L, "invalid 'emitter'");
    }
    lua_pop(L, 1);

    return 1;
}

static int
leffect_update(lua_State *L){
    const float dt = (float)luaL_checknumber(L, 1);
    particle_mgr::get().update(dt);
    return 0;
}

extern "C" {
    LUAMOD_API int
    luaopen_effect(lua_State *L){
        init_interface(L);

        luaL_Reg l[] = {
            { "init",               leffect_init },
            { "shutdown",           leffect_shutdown },
            { "create_emitter",     leffect_create_emitter},
            { "update",             leffect_update},
            { nullptr, nullptr },
        };
        luaL_newlib(L, l);
        return 1;
    }
}