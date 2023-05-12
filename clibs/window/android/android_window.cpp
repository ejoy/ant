extern "C" {
#include "../window.h"
}
#include "include/game-activity/native_app_glue/android_native_app_glue.h"
#include <lua.hpp>
#include <bee/nonstd/to_underlying.h>
#include <android/log.h>
#include <cassert>
#include "runtime.h"

static struct android_app* g_app = NULL;
static struct ant_window_callback* g_cb = NULL;
static ANativeWindow* g_window = NULL;
static bool g_initialized = false;

static void push_message(struct ant_window_message* msg) {
    if (g_cb) {
        g_cb->message(g_cb->ud, msg);
    }
}

enum class AndroidPath {
    InternalDataPath,
    ExternalDataPath,
};

int window_init(struct ant_window_callback* cb) {
    g_cb = cb;
    return 0;
}

int window_create(struct ant_window_callback* cb, int w, int h) {
    return 0;
}

void window_mainloop(struct ant_window_callback* cb, int update) {
    int events;
    android_poll_source* source;
    struct ant_window_message update_msg;
    update_msg.type = ANT_WINDOW_UPDATE;
    do {
        if (ALooper_pollAll(g_window ? 0 : -1, nullptr, &events, (void **) &source) >= 0) {
            if (source) {
                source->process(g_app, source);
            }
        }
        if (g_initialized) {
            cb->message(cb->ud, &update_msg);
        }
    } while (!g_app->destroyRequested);
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
            g_initialized = true;
            int32_t w = ANativeWindow_getWidth(app->window);
            int32_t h = ANativeWindow_getHeight(app->window);
            struct ant_window_message msg;
            msg.type = g_initialized? ANT_WINDOW_INIT: ANT_WINDOW_RECREATE;
            msg.u.init.window = app->window;
            msg.u.init.context = NULL;
            msg.u.init.w = w;
            msg.u.init.h = h;
            push_message(&msg);
            break;
        }
        case APP_CMD_TERM_WINDOW:
            g_window = NULL;
            break;
        case APP_CMD_DESTROY: {
            struct ant_window_message msg;
            msg.type = ANT_WINDOW_EXIT;
            push_message(&msg);
            break;
        }
        case APP_CMD_WINDOW_RESIZED: {
            int32_t w = ANativeWindow_getWidth(app->window);
            int32_t h = ANativeWindow_getHeight(app->window);
            struct ant_window_message msg;
            msg.type = ANT_WINDOW_SIZE;
            msg.u.size.x = w;
            msg.u.size.y = h;
            msg.u.size.type = 0;
            push_message(&msg);
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

static void errfunc(const char* msg) {
    __android_log_write(ANDROID_LOG_FATAL, "",  msg);
}

static bool motion_event_filter_func(const GameActivityMotionEvent *motionEvent) {
    auto sourceClass = motionEvent->source & AINPUT_SOURCE_CLASS_MASK;
    return (sourceClass == AINPUT_SOURCE_CLASS_POINTER || sourceClass == AINPUT_SOURCE_CLASS_JOYSTICK);
}

extern "C" void android_main(struct android_app* app) {
    g_app = app;
    app->onAppCmd = handle_cmd;

    android_app_set_motion_event_filter(app, motion_event_filter_func);
    int argc = 0;
    char* argv[] = {
    };
    runtime_main(argc, argv, errfunc);
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
