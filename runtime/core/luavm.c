#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdarg.h>
#include <string.h>

#define ERRLOG 1
#define MSGTABLE 2
#define RETOP 2

static int DATAL = 0;

struct luavm {
	lua_State *L;
	lua_State *dL;
};

static int
lnewvm(lua_State *L) {
	struct luavm * V = lua_newuserdata(L, sizeof(struct luavm));
	lua_pushvalue(L, -1);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DATAL);

	V->L = L;
	V->dL = lua_newthread(L);
	lua_setuservalue(L, -2);

	lua_newtable(V->dL);	// ERRLOG (1)
	lua_newtable(V->dL);	// MSGTABLE (2)

	return 1;
}

struct luavm *
luavm_new() {
	lua_State *L = luaL_newstate();
	lua_pushcfunction(L, lnewvm);
	if (lua_pcall(L, 0, 1, 0) != LUA_OK) {
		// oom
		lua_close(L);
		return NULL;
	}
	struct luavm *V = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return V;
}

void
luavm_close(struct luavm * V) {
	if (V) {
		lua_close(V->L);
	}
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

static const char *
pusherr(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DATAL) != LUA_TUSERDATA) {
		lua_pop(L, 1);
		return "Broken VM";
	}
	struct luavm *V = (struct luavm *)lua_touserdata(L, -1);
	lua_pop(L, 1);

	lua_State *dL = V->dL;
	lua_settop(dL, RETOP);
	lua_xmove(L, dL, 1);	// save return string

	if (lua_type(dL, -1) != LUA_TSTRING) {
		return "Not a string error object";
	}
	lua_pushvalue(dL, -1);
	int n = lua_rawlen(dL, ERRLOG);
	lua_rawseti(dL, ERRLOG, n + 1);
	return lua_tostring(dL, -1);
}

static const char *
call_cfunction(lua_State *L, lua_CFunction f, const char * source, const char *chunkname, void *ud, int ret) {
	lua_pushcfunction(L, db_traceback);
	lua_pushcfunction(L, f);
	lua_pushlightuserdata(L, (void *)source);
	lua_pushlightuserdata(L, (void *)chunkname);
	if (ud) {
		lua_pushlightuserdata(L, ud);
	}
	if (lua_pcall(L, (ud == NULL) ? 2 : 3, ret, 1) != LUA_OK) {
		lua_replace(L, -2);
		return pusherr(L);
	}
	// remove db_traceback
	lua_remove(L, - ret - 1);
	return NULL;
}

static int
lregister(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DATAL) != LUA_TUSERDATA) {
		return luaL_error(L, "Broken VM");
	}
	struct luavm *V = lua_touserdata(L, -1);
	lua_pop(L, 1);

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
	lua_pushvalue(V->dL, MSGTABLE);
	lua_xmove(V->dL, L, 1);
	int n = lua_rawlen(L, -1) + 1;
	lua_pushvalue(L, -2);
	lua_rawseti(L, -2, n);
	lua_pop(L, 1);
	lua_pushinteger(L, n);
	return 1;
}

const char *
luavm_register(struct luavm * V, const char * source, const char *chunkname, int *handle) {
	const char * err = call_cfunction(V->L, lregister, source, chunkname, NULL, 1);
	if (err)
		return err;
	*handle = lua_tointeger(V->L, -1);
	lua_pop(V->L, 1);
	return NULL;
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
pushargs(lua_State *L, const char *format, va_list ap, lua_State *dL, int *ret) {
	if (format == NULL)
		return 0;
	int i;
	for (i=0;format[i];i++) {}
	if (!lua_checkstack(L, i+1)) {	// +1 for pushcstr
		return -1;
	}
	if (ret) {
		*ret = 0;
		lua_settop(dL, RETOP);
		if (!lua_checkstack(dL, RETOP + i + 1)) {
			return -1;
		}
	}
	if (i == 0)
		return 0;
	int n = 0;
	for (i=0;format[i];i++) {
		switch(format[i]) {
		case 'n':	// Number
			++n;
			lua_pushnumber(L, va_arg(ap, double));
			break;
		case 'i':	// Integer
			++n;
			lua_pushinteger(L, va_arg(ap, int));
			break;
		case 's':	// cstring
			if (pushcstr(L, va_arg(ap, const char *))) {
				// oom error
				lua_pop(L, n);
				return -1;
			}
			++n;
			break;
		case 'b':	// boolean
			++n;
			lua_pushboolean(L, va_arg(ap, int));
			break;
		case 'f':	// cfunction
			++n;
			lua_pushcfunction(L, va_arg(ap, lua_CFunction));
			break;
		case 'p':	// lightuserdata
			++n;
			lua_pushlightuserdata(L, va_arg(ap, void *));
			break;
		case 'N':	// return Number
		case 'I':	// return Integer
		case 'S':	// return String
		case 'B':	// return Boolean
			if (ret == NULL) {
				lua_pop(L, i);
				return -1;
			}
			lua_pushlightuserdata(dL, va_arg(ap, void *));
			++*ret;
			break;
		default:
			lua_pop(L, n);
			return -1;
		}
	}
	return n;
}

/*
	void * source
	void * format
	va_list ap
 */
static int
linit(lua_State *L) {
	luaL_openlibs(L);
	const char * source = (const char *)lua_touserdata(L, 1);
	if (source != NULL) {
		if (luaL_loadbuffer(L, source, strlen(source), "=init") != LUA_OK) {
			return lua_error(L);
		}
		if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DATAL) != LUA_TUSERDATA) {
			return luaL_error(L, "Broken VM");
		}
		struct luavm *V = lua_touserdata(L, -1);
		lua_pop(L, 1);
		lua_pushvalue(V->dL, ERRLOG);
		lua_xmove(V->dL, L, 1);
		const char * format = (const char *)lua_touserdata(L, 2);
		va_list ap = (va_list)lua_touserdata(L, 3);
		int nargs = pushargs(L, format, ap, NULL, NULL);	// no return values
		if (nargs < 0)
			return luaL_error(L, "Invalid init arguments");
		lua_call(L, 1 + nargs, 0);
	}

	return 0;
}

const char *
luavm_init(struct luavm *V, const char * source, const char *format, ...) {
	va_list ap;
	va_start(ap, format);
	const char * err = call_cfunction(V->L, linit, source, format, ap, 0);
	va_end(ap);
	return err;
}

#include <stdlib.h>

const char *
luavm_call(struct luavm *V, int handle, const char *format, ...) {
	lua_State *L = V->L;
	lua_State *dL = V->dL;
	lua_settop(dL, RETOP);
	if (lua_rawgeti(dL, MSGTABLE, handle) != LUA_TFUNCTION) {
		lua_pop(dL, 1);
		return "Invalid message function";
	}
	lua_pushcfunction(L, db_traceback);
	lua_xmove(dL, L, 1);
	// db_traceback func

	va_list ap;
	va_start(ap, format);
	int nret = 0;
	int nargs = pushargs(L, format, ap, dL, &nret);
	if (nargs < 0) {
		lua_pop(L, 2);
		printf("format = [%s] nargs = %d %d\n", format, handle, nargs);
		return "Invalid argument";
	}

	if (lua_pcall(L, nargs, nret, -2-nargs) != LUA_OK) {
		lua_replace(L, -2);	// remove db_traceback
		return pusherr(L);
	} else if (nret > 0) {
		int i;
		int ri = 0;
		void * result;
		for (i=0;format[i];i++) {
			switch(format[i]) {
			case 'I':
				// return integer
				result = lua_touserdata(dL, ++ri + RETOP);
				*(int *)result = lua_tointeger(L, -nret+ri-1);
				break;
			case 'N':
				// return number
				result = lua_touserdata(dL, ++ri + RETOP);
				*(double *)result = lua_tonumber(L, -nret+ri-1);
				break;
			case 'B':
				// return boolean
				result = lua_touserdata(dL, ++ri + RETOP);
				*(int *)result = lua_toboolean(L, -nret+ri-1);
				break;
			case 'S':
				// return string
				result = lua_touserdata(dL, ++ri + RETOP);
				lua_pushvalue(L, -nret+ri-1);	// copy string ret
				*(const char **)result = lua_tostring(L, -1);
				lua_xmove(L, dL, 1);
				lua_replace(dL, RETOP + ri);	// save to dL
				break;
			}
		}
	}
	lua_pop(L, 1);	// remove db_traceback
	return NULL;
}
