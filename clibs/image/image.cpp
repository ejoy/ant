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

static inline void
push_texture_info(lua_State *L, const bimg::ImageContainer *ic){
    bimg::TextureInfo info;
    bimg::imageGetSize(&info
        , (uint16_t)ic->m_width
        , (uint16_t)ic->m_height
        , (uint16_t)ic->m_depth
        , ic->m_cubeMap
        , ic->m_numMips > 1
        , ic->m_numLayers
        , ic->m_format
        );
    
    lua_struct::pack(L, info);
}

static int
lparse(lua_State *L) {
    size_t srcsize = 0;
    auto src = luaL_checklstring(L, 1, &srcsize);
    bx::DefaultAllocator allocator;
    bool readcontent = !lua_isnoneornil(L, 2);
    auto image = bimg::imageParse(&allocator, src, (uint32_t)srcsize, bimg::TextureFormat::Enum(bimg::TextureFormat::Count), nullptr);
    if (!image){
        lua_pushstring(L, "Invalid image content");
        return lua_error(L);
    }
    push_texture_info(L, image);
    if (readcontent){
        lua_pushlstring(L, (const char*)image->m_data, image->m_size);
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
lget_bits_per_pixel(lua_State *L){
    auto fmt = bimg::getFormat(luaL_checkstring(L, 1));
    auto bits = bimg::getBitsPerPixel(fmt);
    lua_pushinteger(L, bits);
    return 1;
}

static int
lget_format_sizebytes(lua_State *L){
    auto fmt = bimg::getFormat(luaL_checkstring(L, 1));
    auto bits = bimg::getBitsPerPixel(fmt);
    lua_pushinteger(L, bits/8);
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

static bimg::ImageContainer*
gray2rgba(const bimg::ImageContainer &ic, bx::DefaultAllocator &allocator){
    auto unpack = [](float* dst, const void* src){
        const uint8_t* _src = (const uint8_t*)src;
        dst[0] = dst[1] = dst[2] = bx::fromUnorm(_src[0], 255.0f);
        if (_src[1] != 255 && _src[1] != 0){
            int debug = 0;
        }
        dst[3] = bx::fromUnorm(_src[1], 255.0f);
    };

    bimg::ImageContainer* dstimage = bimg::imageAlloc(&allocator,
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

    return dstimage;
}

static int
lpng_convert(lua_State *L){
    size_t srcsize = 0;
    auto src = luaL_checklstring(L, 1, &srcsize);
    bx::DefaultAllocator allocator;
    bimg::ImageContainer ic;
    bx::Error err;
    bimg::imageParse(ic, src, (uint32_t)srcsize, &err);

    bimg::ImageContainer *dstimage = &ic;
    if (ic.m_format == bimg::TextureFormat::RG8){
        dstimage = gray2rgba(ic, allocator);
    }

    //we need image file format from png to dds
    push_dds_file(L, &allocator, dstimage);
    push_texture_info(L, dstimage);
    bimg::imageFree(dstimage);
    return 2;
}

static int
lpng_gray2rgba(lua_State *L){
    size_t srcsize = 0;
    auto src = luaL_checklstring(L, 1, &srcsize);
    bx::DefaultAllocator allocator;
    bimg::ImageContainer ic;
    bx::Error err;
    bimg::imageParse(ic, src, (uint32_t)srcsize, &err);

    bimg::ImageContainer *dstimage = &ic;
    if (ic.m_format != bimg::TextureFormat::RG8)
        return 0;

    dstimage = gray2rgba(ic, allocator);
    push_dds_file(L, &allocator, dstimage);
    bimg::imageFree(dstimage);
    return 1;
}

static void
create_png_lib(lua_State *L){
    lua_newtable(L);
    luaL_Reg pnglib[] = {
        {"convert", lpng_convert},
        {"gray2rgba",lpng_gray2rgba},
        {nullptr, nullptr},
    };
    luaL_setfuncs(L, pnglib, 0);
}

enum class CubemapFace : uint8_t { PX, NX, PY, NY, PZ, NZ, Count};

static void
fill_cubemap_face(bimg::ImageContainer* &ic, const bimg::ImageContainer *face, CubemapFace cf, bx::DefaultAllocator &allocator){
    if (!ic){
        ic = bimg::imageAlloc(&allocator, bimg::TextureFormat::RGBA32F, face->m_width, face->m_height, 1, 1, true, false);
    }

    bimg::ImageMip cm_mip;
    bimg::imageGetRawData(*ic, (uint8_t)cf, 0, ic->m_data, ic->m_size, cm_mip);

    const uint32_t pitch = cm_mip.m_width * cm_mip.m_bpp/8;
    bimg::imageCopy((uint8_t*)cm_mip.m_data, cm_mip.m_height, pitch, cm_mip.m_depth, face->m_data, pitch);
}

static void
fill_cross_cubemap_face(bimg::ImageContainer* &ic, const bimg::ImageContainer *face, CubemapFace cf, bx::DefaultAllocator &allocator){
    if (!ic){
        assert(face->m_width == face->m_height);
        const uint32_t w = face->m_width * 4;
        const uint32_t h = face->m_height * 3;
        ic = bimg::imageAlloc(&allocator, bimg::TextureFormat::RGBA32F, w, h, 1, 1, false, false);
    }

//    --> U    _____
//   |        |     |
//   v        | +Y  |
//   V   _____|_____|_____ _____
//      |     |     |     |     |
//      | -X  | +Z  | +X  | -Z  |
//      |_____|_____|_____|_____|
//            |     |
//            | -Y  |
//            |_____|
//

    const uint32_t bytes_pp = getBitsPerPixel(ic->m_format)/8;
    uint32_t srcpitch = face->m_width * bytes_pp;
    uint32_t dstpitch = face->m_width * 4 * bytes_pp;
    uint8_t* srcdata = nullptr;
    const uint32_t facerow_offset = face->m_height * dstpitch;
    switch (cf){
        case CubemapFace::PX:{
            srcdata = (uint8_t*)ic->m_data + facerow_offset + srcpitch * 2;
        } break;
        case CubemapFace::NX:{
            srcdata = (uint8_t*)ic->m_data + facerow_offset;
        } break;
        case CubemapFace::PY:{
            srcdata = (uint8_t*)ic->m_data + srcpitch;
        } break;
        case CubemapFace::NY:{
            srcdata = (uint8_t*)ic->m_data + facerow_offset * 2 + srcpitch;
        } break;
        case CubemapFace::PZ:{
            srcdata = (uint8_t*)ic->m_data + facerow_offset + srcpitch;
        } break;
        case CubemapFace::NZ:{
            srcdata = (uint8_t*)ic->m_data + facerow_offset + srcpitch * 3;
        } break;
        default:
        assert(false);
    }

    bimg::imageCopy(srcdata, face->m_height, srcpitch, 1, face->m_data, dstpitch);
}

static int
lpack2cubemap(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
    const lua_Unsigned n = lua_rawlen(L, 1);
    if (n != 6){
        luaL_error(L, "pack 6 image to cubemap texture need 6 image:%d", n);
    }

    const bool iscross = lua_toboolean(L, 2);
    const char* outfile_fmt = lua_isnoneornil(L, 3) ? nullptr : lua_tostring(L, 3);

    if (iscross && !outfile_fmt){
        return luaL_error(L, "cross cubemap texture must specify output file format as png/hdr/exr");
    }

    bx::DefaultAllocator allocator;

    bimg::ImageContainer* ic = nullptr;
    for (int i=0; i<n; ++i){
        lua_geti(L, 1, i+1);{
            bx::Error err;
            size_t srcsize = 0;
            const char* src = lua_tolstring(L, -1, &srcsize);
            auto face = bimg::imageParse(&allocator, src, (uint32_t)srcsize, bimg::TextureFormat::RGBA32F, &err);
            if (!face){
                luaL_error(L, "parse image failed:%d", i);
            }

            if (iscross){
                fill_cross_cubemap_face(ic, face, CubemapFace(i), allocator);
            } else {
                fill_cubemap_face(ic, face, CubemapFace(i), allocator);
            }

            bimg::imageFree(face);
        }

        lua_pop(L, 1);
    }

    bx::MemoryBlock mb(&allocator);
    bx::MemoryWriter sw(&mb);
    bx::Error err;
    if (iscross){
        if (strcmp(outfile_fmt, "HDR") == 0){
            if (!bimg::imageWriteHdr(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
                return luaL_error(L, "Save to HDR file failed");
            }
        } else if (strcmp(outfile_fmt, "EXR") == 0){
            if (!bimg::imageWriteExr(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
                return luaL_error(L, "Save to EXR file failed");
            }
        } else if (strcmp(outfile_fmt, "PNG") == 0){
            if (!bimg::imageWritePng(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
                return luaL_error(L, "Save to PNG file failed");
            }
        } else {
            return luaL_error(L, "Invalid output file format:%s", outfile_fmt);
        }
    } else {
        if (!bimg::imageWriteKtx(&sw, *ic, ic->m_data, (uint32_t)ic->m_size, &err)){
            return luaL_error(L, "Write to memory as ktx failed");
        }
    }

    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
    bimg::imageFree(ic);
    return 1;
}

extern "C" int
luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse",              lparse },
        { "convert",            lconvert},
        { "encode_image",       lencode_image},
        { "get_bpp",            lget_bits_per_pixel},
        { "get_format_sizebytes",lget_format_sizebytes},
        { "get_format_name",    lget_format_name},
        { "pack2cubemap",       lpack2cubemap},
        { nullptr,              nullptr },
    };
    luaL_newlib(L, lib);
    
    create_png_lib(L);
    lua_setfield(L, -2, "png");

    return 1;
}
