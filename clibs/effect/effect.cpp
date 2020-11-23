#include "pch.h"

#include "particle.h"
#include "transforms.h"
#include "random.h"

#include "quadcache.h"
#include "lua2struct.h"

#include "lua.hpp"

#define EXPORT_BGFX_INTERFACE
#include "bgfx/bgfx_interface.h"

std::unordered_map<std::string, std::function<transform* (lua_State *, int)>> g_attrib_factories = {
    {std::make_pair("scale", [](lua_State *L, int index){
        return (transform*)nullptr;
    })},
    {std::make_pair("translation", [](lua_State *L, int index){
        return (transform*)nullptr;
    })},
    {std::make_pair("rotation", [](lua_State*L, int index){
        return (transform*)nullptr;
    })},
    {std::make_pair("uv",[](lua_State *L, int index){
        return (transform*)nullptr;
    })},
    {std::make_pair("color",[](lua_State *L, int index){
        return (transform*)nullptr;
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

    return 1;
}

extern "C" int
luaopen_effect(lua_State *L){
    init_interface(L);

    luaL_Reg l[] = {
        { "init",               leffect_init },
        { "shutdown",           leffect_shutdown },
        { "create_particles",   leffect_create_particles},
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}

