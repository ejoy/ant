extern "C" {
#include "../window.h"
}
#include "include/android_native_app_glue.h"
#include <lua.hpp>
#include <bee/nonstd/to_underlying.h>
#include <android/log.h>

static struct android_app* g_app;

enum class AndroidPath {
    InternalDataPath,
    ExternalDataPath,
};

int window_init(struct ant_window_callback* cb) {
    return 0;
}

int window_create(struct ant_window_callback* cb, int w, int h) {
    return 0;
}

void window_mainloop(struct ant_window_callback* cb, int update) {
}

extern "C" void window_set_android_app(struct android_app* app) {
    g_app = app;
}

static int ldirectory(lua_State* L) {
    auto type = (AndroidPath)luaL_checkinteger(L, 1);
    switch (type) {
    case AndroidPath::InternalDataPath:
        lua_pushstring(L, g_app->activity->internalDataPath);
        return 1;
    case AndroidPath::ExternalDataPath:
        lua_pushstring(L, g_app->activity->externalDataPath);
        return 1;
    default:
        return luaL_error(L, "unknown directory type");
    }
}

static int lrawlog(lua_State* L) {
    static const char* const opts[] = { "unknown", "default", "verbose", "debug", "info", "warn", "error", "fatal", "silent", NULL };
    android_LogPriority prio = (android_LogPriority)luaL_checkoption(L, 1, NULL, opts);
    const char* tag = luaL_checkstring(L, 2);
    const char* text = luaL_checkstring(L, 3);
    __android_log_write(1, tag, text);
    return 0;
}

extern "C"
int luaopen_android(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "directory", ldirectory },
        { "rawlog", lrawlog },
        { NULL, NULL },
    };
    luaL_newlibtable(L, l);
    luaL_setfuncs(L, l, 0);
#define ENUM(name) \
    lua_pushinteger(L, std::to_underlying(AndroidPath::name)); \
    lua_setfield(L, -2, #name)
    ENUM(InternalDataPath);
    ENUM(ExternalDataPath);
#undef ENUM
    return 1;
}
