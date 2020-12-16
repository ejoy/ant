#include "pch.h"
#define LUA_LIB
#include "random.h"

#include "attributes.h"
#include "emitter.h"
#include "particle_mgr.h"

#include "quadcache.h"
#include "lua2struct.h"

#include "lua.hpp"

#define EXPORT_BGFX_INTERFACE
#include "bgfx/bgfx_interface.h"

static int
leffect_init(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
    particle_mgr::create();
    lua_struct::unpack(L, 1, particle_mgr::get().get_rd());
    return 0;
}

static int
leffect_shutdown(lua_State *L){
    particle_mgr::destroy();
    return 0;
}

static inline particle_emitter*
get_emitter(lua_State *L, int index){
    return (particle_emitter*)luaL_checkudata(L, index, "PARTICLE_EMITTER");
}

static int
lemitter_spawn(lua_State *L){
    auto e = get_emitter(L, 1);
    const glm::mat4 &m = *(glm::mat4*)lua_touserdata(L, 2);
    lua_pushinteger(L, e->spawn(m));
    return 1;

}

static int
lemitter_del(lua_State *L){
    auto e = get_emitter(L, 1);
    e->~particle_emitter();
    return 0;
}

static int
lemitter_update(lua_State *L){
    auto e = get_emitter(L, 1);
    const float dt = (float)luaL_checknumber(L, 2);
    e->update(dt);
    return 0;
}

static int
leffect_create_emitter(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    auto e = (particle_emitter*)lua_newuserdatauv(L, sizeof(particle_emitter), 0);
    new (e) particle_emitter();
    if (luaL_newmetatable(L, "PARTICLE_EMITTER")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");

        luaL_Reg l[] = {
            {"update", lemitter_update},
            {"spawn", lemitter_spawn},
            {"__gc", lemitter_del},
            {nullptr, nullptr,},
        };

        luaL_setfuncs(L, l, 0);
    }

    lua_setmetatable(L, -2);

    if (LUA_TTABLE == lua_getfield(L, 1, "lifetime")){
        interpolation::init_valueT<float> iv;
        lua_struct::unpack(L, -1, iv);
        e->mlife.set(iv.get(randomobj()()));
    } else {
        luaL_error(L, "invalid 'lifetime' data");
    }
    lua_pop(L, 1);

    if (LUA_TTABLE == lua_getfield(L, 1, "subuv_setting")){
        lua_struct::unpack(L, -1, e->msubuv_setting.subuv_dim);
    }
    lua_pop(L, 1);

    if (LUA_TTABLE == lua_getfield(L, 1, "spawn")){
        lua_struct::unpack(L, -1, e->mspawn);

        comp_ids ids;
        for(lua_pushnil(L); lua_next(L, -2); lua_pop(L, 1)){
            if (LUA_TSTRING == lua_type(L, -2)){
                const std::string key = lua_tostring(L, -2);
                auto reader = find_attrib_reader(key);
                reader(L, -1, e, ids);
            }
        }
    } else {
        luaL_error(L, "invalid 'spawn' data");
    }
    lua_pop(L, 1);
    return 1;
}

static int
leffect_update_particles(lua_State *L){
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
            { "update_particles",   leffect_update_particles},
            { nullptr, nullptr },
        };
        luaL_newlib(L, l);
        return 1;
    }
}