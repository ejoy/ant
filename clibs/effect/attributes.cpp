#include "pch.h"
#include "attributes.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "particle.h"
#include "particle_mgr.h"
#include "emitter.h"
#include "random.h"

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

    template <int NUM, typename ELEMTYPE>
    void unpack_vec(lua_State* L, int idx, glm::vec<NUM, ELEMTYPE, glm::defaultp>& v) {
        const int ltype = lua_type(L, idx);
        if (LUA_TTABLE == ltype){
            const int len = (int)luaL_len(L, idx);
            if (len < NUM) {
                luaL_error(L, "invalid vec: %d", len);
            }
            for (int ii = 0; ii < NUM; ++ii) {
                lua_geti(L, idx, ii + 1);
                v[ii] = (ELEMTYPE)lua_tonumber(L, -1);
                lua_pop(L, 1);
            }
        } else if (LUA_TLIGHTUSERDATA == ltype){
            auto t = (const ELEMTYPE*)lua_touserdata(L, idx);
            memcpy(&v, t, sizeof(ELEMTYPE) * NUM);
        }
    }

#define DEF_VEC_UNPACK(_VECTYPE) template<>\
    void unpack(lua_State* L, int index, _VECTYPE &v, void*) {\
        unpack_vec(L, index, v);\
    }\
    template<>\
    void pack(lua_State* L, const _VECTYPE &v, void*) {}

    DEF_VEC_UNPACK(glm::ivec2);
    DEF_VEC_UNPACK(glm::u8vec2);
    DEF_VEC_UNPACK(glm::vec2);
    DEF_VEC_UNPACK(glm::u8vec3);
    DEF_VEC_UNPACK(glm::vec3);
    DEF_VEC_UNPACK(glm::u8vec4);
    DEF_VEC_UNPACK(glm::vec4);

    template<typename T>
    void unpack_interp_value(lua_State* L, int index, interpolation::init_valueT<T> &iv) {
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

#define DEF_INTERP_VALUE_UNPACK(_INTERPTYPE) \
    template<>\
    void unpack(lua_State* L, int index, _INTERPTYPE &iv, void*) {\
        unpack_interp_value(L, index, iv);\
    }

    DEF_INTERP_VALUE_UNPACK(interpolation::init_valueT<float>);
    DEF_INTERP_VALUE_UNPACK(interpolation::init_valueT<uint16_t>);
    DEF_INTERP_VALUE_UNPACK(interpolation::f2_init_value);
    DEF_INTERP_VALUE_UNPACK(interpolation::f3_init_value);

    template<>
    void unpack(lua_State* L, int index, interpolation::color_init_value &civ, void*) {
        auto check_rgba = [](lua_State* L, int index, interpolation::color_init_value &civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGBA")){
                isvalid = true;
                interpolation::init_valueT<glm::u8vec4> f4v;
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

        auto check_rgb = [](lua_State* L, int index, interpolation::color_init_value&civ){
            bool isvalid = false;
            if (LUA_TTABLE == lua_getfield(L, index, "RGB")){
                isvalid = true;
                interpolation::init_valueT<glm::u8vec3> f3v;
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

    template<>
    void unpack(lua_State *L, int index, interpolation::uv_motion_init_value &uvm_iv, void*){
        if (LUA_TTABLE == lua_getfield(L, index, "dimension")){
            uvm_iv.type = uv_motion::mt_index;
            unpack(L, -1, uvm_iv.index.dim);
            lua_pop(L, 1);

            if (LUA_TTABLE == lua_getfield(L, index, "rate")){
                unpack(L, index, uvm_iv.index.rate);
            } else {
                luaL_error(L, "invalid 'rate'");
            }
            lua_pop(L, 1);
        } else {
            lua_pop(L, 1);  // pop for 'dimension'
            if (LUA_TSTRING == lua_getfield(L, index, "interp_type")){
                uvm_iv.type = uv_motion::mt_speed;
            } else {
                luaL_error(L, "invalid data, need define 'dimension'&'rate' for uv_index or 'interp_type' for uv_speed");
            }
            lua_pop(L, 1);
            unpack(L, index, uvm_iv.speed);
        }
    }

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

static void default_reader(lua_State *, int, particle_emitter*, comp_ids&){}

std::unordered_map<std::string, readerop> g_attrib_map = {
    std::make_pair("count", default_reader),
    std::make_pair("rate", default_reader),
    std::make_pair("init_lifetime", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::life::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.life);

    }),
    std::make_pair("init_scale", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::scale::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.scale);
    }),
    std::make_pair("scale_over_life", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        
        interpolation::f3_init_value scale_iv;
        lua_struct::unpack(L, index, scale_iv);

        check_add_id(particles::scale::ID(), emitter->mspawn.init.components);
        emitter->mspawn.init.scale.interp_type = 0;
        emitter->mspawn.init.scale.minv = scale_iv.minv;

        emitter->mspawn.interp.components.push_back(particles::scale_interpolator::ID());
        emitter->mspawn.interp.scale.from_init_value(scale_iv);
    }),
    std::make_pair("init_rotation", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::rotation::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.rotation);
    }),
    std::make_pair("rotation_over_life", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        interpolation::init_valueT<float> iv;
        lua_struct::unpack(L, index, iv);

        check_add_id(particles::rotation::ID(), emitter->mspawn.init.components);
        emitter->mspawn.init.rotation.interp_type = 0;
        emitter->mspawn.init.rotation.minv = iv.minv;

        emitter->mspawn.interp.components.push_back(particles::rotation::ID());
        emitter->mspawn.interp.rotation.from_init_value(iv);
    }),
    std::make_pair("init_translation", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::translation::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.translation);
    }),
    std::make_pair("init_color", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::color::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.color);
    }),
    std::make_pair("color_over_life", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.interp.components.push_back(particles::color_interpolator::ID());
        interpolation::color_init_value iv;
        lua_struct::unpack(L, index, iv);

        // we should override init.color value
        check_add_id(particles::color::ID(), emitter->mspawn.init.components);
        
        for (int ii = 0; ii < 4; ++ii) {
            auto &ic = emitter->mspawn.init.color.rgba[ii];
            const auto& c = iv.rgba[ii];
            ic.minv = c.minv;
            ic.interp_type = 0;
            emitter->mspawn.interp.color.rgba[ii].from_init_value(c);
        }
    }),
    std::make_pair("init_velocity", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::velocity::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.velocity);
    }),
    std::make_pair("init_acceleration", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::acceleration::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.acceleration);
    }),
    std::make_pair("uv_motion", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::uv_motion::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.uv_motion);
    }),
    std::make_pair("uv_index", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::uv_motion::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.uv_motion);
    }),
    std::make_pair("subuv_motion", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::subuv_motion::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.subuv_motion);
    }),
    std::make_pair("subuv_index", [](lua_State *L, int index, particle_emitter* emitter, comp_ids& ids){
        emitter->mspawn.init.components.push_back(particles::subuv_motion::ID());
        lua_struct::unpack(L, index, emitter->mspawn.init.subuv_motion);
    }),
};

readerop find_attrib_reader(const std::string &name){
    auto it = g_attrib_map.find(name);
    if (it == g_attrib_map.end()){
        assert(false && ("invalid spawn attribute: " + name).c_str());
        return default_reader;
    }

    return it->second;
}