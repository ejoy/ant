#include <lua.hpp>
#include <assert.h>
#include <cstring>
#include <bimg/bimg.h>
#include <bx/error.h>
#include <bx/readerwriter.h>
#include <bx/pixelformat.h>
#include <bimg/decode.h>

#include <glm/glm.hpp>
#include <glm/ext/scalar_constants.hpp>
#include <glm/gtx/compatibility.hpp>

#include "luabgfx.h"

#include <vector>

#include "lua2struct.h"
#include "fastio.h"

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

class AlignedAllocator : public bx::AllocatorI
{
public:
	AlignedAllocator(bx::AllocatorI* _allocator, size_t _minAlignment)
		: m_allocator(_allocator)
		, m_minAlignment(_minAlignment)
	{
	}

	virtual void* realloc(
			void* _ptr
		, size_t _size
		, size_t _align
		, const char* _file
		, uint32_t _line
		)
	{
		return m_allocator->realloc(_ptr, _size, bx::max(_align, m_minAlignment), _file, _line);
	}

	bx::AllocatorI* m_allocator;
	size_t m_minAlignment;
};

struct encode_dds_info {
    bool srgb;
};

LUA2STRUCT(encode_dds_info, srgb);

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

static bimg::ImageContainer* create_nomip_image(bx::AllocatorI &allocator, const bimg::ImageContainer *image){
    auto nomip_image = bimg::imageAlloc(&allocator, image->m_format, image->m_width, image->m_height, image->m_depth, image->m_numLayers, image->m_cubeMap, false, nullptr);
    for (uint32_t ilayer = 0; ilayer < image->m_numLayers; ++ilayer){
        auto copy_mip = [](const auto& image_src, uint32_t side, auto &dst_image){
            bimg::ImageMip srcmip;
            bimg::imageGetRawData(image_src, side, 0, image_src.m_data, image_src.m_size, srcmip);

            bimg::ImageMip dstmip;
            bimg::imageGetRawData(dst_image, side, 0, dst_image.m_data, dst_image.m_size, dstmip);

            const uint32_t pitch = srcmip.m_width * srcmip.m_bpp / 8;
            bimg::imageCopy((void*)dstmip.m_data, srcmip.m_height, pitch, srcmip.m_depth, srcmip.m_data, pitch);
        };
        if (image->m_cubeMap){
            for (uint32_t iside=0; iside<6; ++iside){
                copy_mip(*image, iside, *nomip_image);
            }
        } else {
            copy_mip(*image, 0, *nomip_image);
        }
    }
    return nomip_image;
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

static void replace_debug_mipmap_image(const bimg::ImageContainer *srt_image, const bimg::ImageContainer *dst_image, uint32_t src_lod, uint32_t dst_lod){
    for (uint32_t ilayer = 0; ilayer < dst_image->m_numLayers; ++ilayer){
        auto copy_mip = [](const auto& image_src, uint32_t side, uint32_t src_lod, uint32_t dst_lod, const auto &dst_image){
            bimg::ImageMip srcmip;
            bimg::imageGetRawData(image_src, side, src_lod, image_src.m_data, image_src.m_size, srcmip);

            bimg::ImageMip dstmip;
            bimg::imageGetRawData(dst_image, side, dst_lod, dst_image.m_data, dst_image.m_size, dstmip);

            const uint32_t pitch = dstmip.m_width * dstmip.m_bpp / 8;
            bimg::imageCopy((void*)dstmip.m_data, dstmip.m_height, pitch, dstmip.m_depth, srcmip.m_data, pitch);
        };
        copy_mip(*srt_image, ilayer, src_lod, dst_lod, *dst_image);
    }
}

static int
lreplace_debug_mipmap(lua_State *L) {
    auto src_memory = getmemory(L, 1);
    auto dst_memory = getmemory(L, 2);
    auto src_lod    = luaL_checkinteger(L, 3);
    auto dst_lod    = luaL_checkinteger(L, 4);
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    auto dst_image = bimg::imageParse(&allocator, (const void*)dst_memory.data(), (uint32_t)dst_memory.size(), bimg::TextureFormat::Count, nullptr);
    auto srt_image = bimg::imageParse(&allocator, (const void*)src_memory.data(), (uint32_t)src_memory.size(), bimg::TextureFormat::Count, nullptr);
    if (!srt_image){
        lua_pushstring(L, "Invalid src image content");
        return lua_error(L);
    }
    if (!dst_image){
        lua_pushstring(L, "Invalid dst image content");
        return lua_error(L);
    }
    replace_debug_mipmap_image(srt_image, dst_image, (uint32_t)src_lod, (uint32_t)dst_lod);
    push_dds_file(L, &allocator, dst_image);
    bimg::imageFree(srt_image);
    bimg::imageFree(dst_image);
    return 1;
}

static int
lparse(lua_State *L) {
    auto memory = getmemory(L, 1);
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);

    bool readcontent = !lua_isnoneornil(L, 2);
    auto texfmt = bimg::TextureFormat::Count;
    if(!lua_isnoneornil(L, 3)){
        texfmt = bimg::getFormat(lua_tostring(L, 3));
        if (texfmt == bimg::TextureFormat::Unknown){
            return luaL_error(L, "Unkown texture format: %s", texfmt);
        }
    }

    const bool nomip = !lua_isnoneornil(L, 4);
    
    auto image = bimg::imageParse(&allocator, (const void*)memory.data(), (uint32_t)memory.size(), texfmt, nullptr);
    if (!image){
        lua_pushstring(L, "Invalid image content");
        return lua_error(L);
    }

    if (nomip){
        auto nomip_image = create_nomip_image(allocator, image);
        bimg::imageFree(image);
        image = nomip_image;
    }

    push_texture_info(L, image);
    if (readcontent){
        lua_pushlstring(L, (const char*)image->m_data, image->m_size);
    }

    bimg::imageFree(image);
    return readcontent ? 2 : 1;
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
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    
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
        bx::MemoryBlock mb(&allocator);
        bx::MemoryWriter sw(&mb);

        auto t_ic = new_ic ? new_ic : &ic;
        if (!bimg::imageWritePng(&sw, t_ic->m_width, t_ic->m_height, t_ic->m_width * getBitsPerPixel(t_ic->m_format)/8, t_ic->m_data, t_ic->m_format, false, &err)){
            return luaL_error(L, "Save to PNG file failed");
        }
        lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
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


static int
lconvert(lua_State *L){
    size_t bufsize = 0;
    auto buf = luaL_checklstring(L, 1, &bufsize);
    auto fmt = bimg::getFormat(luaL_checkstring(L, 2));

    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
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

static bimg::ImageContainer*
gray2rgba(const bimg::ImageContainer &ic, AlignedAllocator &allocator){
    auto unpack = [](float* dst, const void* src){
        const uint8_t* _src = (const uint8_t*)src;
        dst[0] = dst[1] = dst[2] = bx::fromUnorm(_src[0], 255.0f);
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
    auto memory = getmemory(L, 1);
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    bimg::ImageContainer ic;
    bx::Error err;
    bimg::imageParse(ic, (const void*)memory.data(), (uint32_t)memory.size(), &err);

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
    auto memory = getmemory(L, 1);
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    bimg::ImageContainer ic;
    bx::Error err;
    bimg::imageParse(ic, (const void*)memory.data(), (uint32_t)memory.size(), &err);

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
fill_cubemap_face(bimg::ImageContainer* &ic, const bimg::ImageContainer *face, CubemapFace cf, AlignedAllocator &allocator){
    if (!ic){
        ic = bimg::imageAlloc(&allocator, bimg::TextureFormat::RGBA32F, face->m_width, face->m_height, 1, 1, false, false);
    }

    bimg::ImageMip cm_mip;
    bimg::imageGetRawData(*ic, (uint8_t)cf, 0, ic->m_data, ic->m_size, cm_mip);

    const uint32_t pitch = cm_mip.m_width * cm_mip.m_bpp/8;
    bimg::imageCopy((uint8_t*)cm_mip.m_data, cm_mip.m_height, pitch, cm_mip.m_depth, face->m_data, pitch);
}

static void
fill_cross_cubemap_face(bimg::ImageContainer* &ic, const bimg::ImageContainer *face, CubemapFace cf, AlignedAllocator &allocator){
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
write2memory(lua_State *L, bx::MemoryBlock &mb, bimg::ImageContainer *ic, const char* fmt){
    bx::MemoryWriter sw(&mb);
    bx::Error err;
    if (strcmp(fmt, "HDR") == 0){
        if (!bimg::imageWriteHdr(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
            return luaL_error(L, "Save to HDR file failed");
        }
    } else if (strcmp(fmt, "EXR") == 0){
        if (!bimg::imageWriteExr(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
            return luaL_error(L, "Save to EXR file failed");
        }
    } else if (strcmp(fmt, "PNG") == 0){
        if (!bimg::imageWritePng(&sw, ic->m_width, ic->m_height, ic->m_width * getBitsPerPixel(ic->m_format)/8, ic->m_data, ic->m_format, false, &err)){
            return luaL_error(L, "Save to PNG file failed");
        }
    } else if (strcmp(fmt, "KTX") == 0) {
        if (!bimg::imageWriteKtx(&sw, *ic, ic->m_data, (uint32_t)ic->m_size, &err)){
            return luaL_error(L, "Write to memory as ktx failed");
        }
    } else if (strcmp(fmt, "DDS") == 0) {
        if (!bimg::imageWriteDds(&sw, *ic, ic->m_data, (uint32_t)ic->m_size, &err)){
            return luaL_error(L, "Write to memory as dds failed");
        }
    } else {
        return luaL_error(L, "Invalid output file format:%s", fmt);
    }
    return 1;
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

    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    bimg::ImageContainer* ic = nullptr;
    for (int i=0; i<n; ++i){
        lua_geti(L, 1, i+1);{
            bx::Error err;
            auto memory = getmemory(L, -1);
            auto face = bimg::imageParse(&allocator, (const void*)memory.data(), (uint32_t)memory.size(), bimg::TextureFormat::RGBA32F, &err);
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
    write2memory(L, mb, ic, iscross ? "KTX" : outfile_fmt);

    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
    bimg::imageFree(ic);
    return 1;
}

static inline glm::vec2
hammersley(uint32_t i, float iN) {
    constexpr float tof = 0.5f / 0x80000000U;
    uint32_t bits = i;
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return{ i * iN, bits * tof};
}

struct face_address
{
    uint8_t face;
    float u, v;
};

static float inline n2s(float v){return v*2.f - 1.f;}
static float inline s2n(float v){return (v+1.f)*0.5f;}

static inline face_address
dir2uvface(const glm::vec3 &dir){
    const float x = dir.x, y = dir.y, z = dir.z;
    const float ax = glm::abs(x), ay = glm::abs(y), az = glm::abs(z);
    if (ax > ay){
        if (ax > az){
            return (x > 0) ? face_address{0, s2n(-z/ax), s2n(y/ax)}     // +X
                           : face_address{1, s2n(z/ax), s2n(y/ax)};     // -X
        }
    } else {
        if (ay > az){
            return (y > 0) ? face_address{2, s2n(x/ay), s2n(z/ay)}      // +Y
                           : face_address{3, s2n(x/ay), s2n(-z/ay)};    // -Y
        }
    }

    return z > 0 ? face_address{4, s2n(x/az), s2n(y/az)}                // +Z
                 : face_address{5, s2n(x/az), s2n(-y/az)};              // -Z
}


static inline glm::vec3
uvface2dir(int face, float u, float v){
    u = n2s(u), v = n2s(v);
    switch (face){
        case 0: return glm::vec3( 1.0, v,-u); break;
        case 1: return glm::vec3(-1.0, v, u); break;
        case 2: return glm::vec3( u, 1.0,-v); break;
        case 3: return glm::vec3( u,-1.0, v); break;
        case 4: return glm::vec3( u, v, 1.0); break;
        case 5: 
        default: return glm::vec3(-u, v,-1.0); break;
    }
}

static inline glm::vec3
filter_at(const bimg::ImageContainer &cm, const glm::vec3 &direction){
    auto addr = dir2uvface(direction);
    bimg::ImageMip cm_mip;
    if (!bimg::imageGetRawData(cm, (uint8_t)addr.face, 0, cm.m_data, cm.m_size, cm_mip))
        return glm::vec3(0.f);

    const float maxwidth = (float)cm.m_width-1, maxheight = (float)cm.m_height-1;
    const glm::vec2 xy(std::min(addr.u * maxwidth,  maxwidth),
                 std::min(addr.v * maxheight, maxheight));

    const glm::uvec2 uxy = glm::floor(xy);

    auto read_texel = [&cm_mip](uint32_t x, uint32_t y){
        return *((glm::vec4*)cm_mip.m_data + cm_mip.m_width * y + x);
    };

    const uint32_t x0 = uxy.x, y0 = uxy.y;
    const uint32_t x1 = uxy.x+1, y1 = uxy.y+1;

    const auto texel_x0y0 = read_texel(x0, y0);
    const auto texel_x1y0 = read_texel(x1, y0);
    const auto texel_x0y1 = read_texel(x0, y1);
    const auto texel_x1y1 = read_texel(x1, y1);

    const glm::vec2 st = glm::fract(xy);

    return glm::vec3(
            glm::lerp(
                glm::lerp(texel_x0y0, texel_x1y0, st.s), 
                glm::lerp(texel_x0y1, texel_x1y1, st.s), 
                st.t));
}

template<class ImageType>
static inline void
write_at(ImageType &face, size_t iw, size_t ih, const glm::vec3 &v){
    auto d = (glm::vec4*)face.m_data;
    d[face.m_width * ih + iw] = glm::vec4(v, 0.f);
}

static int
lcubemap2equirectangular(lua_State *L){
    constexpr float pi = glm::pi<float>();

    size_t cmsize;
    const char* cmdata = luaL_checklstring(L, 1, &cmsize);
    const char* fmt = luaL_checkstring(L, 2);
    bx::DefaultAllocator allocator;
    bx::Error err;
    auto cm = bimg::imageParse(&allocator, cmdata, (uint32_t)cmsize, bimg::TextureFormat::RGBA32F, &err);
    if (cm == nullptr){
        return luaL_error(L, "Invalid cubemap texture");
    }

    const uint16_t w = (uint16_t)luaL_optinteger(L, 3, cm->m_width*2);
    const uint16_t h = (uint16_t)luaL_optinteger(L, 4, cm->m_height);

    auto equirectangular = bimg::imageAlloc(&allocator, bimg::TextureFormat::RGBA32F, w, h, 1, 1, false, false);

    for (size_t ih = 0; ih < h; ++ih){
        for (size_t iw = 0; iw < w; ++iw) {
            glm::vec3 c(0.0);
            // float x = 2.0f * (iw) / w - 1.0f;
            // float y = 1.0f - 2.0f * (ih) / h;
            // float theta = x * pi;
            // float phi = y * pi * 0.5f;
            // glm::vec3 s = {
            //         std::cos(phi) * std::sin(theta),
            //         std::sin(phi),
            //         std::cos(phi) * std::cos(theta) };
            // c += filter_at(*cm, s);
            // write_at(*equirectangular, iw, ih, c);

            const size_t numSamples = 64; // TODO: how to chose numsamples
            for (size_t sample = 0; sample < numSamples; sample++) {
                const glm::vec2 u = hammersley(uint32_t(sample), 1.0f / numSamples);
                float x = 2.0f * (iw + u.x) / w - 1.0f;
                float y = 1.0f - 2.0f * (ih + u.y) / h;
                float theta = x * pi;
                float phi = y * pi * 0.5f;
                glm::vec3 s = {
                        std::cos(phi) * std::sin(theta),
                        std::sin(phi),
                        std::cos(phi) * std::cos(theta) };
                c += filter_at(*cm, s);
            }
            write_at(*equirectangular, iw, ih, c * (1.0f / numSamples));
        }
    }

    bx::MemoryBlock mb(&allocator);
    write2memory(L, mb, equirectangular, fmt);
    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
    bimg::imageFree(equirectangular);
    return 1;
}

static int
lequirectangular2cubemap(lua_State *L) {
    size_t esize;
    const char* edata = luaL_checklstring(L, 1, &esize);
    bx::DefaultAllocator allocator;
    bx::Error err;
    auto equirectangular = bimg::imageParse(&allocator, edata, (uint32_t)esize, bimg::TextureFormat::RGBA32F, &err);
    if (equirectangular == nullptr){
        return luaL_error(L, "Invalid cubemap texture");
    }

    const size_t width = equirectangular->m_width;
    const size_t height = equirectangular->m_height;

    if (height * 2 != width){
        return luaL_error(L, "Invalid equirectangular map, width:%d = 2 * height:%d", width, height);
    }

    const uint16_t facesize = (uint16_t)luaL_optinteger(L, 2, height);

    auto load_at = [](const auto equirectangular, size_t x, size_t y){
        const glm::vec4 *d = (const glm::vec4*)(equirectangular->m_data);
        return d[y*equirectangular->m_width+x];
    };

    // const float pi = glm::pi<float>();
    // const float pioverone = 1.f / pi;

    // auto toRectilinear = [=](glm::vec3 s){
    //     float xf = std::atan2(s.x, s.z) * pioverone;   // range [-1.0, 1.0]
    //     float yf = std::asin(s.y) * (2 * pioverone);   // range [-1.0, 1.0]
    //     xf = (xf + 1.0f) * 0.5f * (width  - 1);        // range [0, width [
    //     yf = (1.0f - yf) * 0.5f * (height - 1);        // range [0, height[
    //     return glm::vec2(xf, yf);
    // };

    auto cm = bimg::imageAlloc(&allocator, bimg::TextureFormat::RGBA32F, facesize, facesize, 1, 1, true, false);

    auto dir2spherecoord = [](const glm::vec3 &v)
    {
        const float pi = glm::pi<float>();
        return glm::vec2(
            0.5f + 0.5f * atan2(v.z, v.x) / pi,
            acos(v.y) / pi);
    };

    const float invsize = 1.f / facesize;

    auto remap_index = [=](float v){ return ((v+0.5f) * invsize);};

    for (uint8_t face=0; face < 6; ++face){
        bimg::ImageMip cmface;
        bimg::imageGetRawData(*cm, (uint8_t)face, 0, cm->m_data, cm->m_size, cmface);
        for (uint16_t y=0; y<facesize; ++y){
            for (uint16_t x=0 ; x<facesize ; ++x) {
                const glm::vec3 dir = glm::normalize(uvface2dir(face, remap_index(x), remap_index(y)));
                const glm::vec2 suv = dir2spherecoord(dir);
                const glm::uvec2 uv = glm::uvec2(suv * glm::vec2(width, height));
                auto c = load_at(equirectangular, uv.x, uv.y);
                /////////////////////////////////////////////////////////////////////////////////////////////
                // calculate how many samples we need based on dx, dy in the source
                // x = cos(phi) sin(theta)
                // y = sin(phi)
                // z = cos(phi) cos(theta)

                // here we try to figure out how many samples we need, by evaluating the surface
                // (in pixels) in the equirectangular -- we take the bounding box of the
                // projection of the cubemap texel's corners.

                // auto pos0 = toRectilinear(glm::normalize(uvface2dir(face, remap_index(x + 0.0f), remap_index(y + 0.0f)))); // make sure to use the float version
                // auto pos1 = toRectilinear(glm::normalize(uvface2dir(face, remap_index(x + 1.0f), remap_index(y + 0.0f)))); // make sure to use the float version
                // auto pos2 = toRectilinear(glm::normalize(uvface2dir(face, remap_index(x + 0.0f), remap_index(y + 1.0f)))); // make sure to use the float version
                // auto pos3 = toRectilinear(glm::normalize(uvface2dir(face, remap_index(x + 1.0f), remap_index(y + 1.0f)))); // make sure to use the float version
                // const float minx = std::min(pos0.x, std::min(pos1.x, std::min(pos2.x, pos3.x)));
                // const float maxx = std::max(pos0.x, std::max(pos1.x, std::max(pos2.x, pos3.x)));
                // const float miny = std::min(pos0.y, std::min(pos1.y, std::min(pos2.y, pos3.y)));
                // const float maxy = std::max(pos0.y, std::max(pos1.y, std::max(pos2.y, pos3.y)));
                // const float dx = std::max(1.0f, maxx - minx);
                // const float dy = std::max(1.0f, maxy - miny);
                // const size_t numSamples = size_t(dx * dy);

                // const float iNumSamples = 1.0f / numSamples;
                // glm::vec3 c(0.f);
                // for (size_t sample = 0; sample < numSamples; sample++) {
                //     // Generate numSamples in our destination pixels and map them to input pixels
                //     const glm::vec2 h = hammersley(uint32_t(sample), iNumSamples);
                //     const glm::vec3 s(glm::normalize(uvface2dir(face, remap_index(x + h.x), remap_index(y + h.y))));
                //     auto pos = toRectilinear(s);

                //     // we can't use filterAt() here because it reads past the width/height
                //     // which is okay for cubmaps but not for square images

                //     // TODO: the sample should be weighed by the area it covers in the cubemap texel

                //     c += glm::vec3(load_at(equirectangular, (uint32_t)pos.x, (uint32_t)pos.y));
                // }
                // c *= iNumSamples;
                
                write_at(cmface, x, y, glm::vec3(c));
            }
        }
    }

    bx::MemoryBlock mb(&allocator);
    write2memory(L, mb, cm, "KTX");
    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
    bimg::imageFree(cm);
    return 1;
}

static int
lcvt2file(lua_State *L){
    auto memory = getmemory(L, 1);
    const char* src_datafmt = luaL_optstring(L, 2, "RGBA8");
    const char* fmt = luaL_optstring(L, 3, "PNG");
    bx::DefaultAllocator defaultAllocator;

    bx::Error err;

    auto ic = bimg::imageParse(&defaultAllocator, memory.data(), (uint32_t)memory.size(), bimg::getFormat(src_datafmt), &err);
    if (!ic){
        luaL_error(L, "Parse image file failed:%s", err.getMessage().getPtr());
    }
    bx::MemoryBlock mb(&defaultAllocator);
    if (0 == write2memory(L, mb, ic, fmt)){
        luaL_error(L, "Save file content to memory failed");
    }
    bimg::imageFree(ic);
    lua_pushlstring(L, (const char*)mb.more(), mb.getSize());
    return 1;
}

uint32_t cvt2rgbe(bx::WriterI* _writer, uint32_t _width, uint32_t _height, uint32_t _depth, uint32_t _srcPitch, const void* _src, bimg::TextureFormat::Enum _format, bx::Error* _err){
    uint32_t filesize = 0;
    bimg::UnpackFn unpack = bimg::getUnpack(_format);
	const uint32_t bpp  = bimg::getBitsPerPixel(_format);
	const uint8_t* data = (const uint8_t*)_src;
    for (uint32_t zz = 0; zz < _depth; ++zz)
    {
        for (uint32_t yy = 0; yy < _height; ++yy)
        {
            for (uint32_t xx = 0; xx < _width; ++xx)
            {
                float rgba[4];
                unpack(rgba, &data[xx*bpp/8]);
                const float maxVal = bx::max(rgba[0], rgba[1], rgba[2]);
                const float exp    = bx::ceil(bx::log2(maxVal) );
                const float toRgb8 = 255.0f * 1.0f/bx::ldexp(1.0f, int(exp) );
                uint8_t rgbe[4];
                rgbe[0] = uint8_t(rgba[0] * toRgb8);
                rgbe[1] = uint8_t(rgba[1] * toRgb8);
                rgbe[2] = uint8_t(rgba[2] * toRgb8);
                rgbe[3] = uint8_t(exp+128.0f);
                filesize += bx::write(_writer, rgbe, 4, _err);
            }
            data += _srcPitch;
        }
    }
    return filesize;
}

uint32_t cvt2rgb10A2(bx::WriterI* _writer, uint32_t _width, uint32_t _height, uint32_t _depth, uint32_t _srcPitch, const void* _src, bimg::TextureFormat::Enum _format, bx::Error* _err){
    uint32_t filesize = 0;
    bimg::UnpackFn unpack = bimg::getUnpack(_format);
    bimg::PackFn pack = bimg::getPack(bimg::getFormat("RGB10A2"));
	const uint32_t bpp  = bimg::getBitsPerPixel(_format);
	const uint8_t* data = (const uint8_t*)_src;
    for (uint32_t zz = 0; zz < _depth; ++zz)
    {
        for (uint32_t yy = 0; yy < _height; ++yy)
        {
            for (uint32_t xx = 0; xx < _width; ++xx)
            {
                float rgba[4];
                uint32_t rgb10a2;
                unpack(rgba, &data[xx*bpp/8]);
                pack(&rgb10a2, rgba);
                filesize += bx::write(_writer, &rgb10a2, 4, _err);
            }
            data += _srcPitch;
        }
    }
    return filesize;
}

static int
lcvt2hdr(lua_State *L){
    bx::DefaultAllocator defaultAllocator;
    AlignedAllocator allocator(&defaultAllocator, 16);
    uint32_t dim = luaL_checkinteger(L, 1);
    struct memory *m = (struct memory *)luaL_checkudata(L, 2, "BGFX_MEMORY");
    const char* src_fmt = luaL_optstring(L, 3, "RGBA32F");
    const char* dst_fmt = luaL_optstring(L, 4, "RGB10A2");
    bimg::ImageContainer ic;
    ic.m_width      = dim;
    ic.m_height     = dim;
    ic.m_format     = bimg::getFormat(src_fmt);
    ic.m_size       = getBitsPerPixel(ic.m_format) / 8 * dim * dim;
    ic.m_numLayers  = 1;
    ic.m_numMips    = 1;
    ic.m_offset     = 0;
    ic.m_depth      = dim;
    ic.m_cubeMap    = false;
    ic.m_data       = m->data;
    ic.m_allocator  = nullptr;
    bx::MemoryBlock mb(&allocator);
    bx::MemoryWriter sw(&mb);
    bx::Error err;
    uint32_t filesize = 0;
    uint32_t pitch = ic.m_width * getBitsPerPixel(ic.m_format)/8;
    if (strcmp(dst_fmt, "RGBE") == 0){
        filesize = cvt2rgbe(&sw, ic.m_width, ic.m_height, ic.m_depth, pitch, ic.m_data, ic.m_format, &err);
        lua_pushlstring(L, (const char*)mb.more(), filesize);
    }
    else if (strcmp(dst_fmt, "RGB10A2") == 0){
        filesize = cvt2rgb10A2(&sw, ic.m_width, ic.m_height, ic.m_depth, pitch, ic.m_data, ic.m_format, &err);
        lua_pushlstring(L, (const char*)mb.more(), filesize);
    }
    return 1;
}

extern "C" int
luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse",              lparse },
        { "convert",            lconvert},
        { "encode_image",       lencode_image},
        { "cvt2file",           lcvt2file},
        { "get_bpp",            lget_bits_per_pixel},
        { "get_format_sizebytes",lget_format_sizebytes},
        { "get_format_name",    lget_format_name},
        { "pack2cubemap",       lpack2cubemap},
        { "cubemap2equirectangular", lcubemap2equirectangular},
        { "equirectangular2cubemap", lequirectangular2cubemap},
        { "replace_debug_mipmap",    lreplace_debug_mipmap},
        { "cvt2hdr",            lcvt2hdr},
        { nullptr,              nullptr },
    };
    luaL_newlib(L, lib);
    
    create_png_lib(L);
    lua_setfield(L, -2, "png");

    return 1;
}
