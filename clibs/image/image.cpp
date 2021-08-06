#include <lua.hpp>
#include <assert.h>
#include <cstring>
#include <bimg/bimg.h>
#include <bx/error.h>
#include <bx/readerwriter.h>
#include "luabgfx.h"

#include <vector>

#include "lua2struct.h"

LUA2STRUCT(bimg::TextureInfo, storageSize, width, height, depth, numLayers, numMips, bitsPerPixel, cubeMap);

struct encode_dds_info {
    bool srgb;
};

LUA2STRUCT(encode_dds_info, srgb);

static int
lparse(lua_State *L) {
    struct memory *mem = (struct memory *)luaL_checkudata(L, 1, "BGFX_MEMORY");
    bx::Error err;
    bimg::ImageContainer imageContainer;
    if (!bimg::imageParse(imageContainer, mem->data, (uint32_t)mem->size, &err)) {
        assert(!err.isOk());
        auto errmsg = err.getMessage();
        lua_pushlstring(L, errmsg.getPtr(), errmsg.getLength());
        return lua_error(L);
    }
    bimg::TextureInfo info;
    bimg::imageGetSize(&info
        , (uint16_t)imageContainer.m_width
        , (uint16_t)imageContainer.m_height
        , (uint16_t)imageContainer.m_depth
        , imageContainer.m_cubeMap
        , imageContainer.m_numMips > 1
        , imageContainer.m_numLayers
        , imageContainer.m_format
        );
    
    {
        lua_struct::pack(L, info);
        lua_pushstring(L, bimg::getName(info.format));
        lua_setfield(L, -2, "format");
    }
    return 1;
}

static int
lpack_memory(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
    const uint32_t n = (uint32_t)luaL_len(L, 1);

    const uint32_t memorywidth = (uint32_t)luaL_checkinteger(L, 2);
    const uint32_t memoryheight = (uint32_t)luaL_checkinteger(L, 3);

    const uint32_t packwidth = (uint32_t)luaL_checkinteger(L, 4);
    const uint32_t packheight = (uint32_t)luaL_checkinteger(L, 5);

    struct memory* packmemory = (struct memory*)luaL_checkudata(L, 6, "BGFX_MEMORY");

    std::vector<struct memory*> memories(n);
    uint32_t totalsize = 0;
    for (uint32_t i=0; i<n; ++i){
        lua_geti(L, 1, i+1);
        auto m = (struct memory*)luaL_checkudata(L, -1, "BGFX_MEMORY");
        totalsize += (uint32_t)m->size;
        memories[i] = m;
        lua_pop(L, 1);
    }

    if (packmemory->size != totalsize){
        luaL_error(L, "pack memory size is not enough: %d, %d", packmemory->size, totalsize);
    }

    if (packwidth*packheight != n){
        luaL_error(L, "pack width*height not equal memories count: %d, %d", packwidth*packheight, n);
    }

    const uint32_t sizeheight = packheight * memoryheight;
    uint8_t *pdata = (uint8_t*)packmemory->data;
    for (uint32_t ish=0; ish<sizeheight; ++ish){
        const uint32_t iph = ish/memoryheight;
        const uint32_t ph_idx = iph*packwidth;
        const uint32_t ish_offset = ish*memorywidth*packwidth;
        const uint32_t mh = ish % memoryheight;
        const uint32_t moffset = mh*memorywidth;
        for (uint32_t ipw=0; ipw<packwidth; ++ipw){
            const uint32_t poffset = ipw*memorywidth + ish_offset;
            const uint32_t idx = ipw + ph_idx;
            
            auto m = memories[idx];
            memcpy(pdata+poffset, (const uint8_t *)m->data+moffset, memorywidth);
        }
    }

    return 0;
}

static int
lencode_image(lua_State *L){
    bimg::ImageContainer ic;
    {
        bimg::TextureInfo info;
        lua_struct::unpack(L, 1, info);
        lua_getfield(L, 1, "format");
        const char* fmtname = lua_tostring(L, -1);
        info.format = bimg::getFormat(fmtname);
        lua_pop(L, 1);

        if (info.format == bimg::TextureFormat::Count){
            return luaL_error(L, "invalid format:%s", fmtname);
        }

        ic.m_width  = info.width;
        ic.m_height = info.height;
        ic.m_format = info.format;
        ic.m_size   = info.storageSize;
        ic.m_numLayers = info.numLayers;
        ic.m_numMips = info.numMips;
        ic.m_offset = 0;
        ic.m_depth = info.depth;
        ic.m_cubeMap = info.cubeMap;
        ic.m_data = nullptr;
        ic.m_allocator = nullptr;
    }

    struct memory *m = (struct memory *)luaL_checkudata(L, 2, "BGFX_MEMORY");

    luaL_checktype(L, 3, LUA_TTABLE);
    auto get_type = [L](int idx){
        auto t = lua_getfield(L, idx, "type");
        if (t != LUA_TSTRING){
            luaL_error(L, "invalid 'type' define in arg: %d, need string, like:dds, tga, png", t);
        }
        auto tt = lua_tostring(L, -1);
        lua_pop(L, 1);
        return tt;
    };

    const char* image_type = get_type(3);

    bx::Error err;
    if (strcmp(image_type, "dds") == 0){
        bx::DefaultAllocator allocator;
        bx::MemoryBlock mb(&allocator);
        bx::MemoryWriter sw(&mb);
        ic.m_ktx = ic.m_ktxLE = false;
        encode_dds_info ei;
        lua_struct::unpack(L, 3, ei);
        ic.m_srgb = ei.srgb;
        
        const int32_t filesize = bimg::imageWriteDds(&sw, ic, m->data, (uint32_t)m->size, &err);
        lua_pushlstring(L, (const char*)mb.more(), filesize);
    } else if (strcmp(image_type, "ktx") == 0){

    } else if (strcmp(image_type, "png") == 0){

    } else if (strcmp(image_type, "tga") == 0){

    } else {
        luaL_error(L, "not support image type:%s", image_type);
    }

    if (!err.isOk()){
        luaL_error(L, err.getMessage().getPtr());
    }
    return 1;
}

static int
lgetBitsPerPixel(lua_State *L){
    auto fmt = bimg::getFormat(luaL_checkstring(L, 1));
    auto bits = bimg::getBitsPerPixel(fmt);
    lua_pushinteger(L, bits);
    return 1;
}

extern "C" int
luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse", lparse },
        { "pack_memory", lpack_memory},
        { "encode_image", lencode_image},
        { "getBitsPerPixel", lgetBitsPerPixel},
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
