#include <lua.hpp>

#include "bimg/decode.h"
#include "bx/allocator.h"

static int
lparse(lua_State *L){
    bx::DefaultAllocator da;
    size_t len;
    const char * c = lua_tolstring(L, 1, &len);
    auto img = bimg::imageParse(&da, c, (uint32_t)len);

    lua_newtable(L);
    lua_pushinteger(L, img->m_format);
    lua_setfield(L, -2, "format");

    lua_pushinteger(L, img->m_size);
    lua_setfield(L, -2, "size");

    lua_pushinteger(L, img->m_offset);
    lua_setfield(L, -2, "offset");

    lua_pushinteger(L, img->m_width);
    lua_setfield(L, -2, "width");

    lua_pushinteger(L, img->m_height);
    lua_setfield(L, -2, "height");

    lua_pushinteger(L, img->m_depth);
    lua_setfield(L, -2, "depth");

    lua_pushinteger(L, img->m_numLayers);
    lua_setfield(L, -2, "num_layers");

    lua_pushinteger(L, img->m_numMips);
    lua_setfield(L, -2, "num_mips");

    lua_pushlstring(L, (const char*)img->m_data, img->m_size);
    lua_setfield(L, -2, "data");

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