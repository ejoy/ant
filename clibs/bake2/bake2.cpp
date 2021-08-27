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
        unpack_field(L, idx, "offset", v.offset);
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
    inline void unpack<MeshData>(lua_State* L, int idx, MeshData& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field(L, idx, "worldmat", v.worldmat);
        unpack_field(L, idx, "normalmat", v.normalmat);
        unpack_field(L, idx, "positions", v.positions);
        unpack_field(L, idx, "normals",   v.normals);
        v.tangents.type = BT_None;
        unpack_field_opt(L, idx, "tangents", v.tangents);
        v.bitangents.type = BT_None;
        unpack_field_opt(L, idx, "bitangents", v.bitangents);
        unpack_field(L, idx, "texcoords0", v.texcoords0);
        unpack_field(L, idx, "texcoords1", v.texcoords1);
        unpack_field(L, idx, "materialidx", v.materialidx);
        unpack_field(L, idx, "vertexCount", v.vertexCount);
        v.indexCount = 0;
        unpack_field_opt(L, idx, "indexCount", v.indexCount);
        assert(v.materialidx > 0);
        --v.materialidx;
    }

    template <>
    inline void unpack<MaterialData>(lua_State* L, int idx, MaterialData& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field(L, idx, "diffuse", v.diffuse);
        unpack_field(L, idx, "normal", v.normal);
        unpack_field_opt(L, idx, "roughness", v.roughness);
        unpack_field_opt(L, idx, "metallic",   v.metallic);
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