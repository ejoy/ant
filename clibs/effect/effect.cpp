#include "pch.h"
#define LUA_LIB
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
    particle_mgr::create();
    return 0;
}

static int
leffect_shutdown(lua_State *L){
    return 0;
}

struct spawn_attrib {
    uint32_t    count;
    float       lifetime[2];
};
LUA2STRUCT(struct spawn_attrib, count, lifetime);

LUA2STRUCT(struct render_data, viewid, progid, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(glm::vec3, x, y, z);

struct velocity_attrib{
    float range[2][3];
};

LUA2STRUCT(struct velocity_attrib, range);

struct scale_attrib {
    float range[2][3];
};
LUA2STRUCT(struct scale_attrib, range);

struct translation_attrib {
    float range[2][3];
};
LUA2STRUCT(struct translation_attrib, range);

struct color_attrib {
    float range[2][4];
};
LUA2STRUCT(struct color_attrib, range);

struct uv_attrib {
    glm::vec2 quad_uv[4];
};

namespace lua_struct {
template <>
void unpack<uv_attrib>(lua_State* L, int idx, uv_attrib& v, void*) {
    luaL_checktype(L, idx, LUA_TTABLE);
    const int len = (int)luaL_len(L, 1);
    if (len != 4){
        luaL_error(L, "invalid uv_attrib data length, must be 4, %d privoided", len);
    }

    for (int ii=0; ii<4; ++ii){
        lua_geti(L, idx, ii+1);{
            
        }
        lua_pop(L, 1);
    }
}
template <>
void pack<uv_attrib>(lua_State* L, uv_attrib const& v, void*) {
    lua_newtable(L);
}
}

static int
leffect_create_emitter(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_struct::unpack(L, 1, particle_mgr::get().get_rd());

    if (LUA_TTABLE == lua_getfield(L, 1, "emitter")){

        spawn_attrib si;
        if (LUA_TTABLE == lua_getfield(L, -1, "spawn")){
            lua_struct::unpack(L, -1, si);
        } 
        lua_pop(L, 1);
        randomobj lifetime_ro(si.lifetime[0], si.lifetime[1]);

        auto get_attrib = [L](int index, const char* name, auto &attrib){
            bool isvaild = false;
            if (LUA_TTABLE == lua_getfield(L, index, name)){
                lua_struct::unpack(L, -1, attrib);
                isvaild = true;
            }
            lua_pop(L, 1);
            return isvaild;
        };

        velocity_attrib va;
        const bool has_velocity = get_attrib(-1, "velocity", va);
        randomobj_v3 v_ro(va.range[0], va.range[1]);

        scale_attrib sa;
        const bool has_scale = get_attrib(-1, "scale", sa);
        randomobj_v3 s_ro(sa.range[0], sa.range[1]);

        translation_attrib ta;
        const bool has_translation = get_attrib(-1, "translation", ta);
        randomobj_v3 t_ro(ta.range[0], ta.range[1]);

        color_attrib ca;
        const bool has_color = get_attrib(-1, "color", ca);
        randomobj_v4 c_ro(ca.range[0], ca.range[1]);

        const uint32_t quadidx = quad_cache::get().alloc(si.count);
        quad_cache::get().reset_quad(quadidx, si.count);
        for (uint32_t ii=0; ii<si.count; ++ii){
            auto comp_ids = std::move(particle_mgr::get().start());
            particle_mgr::get().addlifetime(comp_ids, particles::lifetype(lifetime_ro()));

            if (has_velocity){
                particle_mgr::get().addvelocity(comp_ids, v_ro());
            }

            if (has_scale){
                particle_mgr::get().addscale(comp_ids, s_ro());
            }

            if (has_translation){
                particle_mgr::get().addtranslation(comp_ids, t_ro());
            }

            if (has_color){
                auto c = c_ro();
                particle_mgr::get().addcolor(comp_ids, {c, c, c, c});
            }

            particle_mgr::get().addrenderquad(comp_ids, quadidx+ii);

            particle_mgr::get().end(std::move(comp_ids));
        }
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