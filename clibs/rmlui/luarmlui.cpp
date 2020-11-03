#include "pch.h"
#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"
#include "context.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/luabgfx.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>
#include <RmlUi/Lua.h>

#include <cassert>
#include <cstring>

struct rml_context_wrapper {
    rml_context    context;
    System         system;
    FontInterface  font;
    FileInterface2 file;
    Renderer       renderer;
    lua_State*     rL;
    bool           debugger = false;
    rml_context_wrapper(lua_State* L, int idx)
        : context(L, idx)
        , system()
        , font(&context)
        , file(&context)
        , renderer(&context)
        , rL(luaL_newstate())
    {
        if (rL) {
            luaL_openlibs(rL);
        }
    }

    ~rml_context_wrapper() {
        if (rL) {
            lua_close(rL);
        }
    }
};
rml_context_wrapper* g_wrapper;

template<typename T>
T* checkud(lua_State* L, int idx)
{
    T** ptr = static_cast<T**>(lua_touserdata(L, idx));
    if (!ptr || !*ptr) {
        luaL_argerror(L, idx, "invalid userdata");
    }
    return *ptr;
}

static int ContextProcessMouseMove(lua_State* L) {
    Rml::Context* context = checkud<Rml::Context>(L, 1);
    int x = luaL_checkinteger(L, 2);
    int y = luaL_checkinteger(L, 3);
    int state = luaL_optinteger(L, 4, 0);
    context->ProcessMouseMove(x, y, state);
    return 0;
}

static int ContextProcessMouseButtonDown(lua_State* L) {
    Rml::Context* context = checkud<Rml::Context>(L, 1);
    int button = luaL_checkinteger(L, 2);
    int state = luaL_optinteger(L, 3, 0);
    context->ProcessMouseButtonDown(button, state);
    return 0;
}

static int ContextProcessMouseButtonUp(lua_State* L) {
    Rml::Context* context = checkud<Rml::Context>(L, 1);
    int button = luaL_checkinteger(L, 2);
    int state = luaL_optinteger(L, 3, 0);
    context->ProcessMouseButtonUp(button, state);
    return 0;
}

static int ContextDebugger(lua_State* L) {
    Rml::Context* context = checkud<Rml::Context>(L, 1);
    bool open = lua_toboolean(L, 2);
    if (!g_wrapper) {
        return 0;
    }
    if (!g_wrapper->debugger) {
        Rml::Debugger::Initialise(context);
        g_wrapper->debugger = true;
    }
    else {
        Rml::Debugger::SetContext(context);
    }
    Rml::Debugger::SetVisible(open);
    return 0;
}

static int
lrmlui_init(lua_State *L){
    if (g_wrapper) {
        return luaL_error(L, "RmlUi has been initialized.");
    }
    g_wrapper = new rml_context_wrapper(L, 1);
    Rml::SetSystemInterface(&g_wrapper->system);
    Rml::SetFontEngineInterface(&g_wrapper->font);
    Rml::SetFileInterface(&g_wrapper->file);
    Rml::SetRenderInterface(&g_wrapper->renderer);
    if (!Rml::Initialise()){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
    lua_State* rL = g_wrapper->rL;
    Rml::Lua::Initialise(rL);

    if (LUA_TTABLE == lua_getglobal(rL, "Context")) {
        luaL_Reg lib[] = {
            {"ProcessMouseMove",ContextProcessMouseMove},
            {"ProcessMouseButtonDown",ContextProcessMouseButtonDown},
            {"ProcessMouseButtonUp",ContextProcessMouseButtonUp},
            {"Debugger",ContextDebugger},
            {NULL,NULL},
        };
        luaL_setfuncs(rL, lib, 0);
    }
    lua_pop(rL, 1);
    return 0;
}

static int
lrmlui_shutdown(lua_State* L) {
    Rml::Shutdown();
    if (g_wrapper) {
        delete g_wrapper;
        g_wrapper = nullptr;
    }
    return 0;
}

static bool rmlui_load_script(lua_State* L, const char* script) {
    Rml::FileInterface* file_interface = Rml::GetFileInterface();
    Rml::FileHandle handle = file_interface->Open(script);
    if (handle == 0) {
        return false;
    }
    size_t size = file_interface->Length(handle);
    if (size == 0) {
        return false;
    }
    std::string file_contents; file_contents.resize(size);
    file_interface->Read(file_contents.data(), size, handle);
    file_interface->Close(handle);
    if (!Rml::Lua::Interpreter::LoadString(file_contents, std::string("@") + script)) {
        return false;
    }
    if (!Rml::Lua::Interpreter::ExecuteCall(0, 1)) {
        return false;
    }
    return true;
}

static int
lrmlui_run_script(lua_State* L) {
    lua_State* rL = Rml::Lua::Interpreter::GetLuaState();
    const char* script = luaL_checkstring(L, 1);
    if (LUA_TTABLE != lua_getfield(rL, LUA_REGISTRYINDEX, "rmlui::run_script")) {
        lua_pop(rL, 1);
        lua_newtable(rL);
        lua_pushvalue(rL, -1);
        lua_setfield(rL, LUA_REGISTRYINDEX, "rmlui::run_script");
    }
    if (LUA_TFUNCTION != lua_getfield(rL, -1, script)) {
        lua_pop(rL, 1);
        if (!rmlui_load_script(rL, script)) {
            lua_pop(rL, 1);
            lua_pushboolean(L, 0);
            return 1;
        }
        lua_pushvalue(rL, -1);
        lua_setfield(rL, -3, script);
    }
    Rml::Lua::Interpreter::ExecuteCall(0, 0);
    lua_pop(rL, 1);
    lua_pushboolean(L, 1);
    return 1;
}

static int
lrmlui_memory(lua_State* L) {
    if (g_wrapper) {
        lua_State* rL = g_wrapper->rL;
        int k = lua_gc(rL, LUA_GCCOUNT);
        int b = lua_gc(rL, LUA_GCCOUNTB);
        lua_pushinteger(L, (lua_Integer)k * 1024 + b);
    }
    else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

extern "C" {
LUAMOD_API int
    luaopen_rmlui(lua_State* L) {
    init_interface(L);
    luaL_Reg l[] = {
        { "init",       lrmlui_init },
        { "shutdown",   lrmlui_shutdown },
        { "run_script", lrmlui_run_script },
        { "memory",     lrmlui_memory },
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}

bgfx_interface_vtbl_t* 
get_bgfx_interface(){
    return bgfx_inf_;
}