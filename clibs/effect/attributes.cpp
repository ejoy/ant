#include "pch.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "particle.h"
#include "random.h"

LUA2STRUCT(struct render_data, viewid, progid, layout, ibhandle, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(struct particles::spawndata, count, rate);
LUA2STRUCT(struct particles::uv_motion_data, u_speed, v_speed, scale);

namespace lua_struct {
    void to_const(float value, particles::lifedata &ld){
        ld.set(value);
    }

    void to_linear(float minv, float maxv, particles::lifedata &ld){
        randomobj ro;
        ld.set((maxv - minv) * ro());
    }

    template<typename VALUETYPE, typename INTPER_VALUETYPE>
    void to_const(VALUETYPE value, INTPER_VALUETYPE &iv){
        iv.scale = value;
        iv.type = 0;
    }

    template<typename VALUETYPE, typename INTPER_VALUETYPE>
    void to_linear(VALUETYPE minv, VALUETYPE maxv, INTPER_VALUETYPE & iv){
        const float inv_process = 1.f / particles::lifedata::MAX_PROCESS;
        iv.scale = (maxv - minv) * inv_process;
        iv.type = 1;
    }

    template<typename VALUETYPE>
    bool get_field(lua_State *L, int index, const char* name, VALUETYPE&attrib){
        bool isvaild = false;
        const int type = lua_getfield(L, index, name);
        if (LUA_TTABLE == type || LUA_TNUMBER == type){
            lua_struct::unpack(L, -1, attrib);
            isvaild = true;
        }
        lua_pop(L, 1);
        return isvaild;
    }

    template<typename VALUETYPE>
    void unpack_interp_value(lua_State* L, int index, VALUETYPE &iv) {
        luaL_checktype(L, index, LUA_TTABLE);
        const char *t = nullptr;
        if (LUA_TSTRING == lua_getfield(L, index, "interp_type")){
            t = lua_tostring(L, -1);
        }
        lua_pop(L, 1);

        using T = typename VALUETYPE::interp_type;
        if (strcmp(t, "const") == 0){
            T v;
            if (!get_field(L, index, "value", v)){
                luaL_error(L, "'interp_type' const need 'value' field");
            }
                
            to_const(v, iv);
        } else if (strcmp(t, "linear") == 0){
            T minv, maxv;
            if (!(get_field(L, index, "minv", minv) && get_field(L, index, "maxv", maxv))){
                luaL_error(L, "'interp_type' need 'minv' and 'maxv' fields");
            }
            to_linear(minv, maxv, iv);
        } else if (strcmp(t, "curve") == 0){
            luaL_error(L, "not support curve as 'interp_type'");
        } else {
            luaL_error(L, "invalid 'interp_type'");
        }
    }

#define DEF_INTERP_VALUE_UNPACK(_INTERPTYPE) \
    template<>\
    void unpack(lua_State* L, int index, _INTERPTYPE &iv, void*) {\
        unpack_interp_value(L, index, iv);\
    }

    DEF_INTERP_VALUE_UNPACK(particles::lifedata);
    DEF_INTERP_VALUE_UNPACK(particles::float_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f2_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f3_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f4_interp_value);

    template <int NUM>
    void unpack_vec(lua_State* L, int idx, glm::vec<NUM, float, glm::defaultp>& v) {
        luaL_checktype(L, idx, LUA_TTABLE);
        const int len = (int)luaL_len(L, idx);
        if (len != NUM) {
            luaL_error(L, "invalid vec3: %d", len);
        }
        for (int ii = 0; ii < len; ++ii) {
            lua_geti(L, idx, ii + 1);
            v[ii] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    }

#define DEF_VEC_UNPACK(_VECTYPE) template<>\
    void unpack(lua_State* L, int index, _VECTYPE &v, void*) {\
        unpack_vec(L, index, v);\
    }

    DEF_VEC_UNPACK(glm::vec2);
    DEF_VEC_UNPACK(glm::vec3);
    DEF_VEC_UNPACK(glm::vec4);
}


static inline bool check_add_id(component_id id, comp_ids &ids){
    if (ids.end() == std::find(ids.begin(), ids.end(), id)){
        ids.push_back(id);
        return true;
    }
    return false;
}

template<typename VALUETYPE>
static inline VALUETYPE& check_add_component(comp_ids &ids){
    if (check_add_id(VALUETYPE::ID(), ids)){
        VALUETYPE v;
        particle_mgr::get().add_component(v);
    }

    return particle_mgr::get().component_value<VALUETYPE>();
}

std::unordered_map<std::string, std::function<void (lua_State *, int, comp_ids&)>> g_attrib_map = {
    std::make_pair("emitter_lifetime", [](lua_State *L, int index, comp_ids& ids){
        particles::lifedata ld;
        lua_struct::unpack(L, index, ld);
        check_add_id(particle_mgr::get().add_component(particles::life{ld}), ids);
    }),
    std::make_pair("spawn", [](lua_State *L, int index, comp_ids& ids){
        particles::spawndata sd;
        lua_struct::unpack(L, index, sd);

        //TODO: particle lifetime interp value should fetch here and save in 'particles::spawndata'
        check_add_id(particle_mgr::get().add_component(particles::spawn{sd}), ids);
    }),
    std::make_pair("init_lifetime", [](lua_State *L, int index, comp_ids& ids){
        particles::float_interp_value iv;
        lua_struct::unpack(L, index, iv);
        check_add_id(particle_mgr::get().add_component(particles::init_life_interpolator{iv}), ids);
    }),
    std::make_pair("init_scale", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &ri = check_add_component<particles::init_rendertype_interpolator>(ids);
        ri.s = iv;
    }),
    std::make_pair("init_translation", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &ri = check_add_component<particles::init_rendertype_interpolator>(ids);
        ri.t = iv;
    }),
    std::make_pair("init_color", [](lua_State *L, int index, comp_ids& ids){
        particles::f4_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &q = check_add_component<particles::init_quad_interpolator>(ids);
        q.color = iv;
    }),
    std::make_pair("init_velocity", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        check_add_id(particle_mgr::get().add_component(particles::init_velocity_interpolator{iv}), ids);
    }),
    std::make_pair("init_acceleration", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        check_add_id(particle_mgr::get().add_component(particles::init_acceleration_interpolator{iv}), ids);
    }),
    std::make_pair("uv_motion", [](lua_State *L, int index, comp_ids& ids){
        particles::uv_motion_data md;
        lua_struct::unpack(L, index, md);
        check_add_id(particle_mgr::get().add_component(particles::uv_motion{md}), ids);
    }),
};

static void default_reader(lua_State *, int, comp_ids&){
    
}

std::function<void (lua_State *, int, comp_ids&)> find_attrib_reader(const std::string &name){
    auto it = g_attrib_map.find(name);
    if (it == g_attrib_map.end()){
        return default_reader;
    }

    return it->second;
}