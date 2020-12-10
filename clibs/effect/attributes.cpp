#include "pch.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "particle.h"
#include "random.h"

LUA2STRUCT(struct render_data, viewid, progid, qb, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

LUA2STRUCT(struct particles::spawn, count, rate);

using p_color_attrib = particles::spawn::color_attributeT<particles::spawn::init_valueT<float>>;
namespace lua_struct {
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

    template<typename T>
    void unpack_interp_value(lua_State* L, int index, particles::spawn::init_valueT<T> &iv) {
        luaL_checktype(L, index, LUA_TTABLE);
        const char *t = nullptr;
        if (LUA_TSTRING == lua_getfield(L, index, "interp_type")){
            t = lua_tostring(L, -1);
        }
        lua_pop(L, 1);

        if (strcmp(t, "const") == 0){
            iv.interp_type = 0;
            if (!get_field(L, index, "value", iv.minv)){
                luaL_error(L, "'interp_type' const need 'value' field");
            }
        } else if (strcmp(t, "linear") == 0){
            iv.interp_type = 1;
            if (!(get_field(L, index, "minv", iv.minv) && get_field(L, index, "maxv", iv.maxv))){
                luaL_error(L, "'interp_type' need 'minv' and 'maxv' fields");
            }
        } else if (strcmp(t, "curve") == 0){
            luaL_error(L, "not support curve as 'interp_type'");
        } else {
            luaL_error(L, "invalid 'interp_type'");
        }
    }

    template<>
    void unpack(lua_State* L, int index, p_color_attrib &civ, void*) {
        auto check_rgba = [](lua_State* L, int index, p_color_attrib &civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGBA")){
                isvalid = true;
                particles::spawn::init_valueT<glm::vec4> f4v;
                unpack_interp_value(L, index, f4v);
                for (int ii=0; ii<4; ++ii){
                    civ.rgba[ii].minv = f4v.minv[ii];
                    civ.rgba[ii].maxv = f4v.maxv[ii];
                    civ.rgba[ii].interp_type = f4v.interp_type;
                }
            }
            lua_pop(L, 1);
            return isvalid;
        };

        auto check_rgb = [](lua_State* L, int index, p_color_attrib &civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGB")){
                isvalid = true;
                particles::particles::spawn::init_valueT<glm::vec3> f3v;
                unpack_interp_value(L, -1, f3v);
                for (int ii=0; ii<3; ++ii){
                    civ.rgba[ii].minv = f3v.minv[ii];
                    civ.rgba[ii].maxv = f3v.maxv[ii];
                    civ.rgba[ii].interp_type = f3v.interp_type;
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

#define DEF_INTERP_VALUE_UNPACK(_INTERPTYPE) \
    template<>\
    void unpack(lua_State* L, int index, _INTERPTYPE &iv, void*) {\
        unpack_interp_value(L, index, iv);\
    }

    DEF_INTERP_VALUE_UNPACK(particles::spawn::init_valueT<float>);
    DEF_INTERP_VALUE_UNPACK(particles::spawn::init_valueT<glm::vec2>);
    DEF_INTERP_VALUE_UNPACK(particles::spawn::init_valueT<glm::vec3>);

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


    template<>
    void unpack(lua_State* L, int index, quad_buffer& qb, void*) {
        if (LUA_TNUMBER == lua_getfield(L, index, "ib")){
            qb.ib.idx = (uint16_t)lua_tonumber(L, -1);
        } else {
            luaL_error(L, "invalid 'ib'");
        }
        lua_pop(L, 1);
        if (LUA_TUSERDATA == lua_getfield(L, index, "layout")){
            qb.layout = (bgfx_vertex_layout_t*)lua_touserdata(L, -1);
        } else {
            luaL_error(L, "invalid pointer");
        }
        lua_pop(L, 1);
    }
    template<>
    void pack(lua_State* L, const quad_buffer& qb, void*){}
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
        particles::spawn::init_valueT<float> iv;
        lua_struct::unpack(L, index, iv);
        randomobj ro;
        check_add_id(particle_mgr::get().add_component(particles::life(iv.get(ro()))), ids);
    }),
    std::make_pair("spawn", [](lua_State *L, int index, comp_ids& ids){
        particles::spawn sd;
        lua_struct::unpack(L, index, sd);

        check_add_id(particle_mgr::get().add_component(sd), ids);
    }),
    std::make_pair("init_lifetime", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::life::ID());
        lua_struct::unpack(L, index, sp.init.life);

    }),
    std::make_pair("init_scale", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::scale::ID());
        lua_struct::unpack(L, index, sp.init.scale);
    }),
    std::make_pair("scale_over_life", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.interp.components.push_back(particles::scale_interpolator::ID());
        particles::spawn::init_valueT<glm::vec3> scale_iv;
        lua_struct::unpack(L, index, scale_iv);
        sp.interp.scale.from_init_value(scale_iv);
        
    }),
    std::make_pair("init_translation", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.interp.components.push_back(particles::translation::ID());
        lua_struct::unpack(L, index, sp.init.translation);
    }),
    std::make_pair("init_color", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::quad::ID());
        lua_struct::unpack(L, index, sp.init.color);
    }),
    std::make_pair("color_over_life", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.interp.components.push_back(particles::color_interpolator::ID());
        p_color_attrib iv;
        lua_struct::unpack(L, index, iv);
        
        for (int ii = 0; ii < 4; ++ii) {
            sp.interp.color.rgba[ii].from_init_value(iv.rgba[ii]);
        }
    }),
    std::make_pair("init_velocity", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::velocity::ID());
        lua_struct::unpack(L, index, sp.init.velocity);
    }),
    std::make_pair("init_acceleration", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::acceleration::ID());
        lua_struct::unpack(L, index, sp.init.acceleration);
    }),
    std::make_pair("uv_motion", [](lua_State *L, int index, comp_ids& ids){
        auto& sp = particle_mgr::get().component_value<particles::spawn>();
        sp.init.components.push_back(particles::uv_motion::ID());
        lua_struct::unpack(L, index, sp.init.uv_motion);
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