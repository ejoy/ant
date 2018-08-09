#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdarg.h>
#include <string.h>

#define luavm lua_State

static int ERRLOG = 0;
static int MSGTABLE = 0;

struct luavm *
luavm_new() {
	return luaL_newstate();
}

void
luavm_close(struct luavm * L) {
	lua_close(L);
}

static lua_State *
getthread (lua_State *L, int *arg) {
	if (lua_isthread(L, 1)) {
		*arg = 1;
		return lua_tothread(L, 1);
	}
	else {
		*arg = 0;
		return L;  /* function will operate over current thread */
	}
}

static int
db_traceback (lua_State *L) {
	int arg;
	lua_State *L1 = getthread(L, &arg);
	const char *msg = lua_tostring(L, arg + 1);
		if (msg == NULL && !lua_isnoneornil(L, arg + 1))  /* non-string 'msg'? */
		lua_pushvalue(L, arg + 1);  /* return it untouched */
	else {
		int level = (int)luaL_optinteger(L, arg + 2, (L == L1) ? 1 : 0);
		luaL_traceback(L, L1, msg, level);
	}
	return 1;
}

static int
lpusherr(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &ERRLOG) != LUA_TTABLE) {
		return 0;
	}
	int n = lua_rawlen(L, -1);
	int type = lua_type(L, 1);
	switch (type) {
	case LUA_TSTRING:
		lua_pushvalue(L, 1);
		break;
	case LUA_TLIGHTUSERDATA:
		lua_pushstring(L, (const char *)lua_touserdata(L, 1));
		break;
	default:
		lua_pushstring(L, "Invalid message object");
		lua_rawseti(L, -2, n + 1);

		// replace Message if no error
		const char * errlog = luaL_tolstring(L, 1, NULL);	// may raise error
		lua_pushstring(L, errlog);
		break;
	}
	lua_rawseti(L, -2, n + 1);
	return 0;
}

static void
pusherr_result(lua_State *L) {
	lua_pushcfunction(L, lpusherr);
	lua_insert(L, -2);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		lua_pop(L, 1);	// ignore pusherr error
	}
}

static int
call_cfunction(lua_State *L, lua_CFunction f, const char * source, const char *chunkname, void *ud, int ret) {
	lua_pushcfunction(L, db_traceback);
	lua_pushcfunction(L, f);
	lua_pushlightuserdata(L, (void *)source);
	lua_pushlightuserdata(L, (void *)chunkname);
	if (ud) {
		lua_pushlightuserdata(L, ud);
	}
	if (lua_pcall(L, (ud == NULL) ? 2 : 3, ret, 1) != LUA_OK) {
		pusherr_result(L);
		return -1;
	}
	return 0;
}

static int
lregister(lua_State *L) {
	const char * source = (const char *)lua_touserdata(L, 1);
	if (source == NULL) {
		return luaL_error(L, "Register need source");
	}
	const char * chunkname = (const char *)lua_touserdata(L, 2);
	if (luaL_loadbuffer(L, source, strlen(source), chunkname ? chunkname : source) != LUA_OK) {
		return lua_error(L);
	}
	lua_call(L, 0, 1);
	if (lua_type(L, -1) != LUA_TFUNCTION) {
		return luaL_error(L, "Register need return a function");
	}
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &MSGTABLE) != LUA_TTABLE) {
		return luaL_error(L, "Init first");
	}
	int n = lua_rawlen(L, -1) + 1;
	lua_pushvalue(L, -2);
	lua_rawseti(L, -2, n);
	lua_pop(L, 1);
	lua_pushinteger(L, n);
	return 1;
}

int
luavm_register(struct luavm * L, const char * source, const char *chunkname) {
	if (call_cfunction(L, lregister, source, chunkname, NULL, 1)) {
		// error
		return 0;
	}
	int handle = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return handle;
}

static void
pusherr(lua_State *L, const char *err) {
	lua_pushcfunction(L, lpusherr);
	lua_pushlightuserdata(L, (void *)err);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		lua_pop(L, 1);
	}
}

static int
lpushstring(lua_State *L) {
	lua_pushstring(L, (const char *)lua_touserdata(L, 1));
	return 1;
}

static int
pushcstr(lua_State *L, const char *s) {
	lua_pushcfunction(L, lpushstring);
	lua_pushlightuserdata(L, (void *)s);
	if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
		lua_pop(L, 1);
		return 1;
	}
	return 0;
}

static int
pushargs(lua_State *L, const char *format, va_list ap) {
	if (format == NULL)
		return 0;
	int i;
	for (i=0;format[i];i++) {}
	if (!lua_checkstack(L, i+1))	// +1 for pushcstr
		return 0;
	for (i=0;format[i];i++) {
		switch(format[i]) {
		case 'n':	// Number
			lua_pushnumber(L, va_arg(ap, lua_Number));
			break;
		case 'i':	// Integer
			lua_pushinteger(L, va_arg(ap, lua_Integer));
			break;
		case 's':	// cstring
			if (pushcstr(L, va_arg(ap, const char *))) {
				// oom error
				lua_pop(L, i);
				return -1;
			}
			break;
		case 'b':	// boolean
			lua_pushboolean(L, va_arg(ap, int));
			break;
		case 'f':	// cfunction
			lua_pushcfunction(L, va_arg(ap, lua_CFunction));
			break;
		case 'p':	// lightuserdata
			lua_pushlightuserdata(L, va_arg(ap, void *));
			break;
		default:
			lua_pop(L, i);
			return -1;
		}
	}
	return i;
}

/*
	void * source
	void * format
	va_list ap
 */
static int
linit(lua_State *L) {
	luaL_openlibs(L);
	lua_newtable(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &MSGTABLE);
	lua_newtable(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &ERRLOG);
	const char * source = (const char *)lua_touserdata(L, 1);
	if (source != NULL) {
		if (luaL_loadbuffer(L, source, strlen(source), "=init") != LUA_OK) {
			return lua_error(L);
		}
		lua_rawgetp(L, LUA_REGISTRYINDEX, &ERRLOG);
		const char * format = (const char *)lua_touserdata(L, 2);
		va_list ap = (va_list)lua_touserdata(L, 3);
		int nargs = pushargs(L, format, ap);
		if (nargs < 0)
			return luaL_error(L, "Invalid init arguments");
		lua_call(L, 1 + nargs, 0);
	}

	return 0;
}

int
luavm_init(struct luavm *L, const char * source, const char *format, ...) {
	va_list ap;
	va_start(ap, format);
	int ret = call_cfunction(L, linit, source, format, ap, 0);
	va_end(ap);
	return ret;
}

int
luavm_call(struct luavm *L, int handle, const char *format, ...) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &MSGTABLE) != LUA_TTABLE) {
		lua_pop(L, 1);
		pusherr(L, "Init First");
		return -1;
	}
	if (lua_rawgeti(L, -1, handle) != LUA_TFUNCTION) {
		lua_pop(L, 2);
		pusherr(L, "Invalid message function");
		return -1;
	}
	// MSGTABLE func
	lua_pushcfunction(L, db_traceback);
	lua_replace(L, -3);
	// db_traceback func

	va_list ap;
	va_start(ap, format);
	int nargs = pushargs(L, format, ap);
	va_end(ap);
	if (nargs < 0) {
		lua_pop(L, 2);
		pusherr(L, "Invalid argument");
		return -1;
	}

	if (lua_pcall(L, nargs, 0, -2-nargs) != LUA_OK) {
		pusherr_result(L);
		return -1;
	}
	return 0;
}

const char *
luavm_lasterror(struct luavm *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &ERRLOG) != LUA_TTABLE) {
		lua_pop(L, 1);
		return "Invalid error table";
	}
	int n = lua_rawlen(L, -1);
	if (n == 0) {
		return "No error";
	}
	if (lua_rawgeti(L, -1, n) != LUA_TSTRING) {
		lua_pop(L, 2);
		return "Invalid error string";
	}
	const char * errlog = lua_tostring(L, -1);
	lua_pop(L, 2);
	return errlog;
}
