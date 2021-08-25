#include "lua.hpp"
#include "BakerInterface.h"

#include "lua2struct.h"
#include "luabgfx.h"

namespace lua_struct {
    template<>
    inline void unpack<glm::vec3>(lua_State *L, int idx, glm::vec3 &v, void*){
        luaL_checktype(L, idx, LUA_TTABLE);
        for (int ii=0; ii<3; ++ii){
            lua_geti(L, idx, ii+1);
            v[ii] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    }

    template<>
    inline void unpack<glm::vec4>(lua_State *L, int idx, glm::vec4 &v, void*){
        luaL_checktype(L, idx, LUA_TTABLE);
        for (int ii=0; ii<4; ++ii){
            lua_geti(L, idx, ii+1);
            v[ii] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    }

    template<>
    inline void unpack<glm::mat4>(lua_State *L, int idx, glm::mat4 &v, void*){
        luaL_checktype(L, idx, LUA_TTABLE);
        float *vv = &v[0].x;
        for (int ii=0; ii<16; ++ii){
            lua_geti(L, idx, ii+1);
            vv[ii] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    }

    template <>
    inline void unpack<BufferData>(lua_State* L, int idx, BufferData& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field(L, idx, "data", v.data);
        unpack_field(L, idx, "stride", v.stride);
        const char* type = nullptr;
        unpack_field(L, idx, "type", type);
        switch (type[0]){
            case 'B': v.type = BT_Byte; break;
            case 'H': v.type = BT_Uint16; break;
            case 'I': v.type = BT_Uint32; break;
            case 'f': v.type = BT_Float; break;
            case '\0':v.type = BT_None; break;
            default: luaL_error(L, "invalid data type:%s", type);
        }
    }

    template <>
    inline void unpack<Light>(lua_State* L, int idx, Light& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field(L, idx, "dir", v.dir);
        unpack_field(L, idx, "pos", v.pos);
        unpack_field(L, idx, "color", v.color);
        unpack_field(L, idx, "size", v.size);
        const char* type = nullptr;
        unpack_field(L, idx, "type", type);
        if (strcmp(type, "directional") == 0){
            v.type = LT_Directional;
        } else if (strcmp(type, "area") == 0){
            v.type = LT_AreaLight;
        } else {
            luaL_error(L, "invalid light type:%s", type);
        }
    }
}

LUA2STRUCT(MeshData, worldmat, positions, normals, tangents, bitangents, texcoord0, texcoord1, indices, materialidx);
LUA2STRUCT(MaterialData, diffuseTex, normalTex, metallicRoughnessTex);
LUA2STRUCT(Scene, models, lights, materials);

static int
lbaker_create(lua_State *L){
    Scene s;
    lua_struct::unpack(L, 1, s);
    BakerHandle bh = CreateBaker(&s);
    lua_pushlightuserdata(L, bh);
    return 1;
}

static int
lbaker_bake(lua_State *L){
    auto bh = (BakerHandle)lua_touserdata(L, 1);
    BakeResult br;
    Bake(bh, &br);
    lua_createtable(L, 0, 0);
    lua_pushlstring(L, (const char*)br.lm.data.data(), br.lm.data.size());
    lua_setfield(L, -2, "data");

    lua_pushinteger(L, br.lm.size);
    lua_setfield(L, -2, "sieze");

    lua_pushinteger(L, br.lm.texelsize);
    lua_setfield(L, -2, "texelsize");
    return 1;
}

static int
lbaker_destroy(lua_State *L){
    auto bh = (BakerHandle)lua_touserdata(L, 1);
    DestroyBaker(bh);
    return 0;
}

extern "C"{
LUAMOD_API int
luaopen_bake2(lua_State* L) {
    luaL_Reg lib[] = {
        {"create",  lbaker_create},
        {"bake",    lbaker_bake},
        {"destory", lbaker_destroy},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
}