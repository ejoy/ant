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

quad_cache::quad_cache(bgfx_index_buffer_handle_t ib, const bgfx_vertex_layout_t* layout, uint32_t maxquad)
    : mib(ib)
    , mlayout(layout)
    , mmax_quad(maxquad)
{
    assert(BGFX_HANDLE_IS_VALID(mib));
}

//
//	1 ---- 3
//	|      |
//	|      |
//	0 ---- 2
static const quad_cache::vertex s_default_quad[] = {
    {glm::vec3(-0.5f, -0.5f, 0.0f), glm::vec2(0.0f, 0.0f), 0xffffffff},
    {glm::vec3(-0.5f,  0.5f, 0.0f), glm::vec2(0.0f, 1.0f), 0xffffffff},
    {glm::vec3( 0.5f, -0.5f, 0.0f), glm::vec2(1.0f, 1.0f), 0xffffffff},
    {glm::vec3( 0.5f,  0.5f, 0.0f), glm::vec2(1.0f, 0.0f), 0xffffffff},
};

void quad_cache::transform(quad_cache::quad &q, const glm::mat4 &trans){
    for (uint32_t ii=0; ii<4; ++ii){
        q[ii].p = trans * glm::vec4(q[ii].p, 1.f);
    }
}

void quad_cache::rotate(quad_cache::quad &q, const glm::quat &r){
    for (uint32_t ii=0; ii<4; ++ii){
        q[ii].p = glm::rotate(r, glm::vec4(q[ii].p, 1.f));
    }
}

void quad_cache::scale(quad_cache::quad &q, const glm::vec3 &s){
    for (uint32_t ii=0; ii<4; ++ii){
        q[ii].p = glm::scale(s) * glm::vec4(q[ii].p, 1.f);
    }
}

void quad_cache::translate(quad_cache::quad &q, const glm::vec3 &t){
    for (uint32_t ii=0; ii<4; ++ii){
        q[ii].p = glm::translate(t) * glm::vec4(q[ii].p, 1.f);
    }
}

// void quad_cache::update(){
//     // why we should copy the memory to bgfx, but not use make_ref/make_ref_release to shared the memory:
//     //    1). bgfx use multi-thread rendering, memory will pass to bgfx render thread, but memory will still update in main thread
//     //    2). if app shutdown, memory will delete in quad_cache's deconstruct, but memory will still access in bgfx render threading
//     // so, solution is simple, use automic lock to tell update thread and render threading when to release memory
//     // and alloc 2 times memory, one for update, one for render.
//     // but it not worth doing this. because if BGFX(alloc) will just put a pointer, but not really alloc memory

//     if (mquads.size() <= mmax_quad){
//         const uint32_t bufsize = (uint32_t)mquads.size() * sizeof(quad);
//         const auto mem = BGFX(alloc)(bufsize);
//         memcpy(mem->data, &mquads.front(), bufsize);
//         BGFX(update_dynamic_vertex_buffer)(mdyn_vb, 0, mem);
//     }
// }

void quad_cache::submit(uint32_t offset, uint32_t num){
    const uint32_t indices_num = num * 6;
    BGFX(set_index_buffer)(mib, 0, num);

    bgfx_transient_vertex_buffer_t tvb;
    const uint32_t bufsize = num * sizeof(vertex) * 4;
    BGFX(alloc_transient_vertex_buffer)(&tvb, bufsize, mlayout);
    memcpy(tvb.data, &mquads[offset], bufsize);

    const uint32_t startv = offset * 4;
    assert(offset + num <= mmax_quad);
    BGFX(set_transient_vertex_buffer)(0, &tvb, startv, num *4);
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
    const uint32_t maxquad = (uint32_t)luaL_optinteger(L, 3, 1024);

    quad_cache *qc = (quad_cache*)lua_newuserdatauv(L, sizeof(quad_cache), 0);
    new (qc) quad_cache(ibhandle, layout, maxquad);

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
    quad_cache::quad q;
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

extern "C" {
LUAMOD_API int
    luaopen_effect_quadcache(lua_State *L){
        luaL_Reg l[] = {
            {"create",      lcreate},
            {"addquad",     laddquad},
            {nullptr,       nullptr},
        };

        luaL_newlib(L, l);
        return 1;
    }
}