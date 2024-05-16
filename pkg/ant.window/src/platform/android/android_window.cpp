#include "../../window.h"
#include "include/game-activity/native_app_glue/android_native_app_glue.h"
#include <lua.hpp>
#include <bee/nonstd/to_underlying.h>
#include <android/log.h>
#include <cassert>
#include "runtime.h"

lua_State* g_L = NULL;

static struct android_app* g_app = NULL;
static ANativeWindow* g_window = NULL;
static bool g_initialized = false;

enum class AndroidPath {
    InternalDataPath,
    ExternalDataPath,
};

bool window_init(lua_State* L, const char *size) {
    (void)size;
    g_L = L;
    return true;
}

void window_close() {
}

bool window_peek_message() {
    for (;;) {
        if (g_app->destroyRequested) {
            return false;
        }
        int events;
        android_poll_source* source;
        if (ALooper_pollAll(g_window ? 0 : -1, nullptr, &events, (void **) &source) >= 0) {
            if (source) {
                source->process(g_app, source);
            }
        }
        return true;
    }
}

void ant::window::set_message(ant::window::set_msg& msg) {
}

static void handle_cmd(android_app* app, int32_t cmd) {
    switch (cmd) {
        case APP_CMD_START:
        case APP_CMD_INIT_WINDOW: {
            if (g_window == app->window) {
                break;
            }
            if (app->window == NULL) {
                g_window = NULL;
                return;
            }
            g_window = app->window;
            int32_t w = ANativeWindow_getWidth(app->window);
            int32_t h = ANativeWindow_getHeight(app->window);
            if (!g_initialized) {
                window_message_init(g_L, app->window, app->window, NULL, NULL, w, h);
                g_initialized = true;
            }
            else {
                window_message_recreate(g_L, app->window,  app->window, NULL, NULL, w, h);
            }
            break;
        }
        case APP_CMD_TERM_WINDOW:
            g_window = NULL;
            break;
        case APP_CMD_DESTROY: {
            window_message_exit(g_L);
            break;
        }
        case APP_CMD_WINDOW_RESIZED: {
            int32_t w = ANativeWindow_getWidth(app->window);
            int32_t h = ANativeWindow_getHeight(app->window);
            window_message_size(g_L, w, h);
            break;
        }
        case APP_CMD_LOST_FOCUS:
        case APP_CMD_PAUSE:
        case APP_CMD_GAINED_FOCUS:
        case APP_CMD_RESUME:
            break;
        case APP_CMD_WINDOW_REDRAW_NEEDED:
        case APP_CMD_CONTENT_RECT_CHANGED:
        case APP_CMD_CONFIG_CHANGED:
        case APP_CMD_LOW_MEMORY:
        case APP_CMD_SAVE_STATE:
        case APP_CMD_STOP:
        case APP_CMD_WINDOW_INSETS_CHANGED:
            break;
    }
}

extern "C" void android_main(struct android_app* app) {
    g_app = app;
    app->onAppCmd = handle_cmd;

    android_app_set_motion_event_filter(app, +[](GameActivityMotionEvent const*) {
        return false;
    });
    android_app_set_key_event_filter(app, +[](GameActivityKeyEvent const*) {
        return false;
    });

    int argc = 0;
    char* argv[] = {
    };
    runtime_main(argc, argv, +[](const char* msg) {
        __android_log_write(ANDROID_LOG_FATAL, "",  msg);
    });
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
    __android_log_write(prio, tag, text);
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
