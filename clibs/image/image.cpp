#define LUA_LIB 1
#include <lua.hpp>
#include <string.h>
#include <assert.h>
#include <bimg/bimg.h>
#include <bx/allocator.h>
#include <bx/error.h>
#include "bgfx_interface.h"
#include "luabgfx.h"

#include <map>
#include <string_view>
static std::map<bgfx_texture_format_t, std::string_view> c_texture_formats;

static void
init_texture_formats(lua_State* L) {
    if (LUA_TTABLE != lua_getfield(L, LUA_REGISTRYINDEX, "BGFX_TF")) {
        luaL_error(L, "bgfx binding is not initialized.");
        return;
    }
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        size_t sz = 0;
        const char* s = luaL_checklstring(L, -2, &sz);
        c_texture_formats.insert(std::make_pair(
            bgfx_texture_format_t(luaL_checkinteger(L, -1)),
            std::string_view {s,sz}
        ));
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
}

static void
push_texture_formats(lua_State* L, bgfx_texture_format_t format) {
    auto it = c_texture_formats.find(format);
    if (it == c_texture_formats.end()) {
        luaL_error(L, "Invalid texture format %d", format);
    }
    lua_pushstring(L, it->second.data());
}

static int
lparse(lua_State *L){
    struct memory *mem = (struct memory *)luaL_checkudata(L, 1, "BGFX_MEMORY");
    bx::Error err;
    bimg::ImageContainer imageContainer;
    if (!bimg::imageParse(imageContainer, mem->data, mem->size, &err)) {
        assert(!err.isOk());
        auto errmsg = err.getMessage();
        lua_pushlstring(L, errmsg.getPtr(), errmsg.getLength());
        return lua_error(L);
    }
    bgfx_texture_info_t info;
    BGFX(calc_texture_size)(&info
        , (uint16_t)imageContainer.m_width
        , (uint16_t)imageContainer.m_height
        , (uint16_t)imageContainer.m_depth
        , imageContainer.m_cubeMap
        , imageContainer.m_numMips > 1
        , imageContainer.m_numLayers
        , bgfx_texture_format_t(imageContainer.m_format)
        );
    lua_newtable(L);
    push_texture_formats(L, info.format);
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
    init_texture_formats(L);
    luaL_Reg lib[] = {
        { "parse", lparse },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
