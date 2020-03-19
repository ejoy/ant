#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

static int
lvector(lua_State *L) {
	int top = lua_gettop(L);
	int i,j;
	luaL_checkstack(L, top * 4+1, NULL);
	lua_pushstring(L, "VEC");
	for (i=1;i<=top;i++) {
		const float * vec4 = lua_touserdata(L, i);
		for (j=0;j<4;j++) {
			lua_pushnumber(L, vec4[j]);
		}
	}
	return 4 * top + 1;
}

static int
lmatrix1(lua_State *L) {
	int i;
	const float * mat = lua_touserdata(L, 1);
	lua_pushstring(L, "MAT");
	for (i=0;i<16;i++) {
		lua_pushnumber(L, mat[i]);
	}
	return 17;
}

static int
lmatrix2(lua_State *L) {
	int i;
	const float * mat1 = lua_touserdata(L, 1);
	const float * mat2 = lua_touserdata(L, 2);
	for (i=0;i<16;i++) {
		lua_pushnumber(L, mat1[i] - mat2[i]);
	}
	return 16;
}

static int
lformat(lua_State *L) {
	const char * format = lua_tostring(L, 1);
	lua_pushlightuserdata(L, (void *)format);
	return 1;
}

static int
lvariant(lua_State *L) {
	size_t sz;
	const char * format = lua_tolstring(L, 1, &sz);
	int top = lua_gettop(L);
	if (sz+1 != top) {
		return luaL_error(L, "%s need %d arguments", format, (int)sz);
	}
	luaL_checkstack(L, (int)sz, NULL);
	int i;
	for (i=2;i<=top;i++) {
		const float * v = (const float *)lua_touserdata(L, i);
		switch(format[i-2]) {
		case 'm':
			lua_pushnumber(L, v[15]);
			break;
		case 'v':
			lua_pushnumber(L, v[0]);
			break;
		case 'q':
			lua_pushnumber(L, v[3]);
			break;
		default:
			return luaL_error(L, "Invalid format %s", format);
		}
	}

	return (int)sz;
}

static int
lgetmvq(lua_State *L) {
	float * mat = lua_touserdata(L, 1);
	float * vec = lua_touserdata(L, 2);
	float * quat = lua_touserdata(L, 3);
	int i;
	for (i=0;i<16;i++) {
		mat[i] = (float)i;
	}
	for (i=0;i<4;i++) {
		vec[i] = (float)i;
	}
	for (i=0;i<4;i++) {
		quat[i] = 1.0f;
	}
	return 0;
}

static int
lretvector(lua_State *L) {
	static const float v1[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
	static const float v2[4] = { 5.0f, 6.0f, 7.0f, 8.0f };
	lua_pushlightuserdata(L, (void *)v1);
	lua_pushlightuserdata(L, (void *)v2);
	return 2;
}

LUAMOD_API int
luaopen_math3d_adapter_test(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "vector", lvector },
		{ "matrix1", lmatrix1 },
		{ "matrix2", lmatrix2 },
		{ "format", lformat },
		{ "variant", lvariant },
		{ "getmvq", lgetmvq },
		{ "retvec", lretvector },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
