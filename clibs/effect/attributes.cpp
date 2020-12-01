#include "pch.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "particle.h"
#include "random.h"

LUA2STRUCT(struct render_data, viewid, progid, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(struct particles::spawndata, count, rate);
LUA2STRUCT(struct particles::uv_motion_data, u_speed, v_speed, scale);

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

static component_id error_reader(lua_State *, int){
    assert(false && "should not call here");
    return ID_count;
}

extern std::function<component_id (lua_State *, int)> find_attrib_reader(const std::string &name){
    auto it = g_attrib_map.find(name);
    if (it == g_attrib_map.end()){
        return error_reader;
    }

    return it->second;
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

    template <int NUM> 
    void unpack(lua_State* L, int idx, glm::vec<NUM, float, glm::defaultp>& v, void*) { 
        luaL_checktype(L, idx, LUA_TTABLE);
        const int len = (int)luaL_len(L, idx);
        if (len != NUM){
            luaL_error(L, "invalid vec3: %d", len);
        }
        for (int ii=0; ii<len; ++ii){
            lua_geti(L, idx, ii+1);
            v[ii] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    }
    template <int NUM> 
    void pack(lua_State* L, glm::vec<NUM, float, glm::defaultp> const& v, void*) { 
        lua_newtable(L); 
        for (int ii=0; ii<NUM; ++ii){
            lua_pushnumber(L, v[ii]);
            lua_seti(L, -2, ii+1);
        }
    }
}
