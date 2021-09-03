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

        v.texcoords1.type = BT_None;
        unpack_field_opt(L, idx, "texcoords1", v.texcoords1);
        if (v.texcoords1.type == BT_None){
            v.texcoords1 = v.texcoords0;
        }

        unpack_field(L, idx, "vertexCount", v.vertexCount);

        // for indices
        v.indices.type = BT_None;
        unpack_field_opt(L, idx, "indices", v.indices);
        v.indexCount = 0;
        unpack_field_opt(L, idx, "indexCount", v.indexCount);

        unpack_field(L, idx, "materialidx", v.materialidx);
        assert(v.materialidx > 0);
        --v.materialidx;

        unpack_field(L, idx, "lightmap", v.lightmap);
    }

    template <>
    inline void unpack<MaterialData>(lua_State* L, int idx, MaterialData& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field_opt(L, idx, "diffuse", v.diffuse);
        unpack_field_opt(L, idx, "normal", v.normal);
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
        unpack_field(L, idx, "intensity", v.intensity);
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

LUA2STRUCT(Lightmap, size);

LUA2STRUCT(Scene, models, lights, materials);

    //{
    //     MeshData md;
    //     glm::vec3 pos[] = {
    //         glm::vec3(-1.f, 0.f, 1.f),
    //         glm::vec3(1.f, 0.f, 1.f),
    //         glm::vec3(1.f, 0.f, -1.f),
    //         glm::vec3(-1.f, 0.f, -1.f),

    //         glm::vec3(-1.f,  1.f, 0.f),
    //         glm::vec3(1.f,  1.f, 0.f),
    //         glm::vec3(1.f, -1.f, 0.f),
    //         glm::vec3(-1.f, -1.f, 0.f),
    //     };

    //     glm::vec3 nor[] = {
    //         glm::vec3(0.f, 1.f, 0.f),
    //         glm::vec3(0.f, 1.f, 0.f),
    //         glm::vec3(0.f, 1.f, 0.f),
    //         glm::vec3(0.f, 1.f, 0.f),

    //         glm::vec3(0.f, 0.f, 1.f),
    //         glm::vec3(0.f, 0.f, 1.f),
    //         glm::vec3(0.f, 0.f, 1.f),
    //         glm::vec3(0.f, 0.f, 1.f),
    //     };

    //     glm::vec2 tex0[] = {
    //         glm::vec2(0.f, 0.f),
    //         glm::vec2(1.f, 0.f),
    //         glm::vec2(1.f, 1.f),
    //         glm::vec2(0.f, 1.f),

    //         glm::vec2(0.f, 0.f),
    //         glm::vec2(1.f, 0.f),
    //         glm::vec2(1.f, 1.f),
    //         glm::vec2(0.f, 1.f),
    //     };

    //     glm::vec2 lm_uv[] = {
    //         glm::vec2(0.f, 0.f),
    //         glm::vec2(1.f, 0.f),
    //         glm::vec2(1.f, 1.f),
    //         glm::vec2(0.f, 1.f),

    //         glm::vec2(0.f, 0.f),
    //         glm::vec2(1.f, 0.f),
    //         glm::vec2(1.f, 1.f),
    //         glm::vec2(0.f, 1.f),
    //     };

    //     auto set_buffer = [](auto &b, auto data, auto type, auto stride, auto offset){
    //         b.data = (const char*)data;
    //         b.type = type;
    //         b.stride = stride, b.offset = offset;
    //     };
        
    //     set_buffer(md.positions, pos, BT_Float, 12, 0);
    //     set_buffer(md.normals, nor, BT_Float, 12, 0);
    //     set_buffer(md.texcoords0, tex0, BT_Float, 8, 0);
    //     set_buffer(md.texcoords1, lm_uv, BT_Float, 8, 0);

    //     set_buffer(md.tangents, nullptr, BT_None, 0, 0);
    //     set_buffer(md.bitangents, nullptr, BT_None, 0, 0);
    //     md.vertexCount = 8;

    //     uint16_t indices[] = {
    //         0, 1, 2,
    //         2, 3, 0,

    //         4, 5, 6,
    //         6, 7, 4,
    //     };

    //     md.indexCount = 12;

    //     set_buffer(md.indices, indices, BT_Uint16, 2, 0);

    //     md.worldmat = glm::mat4(1.f);
    //     md.normalmat = glm::mat4(1.f);
        
    //     md.materialidx = 0;
    //     s.models.push_back(md);
    //     s.materials.push_back(MaterialData());
    // }
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

    lua_createtable(L, (int)br.lightmaps.size(), 0);
    for (size_t ii=0; ii<br.lightmaps.size(); ++ii){
        lua_createtable(L, 0, 3);{
            const auto &lm = br.lightmaps[ii];
            const auto texelsize = sizeof(glm::vec4);
            lua_pushlstring(L, (const char*)lm.data.data(), lm.data.size() * texelsize);
            lua_setfield(L, -2, "data");

            lua_pushinteger(L, lm.size);
            lua_setfield(L, -2, "size");

            lua_pushinteger(L, texelsize);
            lua_setfield(L, -2, "texelsize");
        }
        lua_seti(L, -2, ii+1);
    }

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
        {"destroy", lbaker_destroy},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
}