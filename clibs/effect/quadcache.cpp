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
    , mquadsize(maxquad)
    , mdyn_vb(BGFX(create_dynamic_vertex_buffer)(maxquad * 4, layout, BGFX_BUFFER_ALLOW_RESIZE))
    , mvertiecs(new quad_vertex[maxquad * 4UL * (size_t)layout->stride])
    , moffset(0)
{
    assert(BGFX_HANDLE_IS_VALID(mib));
    assert(BGFX_HANDLE_IS_VALID(mdyn_vb));
}

quad_cache::~quad_cache(){
    BGFX(destroy_dynamic_vertex_buffer)(mdyn_vb);
    delete mvertiecs; mvertiecs = nullptr;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, const glm::vec3 &p){
    const uint32_t idx = quadidx * 4 + vidx;
    auto ptr = mvertiecs + idx;
    ptr->p = p;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, const glm::vec2 &uv){
    mvertiecs[quadidx * 4 + vidx].uv = uv;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, uint32_t c){
    mvertiecs[quadidx * 4 + vidx].color = c;
}

void quad_cache::set(uint32_t quadidx, uint32_t vidx, const quad_vertex &v){
    mvertiecs[quadidx * 4 + vidx] = v;
}

void quad_cache::set(uint32_t start, uint32_t num, const quad_vertex *vv){
    memcpy(mvertiecs + start + sizeof(quad_vertex), vv, num * sizeof(quad_vertex));
}

//
//	1 ---- 3
//	|      |
//	|      |
//	0 ---- 2
static const quad_vertex s_default_quad[] = {
    {glm::vec3(-0.5f, -0.5f, 0.0f), glm::vec2(0.0f, 0.0f), 0xffffffff},
    {glm::vec3(-0.5f,  0.5f, 0.0f), glm::vec2(0.0f, 1.0f), 0xffffffff},
    {glm::vec3( 0.5f, -0.5f, 0.0f), glm::vec2(1.0f, 1.0f), 0xffffffff},
    {glm::vec3( 0.5f,  0.5f, 0.0f), glm::vec2(1.0f, 0.0f), 0xffffffff},
};

void quad_cache::reset_quad(uint32_t start, uint32_t num){
    for (uint32_t ii=0; ii<num; ++ii){
        auto ptr = mvertiecs + (start+ii) * 4;
        memcpy(ptr, s_default_quad, sizeof(s_default_quad));
    }
}

void quad_cache::init_transform(uint32_t quadidx){
    auto ptr = mvertiecs + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = s_default_quad[ii].p;
    }
}

void quad_cache::transform(uint32_t quadidx, const glm::mat4 &trans){
    auto ptr = mvertiecs + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = trans * glm::vec4(ptr[ii].p, 1.f);
    }
}

void quad_cache::rotate(uint32_t quadidx, const glm::quat &q){
    auto ptr = mvertiecs + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::rotate(q, glm::vec4(ptr[ii].p, 1.f));
    }
}

void quad_cache::scale(uint32_t quadidx, const glm::vec3 &s){
    auto ptr = mvertiecs + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::scale(s) * glm::vec4(ptr[ii].p, 1.f);
    }
}

void quad_cache::translate(uint32_t quadidx, const glm::vec3 &t){
    auto ptr = mvertiecs + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::translate(t) * glm::vec4(ptr[ii].p, 1.f);
    }
}

void quad_cache::update(){
    if (moffset > 0){
        const uint32_t buffersize = moffset * sizeof(quad_vertex) * 4;
        // why we should copy the memory to bgfx, but not use make_ref/make_ref_release to shared the memory:
        //    1). bgfx use multi-thread rendering, memory will pass to bgfx render thread, but memory will still update in main thread
        //    2). if app shutdown, memory will delete in quad_cache's deconstruct, but memory will still access in bgfx render threading
        // so, solution is simple, use automic lock to tell update thread and render threading when to release memory
        // and alloc 2 times memory, one for update, one for render.
        // but it not worth doing this. because if BGFX(alloc) will just put a pointer, but not really alloc memory
        const auto mem = BGFX(alloc)(buffersize);
        memcpy(mem->data, mvertiecs, buffersize);
        BGFX(update_dynamic_vertex_buffer)(mdyn_vb, 0, mem);
    }
}

void quad_cache::submit(uint32_t offset, uint32_t num){
    const uint32_t indices_num = num * 6;
    BGFX(set_index_buffer)(mib, 0, num);

    const uint32_t startv = offset * 4;
    assert(offset + num <= mquadsize);
    BGFX(set_dynamic_vertex_buffer)(0, mdyn_vb, startv, num * 4);
}

////////////////////////////////////////////////////////////////

static int
linit(lua_State *L){

    const bgfx_index_buffer_handle_t ibhandle = {(uint16_t)luaL_checkinteger(L, 1)};
    const auto layout = (bgfx_vertex_layout_t*)lua_touserdata(L, 2);

    quad_cache::create(ibhandle, layout, 1024);
    return 0;
}

static int
lshutdown(lua_State *L){
    quad_cache::destroy();
    return 0;
}

static int
lalloc(lua_State *L){
    const uint32_t num = (uint32_t)luaL_optnumber(L, 1, 1);
    const auto offset = quad_cache::get().alloc(num);
    if (offset == UINT32_MAX){
        return luaL_error(L, "invalid quad_cache alloc");
    }
    lua_pushinteger(L, offset);
    return 1;
}

static int
lbuffer(lua_State *L){
    auto ib = quad_cache::get().get_ib();
    auto vb = quad_cache::get().get_vb();

    lua_pushinteger(L, BGFX_LUAHANDLE(DYNAMIC_VERTEX_BUFFER, vb));
    lua_pushinteger(L, BGFX_LUAHANDLE(INDEX_BUFFER, ib));

    return 2;
}

extern "C" {
LUAMOD_API int
    luaopen_effect_quadcache(lua_State *L){
        luaL_Reg l[] = {
            {"init",        linit},
            {"shutdown",    lshutdown},
            {"alloc",       lalloc},
            {nullptr,       nullptr},
        };

        luaL_newlib(L, l);
        return 1;
    }
}