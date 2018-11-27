#define LUA_LIB

#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include "window.h"


typedef enum {
	CALLBACK_ERROR = 1,
	CALLBACK_UPDATE,
	CALLBACK_EXIT,
	CALLBACK_TOUCH,
	CALLBACK_KEYBOARD,
	CALLBACK_MOUSE_MOVE,
	CALLBACK_MOUSE_WHEEL,
	CALLBACK_MOUSE_CLICK,
	CALLBACK_COUNT,
} CallBackType;


struct callback_context {
	lua_State *callback;
	lua_State *functions;
};

static int
push_callback_function(struct callback_context * context, int id) {
	lua_pushvalue(context->functions, id);
	lua_xmove(context->functions, context->callback, 1);
	int ret = lua_type(context->callback, 2) == LUA_TFUNCTION;
	if (!ret) {
		lua_pop(context->callback, 1);
	}
	return ret;
}

static void
push_update_args(lua_State *L, struct ant_window_update *update) {
}

static void
push_exit_args(lua_State *L, struct ant_window_exit *exit) {
}

static void
push_touch_args(lua_State *L, struct ant_window_touch *touch) {
	lua_pushinteger(L, touch->what);
	lua_pushinteger(L, touch->x);
	lua_pushinteger(L, touch->y);
}

static void
push_keyboard_arg(lua_State *L, struct ant_window_keyboard *keyboard) {
	lua_pushinteger(L, keyboard->key);
	lua_pushboolean(L, keyboard->press);
	lua_pushinteger(L, keyboard->state);
}

static void
push_mouse_move_args(lua_State *L, struct ant_window_mouse_move *mouse) {
	lua_pushinteger(L, mouse->x);
	lua_pushinteger(L, mouse->y);
}

static void
push_mouse_wheel_args(lua_State *L, struct ant_window_mouse_wheel *mouse) {
	lua_pushinteger(L, mouse->delta);
	lua_pushinteger(L, mouse->x);
	lua_pushinteger(L, mouse->y);
}

static void
push_mouse_click_arg(lua_State *L, struct ant_window_mouse_click *mouse) {
	lua_pushinteger(L, mouse->type);
	lua_pushboolean(L, mouse->press);
	lua_pushinteger(L, mouse->x);
	lua_pushinteger(L, mouse->y);
}

static int
lraise_error_string(lua_State *L) {
	const char * msg = (const char *)lua_touserdata(L, 2);
	if (lua_type(L, 1) != LUA_TFUNCTION) {
		// no error handle
		printf("Error: %s\n", msg);
	} else {
		lua_pop(L, 1);
		lua_pushstring(L, msg);
		lua_call(L, 1, 0);
	}
	return 0;
}

static void
raise_error_string(struct callback_context *context, const char *errmsg) {
	lua_State *L = context->callback;
	lua_pushcfunction(L, lraise_error_string);
	lua_pushvalue(context->functions, CALLBACK_ERROR);
	lua_xmove(context->functions, L, 1);
	lua_pushlightuserdata(L, (void *)errmsg);
	if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
		printf("Error in error handle : %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

static void
raise_error(struct callback_context *context) {
	lua_State *L = context->callback;
	lua_pushvalue(context->functions, CALLBACK_ERROR);
	lua_xmove(context->functions, L, 1);
	if (lua_type(L, -1) == LUA_TFUNCTION) {
		lua_insert(L, -2);	// error_handler, error_string
		if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
			printf("Error in error handle : %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	} else {
		printf("Error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 2);
	}
}

static void
callback(void *ud, struct ant_window_message *msg) {
	struct callback_context * context = (struct callback_context *)ud;
	lua_State *L = context->callback;
	switch(msg->type) {
	case ANT_WINDOW_UPDATE:
		if (push_callback_function(context, CALLBACK_UPDATE)) {
			push_update_args(L, &msg->u.update);
			break;
		} else {
//			raise_error_string(context, "No update handler");
			return;
		}
	case ANT_WINDOW_EXIT:
		if (push_callback_function(context, CALLBACK_EXIT)) {
			push_exit_args(L, &msg->u.exit);
			break;
		} else {
//			raise_error_string(context, "No exit handler");
			return;
		}
	case ANT_WINDOW_TOUCH:
		if (push_callback_function(context, CALLBACK_TOUCH)) {
			push_touch_args(L, &msg->u.touch);
			break;
		} else {
//			raise_error_string(context, "No touch handler");
			return;
		}
	case ANT_WINDOW_KEYBOARD:
		if (push_callback_function(context, CALLBACK_KEYBOARD)) {
			push_keyboard_arg(L, &msg->u.keyboard);
			break;
		} else {
			return;
		}
	case ANT_WINDOW_MOUSE_MOVE:
		if (push_callback_function(context, CALLBACK_MOUSE_MOVE)) {
			push_mouse_move_args(L, &msg->u.mouse_move);
			break;
		} else {
//			raise_error_string(context, "No move handler");
			return;
		}
	case ANT_WINDOW_MOUSE_WHEEL:
		if (push_callback_function(context, CALLBACK_MOUSE_WHEEL)) {
			push_mouse_wheel_args(L, &msg->u.mouse_wheel);
			break;
		} else {
//			raise_error_string(context, "No move handler");
			return;
		}
	case ANT_WINDOW_MOUSE_CLICK:
		if (push_callback_function(context, CALLBACK_MOUSE_CLICK)) {
			push_mouse_click_arg(L, &msg->u.mouse_click);
			break;
		} else {
			return;
		}
	default:
		raise_error_string(context, "Unknown callback");
		return;
	}
	int nargs = lua_gettop(L) - 2;
	if (lua_pcall(L, nargs, 0, 1) != LUA_OK) {
		raise_error(context);
	}
}

static void
register_function(lua_State *L, int index, const char *name, lua_State *fL, int id) {
	lua_getfield(L, index, name);
	lua_xmove(L, fL, 1);
	lua_replace(fL, id);
}

static void
register_functions(lua_State *L, int index, lua_State *fL) {
	int i;
	luaL_checkstack(fL, CALLBACK_COUNT+2, NULL);	// 2 for temp
	for (i=0;i<CALLBACK_COUNT;i++) {
		lua_pushnil(fL);
	}
	register_function(L, index, "error", fL, CALLBACK_ERROR);
	register_function(L, index, "update", fL, CALLBACK_UPDATE);
	register_function(L, index, "exit", fL, CALLBACK_EXIT);
	register_function(L, index, "touch", fL, CALLBACK_TOUCH);
	register_function(L, index, "keyboard", fL, CALLBACK_KEYBOARD);
	register_function(L, index, "mouse_move", fL, CALLBACK_MOUSE_MOVE);
	register_function(L, index, "mouse_wheel", fL, CALLBACK_MOUSE_WHEEL);
	register_function(L, index, "mouse_click", fL, CALLBACK_MOUSE_CLICK);
}

static int
ltraceback(lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL && !lua_isnoneornil(L, 1)) {
		lua_pushvalue(L, 1);
	} else {
		luaL_traceback(L, L, msg, 2);
	}
	return 1;
}

static int
lregistercallback(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);

	if (lua_getfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK) != LUA_TUSERDATA) {
		return luaL_error(L, "Create native window first");
	}
	struct ant_window_callback *cb = (struct ant_window_callback *)lua_touserdata(L, -1);
	lua_pop(L, 1);

	struct callback_context * context = lua_newuserdata(L, sizeof(*context));
	lua_createtable(L, 2, 0);	// for callback and functions thread
	context->callback = lua_newthread(L);
	lua_pushcfunction(context->callback, ltraceback);	// push traceback function
	lua_rawseti(L, -2, 1);
	context->functions = lua_newthread(L);
	lua_rawseti(L, -2, 2);
	lua_setuservalue(L, -2);	// ref 2 threads to context userdata
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_CALLBACK_CONTEXT");

	register_functions(L, 1, context->functions);

	cb->message = callback;
	cb->ud = context;

	return 0;
}

LUAMOD_API int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "register", lregistercallback },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
