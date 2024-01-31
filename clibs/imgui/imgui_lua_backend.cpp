#include <lua.hpp>
#include <imgui.h>
#include <cstdint>
#include <bx/platform.h>
#include "backend/imgui_impl_bgfx.h"
#include "imgui_platform.h"
#include "fastio.h"

namespace imgui_lua_backend {

static int read_field_checkint(lua_State *L, const char * field, int tidx) {
    int v;
    if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
        if (!lua_isinteger(L, -1)) {
            luaL_error(L, "Not an integer");
        }
        v = (int)lua_tointeger(L, -1);
    } else {
        v = 0;
        luaL_error(L, "no int %s", field);
    }
    lua_pop(L, 1);
    return v;
}

static float read_field_checkfloat(lua_State *L, const char * field, int tidx) {
    float v;
    if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
        v = (float)lua_tonumber(L, -1);
    } else {
        v = 0;
        luaL_error(L, "no float %s", field);
    }
    lua_pop(L, 1);
    return v;
}

static const char* read_field_string(lua_State *L, const char * field, const char *v, int tidx) {
    if (lua_getfield(L, tidx, field) == LUA_TSTRING) {
        v = lua_tostring(L, -1);
    }
    lua_pop(L, 1);
    return v;
}

#if BX_PLATFORM_WINDOWS
#define bx_malloc_size _msize
#elif BX_PLATFORM_LINUX || BX_PLATFORM_ANDROID
#include <malloc.h>
#define bx_malloc_size malloc_usable_size
#elif BX_PLATFORM_OSX
#include <malloc/malloc.h>
#define bx_malloc_size malloc_size
#elif BX_PLATFORM_IOS
#include <malloc/malloc.h>
#define bx_malloc_size malloc_size
#else
#    error "Unknown PLATFORM!"
#endif

static int64_t allocator_memory = 0;

static void* ImGuiAlloc(size_t sz, void* /*user_data*/) {
    void* ptr = malloc(sz);
    if (ptr) {
        allocator_memory += bx_malloc_size(ptr);
    }
    return ptr;
}

static void ImGuiFree(void* ptr, void* /*user_data*/) {
    if (ptr) {
        allocator_memory -= bx_malloc_size(ptr);
    }
    free(ptr);
}

static int Memory(lua_State* L) {
    lua_pushinteger(L, allocator_memory);
    return 1;
}

static int Init(lua_State* L) {
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL;
    io.UserData = L;
    return 0;
}

static int PlatformInit(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    void* window = lua_touserdata(L, 1);
    platformInit(window);
    return 0;
}

static int PlatformDestroy(lua_State* L) {
    platformShutdown();
    return 0;
}

static int PlatformNewFrame(lua_State* L) {
    platformNewFrame();
    return 0;
}

static int RenderInit(lua_State* L) {
    RendererInitArgs initargs;
    initargs.fontProg = read_field_checkint(L, "fontProg", 1);
    initargs.imageProg = read_field_checkint(L, "imageProg", 1);
    initargs.fontUniform = read_field_checkint(L, "fontUniform", 1);
    initargs.imageUniform = read_field_checkint(L, "imageUniform", 1);
    
    if (lua_getfield(L, 1, "viewIdPool") == LUA_TTABLE) {
        lua_Integer n = luaL_len(L, -1);
        initargs.viewIdPool.reserve((size_t)n);
        for (lua_Integer i = 1; i <= n; ++i) {
            if (LUA_TNUMBER == lua_geti(L, -1, i)) {
                initargs.viewIdPool.push_back((int)luaL_checkinteger(L, -1));
            }
            lua_pop(L, 1);
        }
    }
    else {
        luaL_error(L, "no table viewIdPool");
    }
    lua_pop(L, 1);

    if (!ImGui_ImplBgfx_Init(initargs)) {
        return luaL_error(L, "Create renderer failed");
    }
    return 0;
}

static int RenderDestroy(lua_State* L) {
    ImGui_ImplBgfx_Shutdown();
    return 0;
}

static const ImWchar* GetGlyphRanges(ImFontAtlas* atlas, const char* type) {
    if (!type) {
        return nullptr;
    }
    if (strcmp(type, "Default") == 0) {
        return atlas->GetGlyphRangesDefault();
    }
    if (strcmp(type, "Korean") == 0) {
        return atlas->GetGlyphRangesKorean();
    }
    if (strcmp(type, "Japanese") == 0) {
        return atlas->GetGlyphRangesJapanese();
    }
    if (strcmp(type, "ChineseFull") == 0) {
        return atlas->GetGlyphRangesChineseFull();
    }
    if (strcmp(type, "ChineseSimplifiedCommon") == 0) {
        return atlas->GetGlyphRangesChineseSimplifiedCommon();
    }
    if (strcmp(type, "Cyrillic") == 0) {
        return atlas->GetGlyphRangesCyrillic();
    }
    if (strcmp(type, "Thai") == 0) {
        return atlas->GetGlyphRangesThai();
    }
    if (strcmp(type, "Vietnamese") == 0) {
        return atlas->GetGlyphRangesVietnamese();
    }
    return (const ImWchar*)type;
}

static int RenderCreateFontsTexture(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    ImFontAtlas* atlas = ImGui::GetIO().Fonts;
    atlas->Clear();

    lua_Integer n = luaL_len(L, 1);
    for (lua_Integer i = 1; i <= n; ++i) {
        lua_rawgeti(L, 1, i);
        luaL_checktype(L, -1, LUA_TTABLE);
        int idx = lua_absindex(L, -1);
        lua_getfield(L, idx, "FontData");
        auto ttf = getmemory(L, lua_absindex(L, -1));
        ImFontConfig config;
        config.MergeMode = (i != 1);
        config.FontData = (void*)ttf.data();
        config.FontDataSize = (int)ttf.size();
        config.FontDataOwnedByAtlas = false;
        config.SizePixels = read_field_checkfloat(L, "SizePixels", idx);
        config.GlyphRanges = GetGlyphRanges(atlas, read_field_string(L, "GlyphRanges", nullptr, idx));
        atlas->AddFont(&config);
        lua_pop(L, 2);
    }
    if (!atlas->Build()) {
        luaL_error(L, "Create font failed.");
        return 0;
    }
    ImGui_ImplBgfx_CreateFontsTexture();
    return 0;
}

static int RenderDrawData(lua_State* L) {
    ImGui_ImplBgfx_RenderDrawData(ImGui::GetMainViewport());
    return 0;
}

static int init(lua_State* L) {
    ImGui::SetAllocatorFunctions(&ImGuiAlloc, &ImGuiFree, NULL);
    static luaL_Reg funcs[] = {
        { "Memory", Memory },
        { "Init", Init },
        { "PlatformInit", PlatformInit },
        { "PlatformDestroy", PlatformDestroy },
        { "PlatformNewFrame", PlatformNewFrame },
        { "RenderInit", RenderInit },
        { "RenderDestroy", RenderDestroy },
        { "RenderCreateFontsTexture", RenderCreateFontsTexture },
        { "RenderDrawData", RenderDrawData },
        { NULL, NULL },
    };
    luaL_newlib(L, funcs);
    return 1;
}
}

extern "C"
int luaopen_imgui_backend(lua_State* L) {
    return imgui_lua_backend::init(L);
}
