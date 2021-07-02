#define LUA_LIB 1
#include <lua.hpp>
#include <assert.h>
#include <bimg/bimg.h>
#include <bx/error.h>
#include "luabgfx.h"

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
    lua_newtable(L);
    lua_pushstring(L,  bimg::getName(info.format));
    lua_setfield(L, -2, "format");
    lua_pushinteger(L, info.storageSize);
    lua_setfield(L, -2, "storageSize");
    lua_pushinteger(L, info.width);
    lua_setfield(L, -2, "width");
    lua_pushinteger(L, info.height);
    lua_setfield(L, -2, "height");
    lua_pushinteger(L, info.depth);
    lua_setfield(L, -2, "depth");
    lua_pushinteger(L, info.numLayers);
    lua_setfield(L, -2, "numLayers");
    lua_pushinteger(L, info.numMips);
    lua_setfield(L, -2, "numMips");
    lua_pushinteger(L, info.bitsPerPixel);
    lua_setfield(L, -2, "bitsPerpixel");
    lua_pushboolean(L, info.cubeMap);
    lua_setfield(L, -2, "cubeMap");
    return 1;
}

extern "C" LUAMOD_API int
luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse", lparse },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
