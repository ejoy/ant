#include "pch.h"

#include "lua.hpp"
#include "lua2struct.h"
#include "attributes.h"
#include "particle.h"

// LUA2STRUCT(float_interp_attrib, minv, maxv);
// LUA2STRUCT(v3_interp_attrib, minv, maxv);

// LUA2STRUCT(struct v3_componet_attrib, type, interp_attrib);
// LUA2STRUCT(struct float_componet_attrib, type, interp_attrib);
// LUA2STRUCT(struct emitter_lifetime, lifetime);

LUA2STRUCT(struct particles::spawndata, count, rate);
LUA2STRUCT(struct particles::uv_motion_data, u_speed, v_speed, scale);

namespace lua_struct {
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