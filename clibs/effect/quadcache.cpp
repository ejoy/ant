#include "pch.h"
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
}

quad_cache::~quad_cache(){
    if (BGFX_HANDLE_IS_VALID(mdyn_vb)){
        BGFX(destroy_dynamic_vertex_buffer)(mdyn_vb);
    }
    mvertiecs = nullptr;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, const glm::vec3 &p){
    const uint32_t idx = quadidx * 4 + vidx;
    auto ptr = mvertiecs.get() + idx;
    ptr->p = p;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, const glm::vec2 &uv){
    const uint32_t idx = quadidx * 4 + vidx;
    auto ptr = mvertiecs.get() + idx;
    ptr->uv = uv;
}

void quad_cache::set_attrib(uint32_t quadidx, uint32_t vidx, uint32_t c){
    const uint32_t idx = quadidx * 4 + vidx;
    auto ptr = mvertiecs.get() + idx;
    ptr->color = c;
}

void quad_cache::set(uint32_t quadidx, uint32_t vidx, const quad_vertex &v){
    const uint32_t idx = quadidx * 4 + vidx;
    auto ptr = mvertiecs.get() + idx;
    *ptr = v;
}

void quad_cache::set(uint32_t start, uint32_t num, const quad_vertex *vv){
    memcpy(mvertiecs.get() + start + sizeof(quad_vertex), vv, num * sizeof(quad_vertex));
}

void quad_cache::transform(uint32_t quadidx, const glm::mat4 &trans){
    auto ptr = mvertiecs.get() + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = trans * glm::vec4(ptr[ii].p, 1.f);
    }
}

void quad_cache::rotate(uint32_t quadidx, const glm::quat &q){
    auto ptr = mvertiecs.get() + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::rotate(q, glm::vec4(ptr[ii].p, 1.f));
    }
}

void quad_cache::scale(uint32_t quadidx, const glm::vec3 &s){
    auto ptr = mvertiecs.get() + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::scale(s) * glm::vec4(ptr[ii].p, 1.f);
    }
}

void quad_cache::translate(uint32_t quadidx, const glm::vec3 &t){
    auto ptr = mvertiecs.get() + quadidx * 4;
    for (uint32_t ii=0; ii<4; ++ii){
        ptr[ii].p = glm::translate(t) * glm::vec4(ptr[ii].p, 1.f);
    }
}

struct wrapper{
    using PT = decltype(quad_cache::mvertiecs);
    PT p;
    wrapper(PT p_):p(p_){}
};

void quad_cache::update(){
    if (moffset > 0){
        auto p = mvertiecs;

        auto mem = BGFX(make_ref_release)(mvertiecs.get(), moffset * sizeof(quad_vertex) * 4, 
        [](void *p, void *userdata){
            assert(((wrapper*)(userdata))->p.get() == p);
            delete userdata;
        },
        new wrapper(mvertiecs));

        BGFX(update_dynamic_vertex_buffer)(mdyn_vb, 0, mem);
    }
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

extern "C" int
luaopen_quadcache(lua_State *L){
    luaL_Reg l[] = {
        {"init",        linit},
        {"shutdown",    lshutdown},
        {"alloc",       lalloc},
        {nullptr,       nullptr},
    };

    luaL_newlib(L, l);
    return 1;
}