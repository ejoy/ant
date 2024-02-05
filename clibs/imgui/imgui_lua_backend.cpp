#include <lua.hpp>
#include <imgui.h>
#include <cstdint>
#include <bx/platform.h>
#include "backend/imgui_impl_bgfx.h"
#include "backend/imgui_impl_platform.h"
#include "../luabind/lua2struct.h"

namespace imgui_lua_backend {

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
    ImGui_ImplPlatform_Init(window);
    return 0;
}

static int PlatformDestroy(lua_State* L) {
    ImGui_ImplPlatform_Shutdown();
    return 0;
}

static int PlatformNewFrame(lua_State* L) {
    ImGui_ImplPlatform_NewFrame();
    return 0;
}

static int RenderInit(lua_State* L) {
    auto initargs = lua_struct::unpack<RendererInitArgs>(L, 1);
    if (!ImGui_ImplBgfx_Init(initargs)) {
        return luaL_error(L, "Create renderer failed");
    }
    return 0;
}

static int RenderDestroy(lua_State* L) {
    ImGui_ImplBgfx_Shutdown();
    return 0;
}

static int RenderCreateFontsTexture(lua_State *L) {
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
