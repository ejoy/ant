#include <lua.hpp>
#include <cstring>
#include "bimg/decode.h"
#include "bx/allocator.h"
#include "bx/error.h"

bx::DefaultAllocator s_imgallocator;

struct image {
    bimg::ImageContainer *ic;
};

static inline image*
get_image(lua_State *L, int idx=1){
    return (image*)luaL_checkudata(L, idx, "IMAGE_CONTAINER");
}

static int
limg_del(lua_State *L){
    auto img = get_image(L);
    BX_ALIGNED_FREE(&s_imgallocator, img->ic, 16);
    return 1;
}

static int
limg_size(lua_State *L){
    auto ic = get_image(L)->ic;
    lua_pushnumber(L, ic->m_width);
    lua_pushnumber(L, ic->m_height);
    return 2;
}

static int
limg_data(lua_State *L){
    auto ic = get_image(L)->ic;
    lua_pushlightuserdata(L, ic->m_data);
    lua_pushinteger(L, ic->m_size);
    return 2;
}

static inline bimg::TextureFormat::Enum
get_fmt(const char *s){
    if (strcmp(s, "rgba8") == 0){
        return bimg::TextureFormat::Enum::RGBA8;
    }

    if (strcmp(s, "rgb8") == 0){
        return bimg::TextureFormat::Enum::RGB8;
    }

    if (strcmp(s, "r32f") == 0){
        return bimg::TextureFormat::Enum::R32F;
    }

    return bimg::TextureFormat::Enum::Unknown;
}

static int
lparse(lua_State *L){
    size_t len;
    const char * c = lua_tolstring(L, 1, &len);
    const char* s = luaL_checkstring(L, 2);
    auto fmt = get_fmt(s);
    if (fmt == bimg::TextureFormat::Enum::Unknown){
        luaL_error(L, "fmt not support: %s", s);
    }
    bx::Error err;
    image* i = (image*)lua_newuserdatauv(L, sizeof(image), 0);
    i->ic = bimg::imageParse(&s_imgallocator, c, (uint32_t)len, fmt, &err);

    if (luaL_newmetatable(L, "IMAGE_CONTAINER")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"size", limg_size},
            {"data", limg_data},
            {"__gc", limg_del},
            {nullptr, nullptr},
        };
		luaL_setfuncs(L, l, 0);
    }

    lua_setmetatable(L, -2);
    return 1;
}

extern "C"
#if BX_PLATFORM_WINDOWS
__declspec(dllexport)
#endif
int luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse", lparse},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}