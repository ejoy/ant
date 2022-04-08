#include <lua.hpp>
#include <assert.h>
#include <cstring>
#include <bimg/bimg.h>
#include <bx/error.h>
#include <bx/readerwriter.h>
#include <bx/pixelformat.h>
#include <bimg/decode.h>
#include "luabgfx.h"

#include <vector>

#include "lua2struct.h"

LUA2STRUCT(bimg::TextureInfo, format, storageSize, width, height, depth, numLayers, numMips, bitsPerPixel, cubeMap);

namespace lua_struct {
    template <>
    inline void unpack<bimg::TextureFormat::Enum>(lua_State* L, int idx, bimg::TextureFormat::Enum& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        const char* name;
        unpack_field(L, idx, "format", name);
        v = bimg::getFormat(name);
    }
    template <>
    inline void pack<bimg::TextureFormat::Enum>(lua_State* L, bimg::TextureFormat::Enum const& fmt, void*) {
        auto name = bimg::getName(fmt);
        lua_pushstring(L, name);
    }
}

struct encode_dds_info {
    bool srgb;
};

LUA2STRUCT(encode_dds_info, srgb);

static inline struct memory*
TO_MEM(lua_State *L, int idx){
    return (struct memory *)luaL_checkudata(L, idx, "BGFX_MEMORY");
}

static int
lparse(lua_State *L) {
    auto mem = TO_MEM(L, 1);
    bool readcontent = lua_isnoneornil(L, 2);
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
    
    lua_struct::pack(L, info);

    if (readcontent){
        lua_pushlstring(L, (const char*)imageContainer.m_data, imageContainer.m_size);
        return 2;
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

static bimg::TextureFormat::Enum
format_from_field(lua_State *L, int idx, const char* fieldname){
    auto t = lua_getfield(L, idx, fieldname);
    if (t == LUA_TSTRING){
        const char* fmtname = lua_tostring(L, -1);
        lua_pop(L, 1);
        return bimg::getFormat(fmtname);
    }
    lua_pop(L, 1);
    return bimg::TextureFormat::Unknown;
}

static int
lencode_image(lua_State *L){
    bx::DefaultAllocator allocator;
    
    bimg::TextureInfo info;
    lua_struct::unpack(L, 1, info);
    info.format = format_from_field(L, 1, "format");
    assert(info.format != bimg::TextureFormat::Unknown);
    struct memory *m = (struct memory *)luaL_checkudata(L, 2, "BGFX_MEMORY");

    bimg::ImageContainer ic;
    ic.m_width      = info.width;
    ic.m_height     = info.height;
    ic.m_format     = info.format;
    ic.m_size       = info.storageSize;
    ic.m_numLayers  = info.numLayers;
    ic.m_numMips    = info.numMips;
    ic.m_offset     = 0;
    ic.m_depth      = info.depth;
    ic.m_cubeMap    = info.cubeMap;
    ic.m_data       = m->data;
    ic.m_allocator  = nullptr;

    luaL_checktype(L, 3, LUA_TTABLE);
    const char* image_type = nullptr;
    lua_struct::unpack_field(L, 3, "type", image_type);
    bimg::TextureFormat::Enum dst_format = format_from_field(L, 3, "format");
    
    bimg::ImageContainer *new_ic = nullptr;
    if (dst_format != bimg::TextureFormat::Unknown && dst_format != ic.m_format){
        new_ic = bimg::imageConvert(&allocator, dst_format, ic, true);
    }

    bx::Error err;
    if (strcmp(image_type, "dds") == 0){
        bx::MemoryBlock mb(&allocator);
        bx::MemoryWriter sw(&mb);

        auto t_ic = new_ic ? new_ic : &ic;

        t_ic->m_ktx = t_ic->m_ktxLE = false;
        lua_struct::unpack_field(L, 3, "srgb", t_ic->m_srgb);

        const int32_t filesize = bimg::imageWriteDds(&sw, *t_ic, t_ic->m_data, (uint32_t)m->size, &err);
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

    if (new_ic){
        bimg::imageFree(new_ic);
    }
    return 1;
}

static int
lget_bits_pre_pixel(lua_State *L){
    auto fmt = bimg::getFormat(luaL_checkstring(L, 1));
    auto bits = bimg::getBitsPerPixel(fmt);
    lua_pushinteger(L, bits);
    return 1;
}

static int
lget_format_name(lua_State *L){
    auto fmt = luaL_checkinteger(L, 1);
    lua_pushstring(L, bimg::getName(bimg::TextureFormat::Enum(fmt)));
    return 1;
}

static int32_t
to_dds_file(bx::MemoryBlock *mb, bimg::ImageContainer *ic){
    bx::MemoryWriter sw(mb);
    bx::Error err;
    return bimg::imageWriteDds(&sw, *ic, ic->m_data, (uint32_t)ic->m_size, &err);
}

static void
push_dds_file(lua_State *L, bx::AllocatorI *allocator, bimg::ImageContainer *ic){
    bx::MemoryBlock mb(allocator);
    to_dds_file(&mb, ic);
    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
}

static int
lconvert(lua_State *L){
    size_t bufsize = 0;
    auto buf = luaL_checklstring(L, 1, &bufsize);
    auto fmt = bimg::getFormat(luaL_checkstring(L, 2));

    bx::DefaultAllocator allocator;
    bimg::ImageContainer ic;
    ic.m_allocator = &allocator;
    bx::Error err;
    auto img = bimg::imageParse(&allocator, buf, (uint32_t)bufsize, fmt, &err);
    if (img){
        push_dds_file(L, &allocator, img);
        bimg::imageFree(img);
        return 1;
    }

    return luaL_error(L, "bimg::imageParse failed");
    
}

static inline int
check_mem(lua_State *L, int memidx, int fmtidx, struct memory *& m, bimg::TextureFormat::Enum &fmt){
    m = TO_MEM(L, 1);
    fmt = bimg::getFormat(luaL_checkstring(L, 2));
    const auto srcbytes = bimg::getBitsPerPixel(fmt) / 8;
    if ( m->size % srcbytes != 0){
        return luaL_error(L, "invalid format:%s, memory size:%d", bimg::getName(fmt), m->size);
    }

    return 1;
}

static int
lpng_gray2rgb(lua_State *L){
    size_t srcsize = 0;
    auto src = luaL_checklstring(L, 1, &srcsize);
    bx::DefaultAllocator allocator;
    bimg::ImageContainer ic;
    bx::Error err;
    bimg::imageParse(ic, src, (uint32_t)srcsize, &err);

    auto unpack = [](float* dst, const void* src){
        const uint8_t* _src = (const uint8_t*)src;
        dst[0] = dst[1] = dst[2] = bx::fromUnorm(_src[0], 255.0f);
        if (_src[1] != 255 && _src[1] != 0){
            int debug = 0;
        }
        dst[3] = bx::fromUnorm(_src[1], 255.0f);
    };

    auto dstimage = bimg::imageAlloc(&allocator,
        bimg::TextureFormat::RGBA8,
        ic.m_width,
        ic.m_height,
        ic.m_depth,
        ic.m_numLayers,
        ic.m_cubeMap,
        ic.m_numMips > 1, nullptr);

    const uint32_t srcbpp = bimg::getBitsPerPixel(ic.m_format);
    const uint32_t dstbpp = bimg::getBitsPerPixel(bimg::TextureFormat::RGBA8);

    bimg::imageConvert( dstimage->m_data, dstbpp, bx::packRgba8, 
                        ic.m_data, srcbpp, unpack, 
                        ic.m_width, ic.m_height, ic.m_depth,
                        ic.m_width * (srcbpp/8), ic.m_width * (dstbpp/8));
    push_dds_file(L, &allocator, dstimage);
    bimg::imageFree(dstimage);
    return 1;
}

static void
create_png_lib(lua_State *L)    {
    lua_newtable(L);
    luaL_Reg pnglib[] = {
        {"gray2rgb", lpng_gray2rgb},
        {nullptr, nullptr},
    };
    luaL_setfuncs(L, pnglib, 0);
}

extern "C" int
luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse",              lparse },
        { "convert",            lconvert},
        { "encode_image",       lencode_image},
        { "get_bits_pre_pixel", lget_bits_pre_pixel},
        { "get_format_name",    lget_format_name},
        { nullptr,              nullptr },
    };
    luaL_newlib(L, lib);
    
    create_png_lib(L);
    lua_setfield(L, -2, "png");

    return 1;
}
