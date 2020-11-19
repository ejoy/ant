#include "pch.h"

#include "particle.h"
#include "transforms.h"
#include "random.h"

#include "quadcache.h"
#include "lua2struct.h"

#include "lua.hpp"

#define EXPORT_BGFX_INTERFACE
#include "bgfx/bgfx_interface.h"

struct effect_context{
};

std::unordered_map<std::string, std::function<attribute* (lua_State *, int)>> g_attrib_factories = {
    {std::make_pair("scale", [](lua_State *L, int index){
        return (attribute*)nullptr;
    })},
    {std::make_pair("translation", [](lua_State *L, int index){
        return (attribute*)nullptr;
    })},
    {std::make_pair("rotation", [](lua_State*L, int index){
        return (attribute*)nullptr;
    })},
    {std::make_pair("uv",[](lua_State *L, int index){
        return (attribute*)nullptr;
    })},
};

static int
leffect_init(lua_State *L){
    return 1;
}

static int
leffect_shutdown(lua_State *L){
    return 1;
}

static attribute*
create_attribute(lua_State *L, int index, const char* name){
    
}

static inline void
init_emitter(lua_State *L, int argidx, int eidx){

}

struct attribte_wrapper{
    attribute *v;
};

static int
lattribute_del(lua_State *L){
    auto attrib = (attribte_wrapper *)luaL_checkudata(L, 1, "ATTRIBUTE_MT");
    if (attrib->v){
        delete attrib->v;
        attrib->v = nullptr;
    }
    return 0;
}

static int
leffect_create_attribute(lua_State *L){
    auto name = luaL_checkstring(L, 1);
    auto it = g_attrib_factories.find(name);
    if (it != g_attrib_factories.end()){
        auto aw = (attribte_wrapper*)lua_newuserdatauv(L, sizeof(attribte_wrapper), 0);
        aw->v = it->second(L, 2);
    }
    return 0;
}

struct spawninfo {
    uint32_t    count;
    glm::vec2   lifetime_range;
    uint8_t     type;
};
LUA2STRUCT(struct spawninfo, count, lifetime_range, type);
LUA2STRUCT(glm::vec2, x, y);

static int
leffect_create_particles(lua_State *L){
    spawninfo si;
    lua_struct::unpack(L, 1, si);

    std::mt19937 gen(std::random_device().operator()());

    auto rdobj = randomobj::create(si.lifetime_range);
    const uint32_t idx = quad_cache::get().alloc(si.count);
    uint32_t pidx = 0;

    auto pw = (particles_set*)lua_newuserdatauv(L, sizeof(particles_set) + (si.count - 1) * sizeof(uint16_t), 0);
    pw->count = si.count;
    for (uint32_t ii=0; ii<si.count; ++ii){
        pidx    = particle_mgr::get().spawn_valid(pidx);
        auto &p = particle_mgr::get().get_particle(pidx);
        p.idx = idx + ii;
        p.lifetime = rdobj();
        p.currenttime = 0.f;
        p.isdead = true;

        pw->indices[ii] = pidx;
    }
    return 1;
}

extern "C" int
luaopen_effect(lua_State *L){
    init_interface(L);

    luaL_Reg l[] = {
        { "init",           leffect_init },
        { "shutdown",       leffect_shutdown },
        { "create_attribute", leffect_create_attribute},
        { "create_particles", leffect_create_particles},
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}

