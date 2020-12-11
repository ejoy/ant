#include "pch.h"
#define LUA_LIB

#include "quadcache.h"

#include "lua.hpp"
extern "C"{
    #include "bgfx/luabgfx.h"
}

#include <glm/gtx/quaternion.hpp>

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

//
//	1 ---- 3
//	|      |
//	|      |
//	0 ---- 2
static const quad_vertex s_default_quad[] = {
    {glm::vec3(-0.5f, -0.5f, 0.0f), glm::vec2(0.0f, 0.0f), glm::vec2(0.0f, 0.0f), 0xffffffff},
    {glm::vec3(-0.5f,  0.5f, 0.0f), glm::vec2(0.0f, 1.0f), glm::vec2(0.0f, 1.0f), 0xffffffff},
    {glm::vec3( 0.5f, -0.5f, 0.0f), glm::vec2(1.0f, 0.0f), glm::vec2(1.0f, 0.0f), 0xffffffff},
    {glm::vec3( 0.5f,  0.5f, 0.0f), glm::vec2(1.0f, 1.0f), glm::vec2(1.0f, 1.0f), 0xffffffff},
};

static_assert(sizeof(quaddata) == sizeof(s_default_quad));

void quaddata::reset(){
    memcpy(v, s_default_quad, sizeof(s_default_quad));
}

//static
const quaddata& quaddata::default_quad(){
    return *(quaddata*)s_default_quad;
}

void quaddata::transform(const glm::mat4 &trans){
    for (uint32_t ii=0; ii<4; ++ii){
        v[ii].p = trans * glm::vec4(v[ii].p, 1.f);
    }
}

void quaddata::rotate(const glm::quat &r){
    for (uint32_t ii=0; ii<4; ++ii){
        v[ii].p = glm::rotate(r, glm::vec4(v[ii].p, 1.f));
    }
}

void quaddata::scale(const glm::vec3 &s){
    for (uint32_t ii=0; ii<4; ++ii){
        v[ii].p = glm::scale(s) * glm::vec4(v[ii].p, 1.f);
    }
}

void quaddata::translate(const glm::vec3 &t){
    for (uint32_t ii=0; ii<4; ++ii){
        v[ii].p = glm::translate(t) * glm::vec4(v[ii].p, 1.f);
    }
}



void quad_buffer::submit(const quadvector &quads){
    if (layout == nullptr || quads.empty())
        return ;

    const uint32_t num = (uint32_t)quads.size();
    const uint32_t indices_num = num * 6;
    BGFX(set_index_buffer)(ib, 0, indices_num);

    bgfx_transient_vertex_buffer_t tvb;
    const uint32_t bufsize = num * sizeof(quad_vertex) * 4;
    BGFX(alloc_transient_vertex_buffer)(&tvb, bufsize, layout);
    memcpy(tvb.data, quads.data(), bufsize);
    BGFX(set_transient_vertex_buffer)(0, &tvb, 0, num *4);
}

////////////////////////////////////////////////////////////////
static int
lqc_del(lua_State *L){
    quad_cache *qc = (quad_cache*)lua_touserdata(L, 1);
    qc->~quad_cache();
    return 0;
}

static inline quad_cache*
get_qc(lua_State *L, int idx=1){
    return (quad_cache*)luaL_checkudata(L, idx, "QUADCACHE_MT");
}

static int
lcreate(lua_State *L){
    const bgfx_index_buffer_handle_t ibhandle = {(uint16_t)luaL_checkinteger(L, 1)};
    const auto layout = (bgfx_vertex_layout_t*)lua_touserdata(L, 2);
    
    quad_cache *qc = (quad_cache*)lua_newuserdatauv(L, sizeof(quad_cache), 0);
    new (qc) quad_cache();
    qc->mqb.ib = ibhandle;
    qc->mqb.layout= layout;

    if (luaL_newmetatable(L, "QUADCACHE_MT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");

        luaL_Reg l[] = {
            {"__gc", lqc_del},
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);
    return 1;
}

static int
laddquad(lua_State *L){
    quad_cache *qc = (quad_cache*)lua_touserdata(L, 1);

    luaL_checktype(L, 2, LUA_TTABLE);
    const int num = (int)luaL_len(L, 2);
    if (num < 4){
        luaL_error(L, "quad need 4 vertex: %d", num);
    }
    quaddata q;
    for (int ii=0; ii<4; ++ii){
        auto &qv=q[ii];
        lua_geti(L, 2, ii+1);{
            //pos
            if (LUA_TTABLE != lua_geti(L, -1, 1)){
                luaL_error(L, "vertex[1] must be table with position elemenet");
            }
            const int elemnum = (int)luaL_len(L, -1);
            if (elemnum != 3){
                luaL_error(L, "position element must be 3 element");
            }
            for (int ie=0; ie<3; ++ie){
                lua_geti(L, -1, ie+1);
                qv.p[ie] = (float)lua_tonumber(L, -1);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);

            //color
            qv.color = (uint32_t)lua_tonumber(L, 2);
            //uv
            const int uvelemnum = (int)luaL_len(L, 3);
            lua_geti(L, -1, 3);{
                for (int jj=0; jj<2; ++jj){
                    lua_geti(L, -1, jj+1);
                    qv.uv[jj] = (float)lua_tonumber(L, -1);
                    lua_pop(L, 1);
                }
            }
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        
    }
    qc->mquads.push_back(q);

    return 0;
}

static int
lsubmit(lua_State *L){
    
    return 0;
}

extern "C" {
LUAMOD_API int
    luaopen_effect_quadcache(lua_State *L){
        luaL_Reg l[] = {
            {"create",      lcreate},
            {"addquad",     laddquad},
            {"submit",      lsubmit},
            {nullptr,       nullptr},
        };

        luaL_newlib(L, l);
        return 1;
    }
}