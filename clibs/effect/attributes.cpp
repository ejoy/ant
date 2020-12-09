#include "pch.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "particle.h"
#include "random.h"

LUA2STRUCT(struct render_data, viewid, progid, qb, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(struct particles::spawndata, count, rate);
LUA2STRUCT(struct particles::uv_motion_data, u_speed, v_speed, scale);

namespace lua_struct {
    template<>
    void unpack(lua_State* L, int index, quad_buffer& qb, void*) {
        if (LUA_TNUMBER == lua_getfield(L, index, "ib")){
            qb.ib.idx = (L, -1);
        } else {
            luaL_error(L, "invalid 'ib'");
        }
        lua_pop(L, 1);
        if (LUA_TUSERDATA == lua_getfield(L, index, "layout")){
            qb.layout = (bgfx_vertex_layout_t*)lua_touserdata(L, 2);
        } else {
            luaL_error(L, "invalid pointer");
        }
        lua_pop(L, 1);
    }
    template<>
    void pack(lua_State* L, const quad_buffer& qb, void*){

    }
    void to_const(float value, particles::life &ld){
        ld.set(value);
    }

    void to_linear(float minv, float maxv, particles::life &ld){
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

    template<>
    void unpack(lua_State* L, int index, particles::transform_interp &iv, void*) {
        unpack_interp_value(L, index, iv.s);
        unpack_interp_value(L, index, iv.r);
        unpack_interp_value(L, index, iv.t);
    }

    template<>
    void unpack(lua_State* L, int index, particles::color_interp_value &civ, void*) {
        auto check_rgba = [](lua_State* L, int index, particles::color_interp_value &civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGBA")){
                isvalid = true;
                particles::f4_interp_value f4v;
                unpack_interp_value(L, index, f4v);
                for (int ii=0; ii<4; ++ii){
                    civ.rgba[ii].scale = f4v.scale[ii];
                    civ.rgba[ii].type = f4v.type;
                }
            }
            lua_pop(L, 1);
            return isvalid;
        };

        auto check_rgb = [](lua_State* L, int index, particles::color_interp_value &civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGB")){
                isvalid = true;
                particles::f3_interp_value f3v;
                unpack_interp_value(L, -1, f3v);
                for (int ii=0; ii<3; ++ii){
                    civ.rgba[ii].scale = f3v.scale[ii];
                    civ.rgba[ii].type = f3v.type;
                }
            }
            lua_pop(L, 1);

            if (LUA_TTABLE == lua_getfield(L, index, "A")){
                unpack_interp_value(L, -1, civ.rgba[3]);
            } else {
                luaL_error(L, "need define 'A' for alpha interp");
            }
            lua_pop(L, 1);
            return isvalid;
        };

        if (check_rgba(L, index, civ))
            return;
        
        if (check_rgb(L, index, civ))
            return;

        const char* rgba_names[] = {"R", "G", "B", "A"};
        for (int ii=0; ii<4; ++ii){
            if (LUA_TTABLE == lua_getfield(L, index, rgba_names[ii])){
                unpack_interp_value(L, -1, civ.rgba[ii]);
            } else {
                luaL_error(L, "need define '%s'", rgba_names[ii]);
            }
            lua_pop(L, 1);
        }
    }

    template<>
    void unpack(lua_State* L, int index, particles::quad_interp &iv, void*) {
        unpack(L, index, iv.color);
    }

#define DEF_INTERP_VALUE_UNPACK(_INTERPTYPE) \
    template<>\
    void unpack(lua_State* L, int index, _INTERPTYPE &iv, void*) {\
        unpack_interp_value(L, index, iv);\
    }

    DEF_INTERP_VALUE_UNPACK(particles::life);
    DEF_INTERP_VALUE_UNPACK(particles::float_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f2_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f3_interp_value);
    DEF_INTERP_VALUE_UNPACK(particles::f4_interp_value);

    template <int NUM>
    void unpack_vec(lua_State* L, int idx, glm::vec<NUM, float, glm::defaultp>& v) {
        luaL_checktype(L, idx, LUA_TTABLE);
        const int len = (int)luaL_len(L, idx);
        if (len < NUM) {
            luaL_error(L, "invalid vec: %d", len);
        }
        for (int ii = 0; ii < NUM; ++ii) {
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
        particles::life ld;
        lua_struct::unpack(L, index, ld);
        check_add_id(particle_mgr::get().add_component(particles::life{ld}), ids);
    }),
    std::make_pair("spawn", [](lua_State *L, int index, comp_ids& ids){
        particles::spawndata sd;
        lua_struct::unpack(L, index, sd);

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
        auto &t = check_add_component<particles::init_transform_interpolator>(ids);
        t.s = iv;
    }),
    std::make_pair("scale_over_life", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &t = check_add_component<particles::lifetime_transform_interpolator>(ids);
        t.s = iv;
    }),
    std::make_pair("init_translation", [](lua_State *L, int index, comp_ids& ids){
        particles::f3_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &t = check_add_component<particles::init_transform_interpolator>(ids);
        t.t = iv;
    }),
    std::make_pair("init_color", [](lua_State *L, int index, comp_ids& ids){
        particles::color_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &q = check_add_component<particles::init_quad_interpolator>(ids);
        q.color = iv;
    }),
    std::make_pair("color_over_life", [](lua_State *L, int index, comp_ids& ids){
        particles::color_interp_value iv;
        lua_struct::unpack(L, index, iv);
        auto &q = check_add_component<particles::lifetime_quad_interpolator>(ids);
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