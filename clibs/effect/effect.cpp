#include "pch.h"

#include "particle.h"
#include "transforms.h"
#include "random.h"

#include "quadcache.h"
#include "lua2struct.h"

#include "lua.hpp"

#define EXPORT_BGFX_INTERFACE
#include "bgfx/bgfx_interface.h"

static int
leffect_init(lua_State *L){
    return 1;
}

static int
leffect_shutdown(lua_State *L){
    return 1;
}

struct spawninfo {
    uint32_t    count;
    glm::vec2   lifetime_range;
    uint8_t     type;
};
LUA2STRUCT(struct spawninfo, count, lifetime_range, type);
LUA2STRUCT(glm::vec2, x, y);

LUA2STRUCT(struct render_data, viewid, progid, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(glm::vec3, x, y, z);

struct velocity_attrib{
    glm::vec3 range[2];
};

LUA2STRUCT(struct velocity_attrib, range);

struct scale_attrib {
    glm::vec3 range[2];
};
LUA2STRUCT(struct scale_attrib, range);

static int
leffect_create_particles(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_struct::unpack(L, 1, particle_mgr::get().get_rd());

    if (LUA_TTABLE == lua_getfield(L, 1, "emitter")){

        spawninfo si;
        if (LUA_TTABLE == lua_getfield(L, -1, "spawn")){
            lua_struct::unpack(L, -1, si);
        } 
        lua_pop(L, 1);
        auto lifetime_ro = randomobj::create(si.lifetime_range);

        velocity_attrib va;
        bool has_velocity = false;
        if (LUA_TTABLE == lua_getfield(L, -1, "velocity")){
            lua_struct::unpack(L, -1, va);
            has_velocity = true;
        }
        randomobj_vec3 v_ro(va.range[0], va.range[1]);
        lua_pop(L, 1);

        scale_attrib sa;
        bool has_scale = false;
        if (LUA_TTABLE == lua_getfield(L, -1, "scale")){
            lua_struct::unpack(L, -1, sa);
            has_scale = true;
        }
        randomobj_vec3 s_ro(sa.range[0], sa.range[1]);
        lua_pop(L, 1);

        for (uint32_t ii=0; ii<si.count; ++ii){
            auto comp_ids = particle_mgr::get().start();
            particle_mgr::get().addlifetime(comp_ids, particles::lifetype(lifetime_ro()));

            if (has_velocity){
                particle_mgr::get().addvelocity(comp_ids, v_ro());
            }

            if (has_scale){
                particle_mgr::get().addscale(comp_ids, s_ro());
            }

            particle_mgr::get().end(std::move(comp_ids));
        }
    } else {
        luaL_error(L, "invalid 'emitter'");
    }

    return 1;
}

extern "C" int
luaopen_effect(lua_State *L){
    init_interface(L);

    luaL_Reg l[] = {
        { "init",               leffect_init },
        { "shutdown",           leffect_shutdown },
        { "create_particles",   leffect_create_particles},
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}

