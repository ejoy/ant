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

LUA2STRUCT(struct render_data, viewid, progid, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

template<typename VALUETYPE>
bool get_value(lua_State *L, int index, const char* name, VALUETYPE&attrib){
    bool isvaild = false;
    if (LUA_TNIL == lua_getfield(L, index, name)){
        lua_struct::unpack(L, -1, attrib);
        isvaild = true;
    }
    lua_pop(L, 1);
    return isvaild;
}

namespace lua_struct {
    void to_const(float value, particles::lifedata &ld){
        ld.set(value);
    }

    void to_linear(float minv, float maxv, particles::lifedata &ld){
        randomobj ro;
        ld.set((maxv - minv) * ro());
    }

    void to_const(float value, particles::float_interp_value &iv){
        iv.scale = value;
        iv.type = 0;
    }

    void to_linear(float minv, float maxv, particles::float_interp_value & iv){
        iv.scale = (maxv - minv) / particles::lifedata::MAX_PROCESS;
        iv.type = 1;
    }

    template<typename VALUETYPE>
    struct interp_type_taitis{using type = void;};
    template<>
    struct interp_type_taitis<particles::lifedata>{using type = float;};
    template<>
    struct interp_type_taitis<particles::float_interp_value>{using type = float;};

    template<typename VALUETYPE>
    void unpack_interp_value(lua_State* L, int index, VALUETYPE &iv) {
        luaL_checktype(L, index, LUA_TTABLE);
        const char *t = nullptr;
        if (LUA_TSTRING == lua_getfield(L, index, "interp_type")){
            t = lua_tostring(L, -1);
        }
        lua_pop(L, 1);

        using T = typename interp_type_taitis<VALUETYPE>::type;
        if (strcmp(t, "const") == 0){
            T v;
            if (!get_value(L, index, "value", v)){
                luaL_error(L, "'interp_type' const need 'value' field");
            }
                
            to_const(v, iv);
        } else if (strcmp(t, "linear") == 0){
            T minv, maxv;
            if (!(get_value(L, index, "minv", minv) && get_value(L, index, "maxv", maxv))){
                luaL_error(L, "'interp_type' need 'minv' and 'maxv' fields");
            }
            to_linear(minv, maxv, iv);
        } else if (strcmp(t, "curve") == 0){
            luaL_error(L, "not support curve as 'interp_type'");
        } else {
            luaL_error(L, "invalid 'interp_type'");
        }
    }

    template<>
    void unpack(lua_State* L, int index, particles::lifedata &iv, void*) { 
        unpack_interp_value(L, index, iv);
    }

    template<>
    void unpack(lua_State* L, int index, particles::float_interp_value &iv, void*) { 
        unpack_interp_value(L, index, iv);
    }
}

std::unordered_map<std::string, std::function<component_id (lua_State *, int)>> g_attrib_map = {
    std::make_pair("emitter_lifttime", [](lua_State *L, int index){
        particles::lifedata ld;
        if (!get_value(L, index, "emitter_lifttime", ld)){
            luaL_error(L, "spawn attribute must be define as emitter");
        }

        return particle_mgr::get().component(particles::life{ld});
    }),
    std::make_pair("init_lifttime", [](lua_State *L, int index){
        particles::float_interp_value iv;
        if (get_value(L, index, "init_lifttime", iv)){
            return particle_mgr::get().component(particles::init_life_interpolator{iv});
        }
        return ID_count;
    }),
    std::make_pair("spawn", [](lua_State *L, int index){
        particles::spawndata sd;
        if (!get_value(L, index, "spawn", sd)){
            luaL_error(L, "spawn attribute must be define as emitter");
        }

        //TODO: particle lifetime interp value should fetch here and save in 'particles::spawndata'
        return particle_mgr::get().component(particles::spawn{sd});
    }),
};

static int
leffect_create_emitter(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_struct::unpack(L, 1, particle_mgr::get().get_rd());

    if (LUA_TTABLE == lua_getfield(L, 1, "emitter")){
        comp_ids ids;
        ids.push_back(ID_TAG_emitter);

        for(lua_pushnil(L); lua_next(L, -2); lua_pop(L, 1)){
           if (LUA_TSTRING == lua_type(L, -2)){
               const std::string key = lua_tostring(L, -2);
               auto itattrib = g_attrib_map.find(key);
               if (itattrib != g_attrib_map.end()){
                   ids.push_back(itattrib->second(L, -2));
               }
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