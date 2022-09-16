#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <string.h>

struct bundle_record {
	const char *key;
	void *value;
};

struct bundle {
	int n;
	struct bundle_record r[1];
};

static int
comp_str(const void *aa, const void *bb) {
	const struct bundle_record * a = (const struct bundle_record *)aa;
	const struct bundle_record * b = (const struct bundle_record *)bb;
	return strcmp(a->key, b->key);
}

static struct bundle_record *
find_key(struct bundle *b, const char *key) {
	int begin = 0;
	int end = b->n;
	while (begin < end) {
		int mid = (begin + end) / 2;
		int c = strcmp(b->r[mid].key, key);
		if (c == 0)
			return &b->r[mid];
		else if (c < 0) {
			begin = mid + 1;
		} else {
			end = mid;
		}
	}
	return NULL;
}

static int
setvalue(lua_State *L) {
	struct bundle * b = luaL_checkudata(L, 1, "BUNDLE_META");
	const char * key = luaL_checkstring(L, 2);
	struct bundle_record *r = find_key(b, key);
	if (r == NULL)
		return luaL_error(L, "Invalid key = %s", key);
	if (r->value != NULL) {
		return luaL_error(L, "key %s exist", key);
	}
	switch (lua_type(L, 3)) {
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA:
		r->value = lua_touserdata(L, 3);
		break;
	case LUA_TSTRING:
		r->value = (void *)lua_tostring(L, 3);
		break;
	default:
		return luaL_error(L, "Invalid value type = %s", lua_typename(L, lua_type(L, 3)));
	}
	return 0;
}

static int
getvalue(lua_State *L) {
	struct bundle * b = lua_touserdata(L, 1);
	if (b == NULL)
		return luaL_error(L, "Need bundle userdata");
	const char *key = luaL_checkstring(L, 2);
	struct bundle_record *r = find_key(b, key);
	if (r == NULL)
		return luaL_error(L, "Invalid key = %s", key);
	if (r->value == NULL)
		return 0;
	lua_pushlightuserdata(L, r->value);
	return 1;
}

static int
lcreate_bundle(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = lua_rawlen(L, 1);
	size_t sz = sizeof(struct bundle) + sizeof(struct bundle_record) * (n-1);
	struct bundle *b = (struct bundle *)lua_newuserdatauv(L, sz, n);
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TSTRING) {
			return luaL_error(L, "[%d] is not a string", i+1);
		}
		b->r[i].key = lua_tostring(L, -1);
		b->r[i].value = NULL;
		lua_setiuservalue(L, -2, i+1);
	}
	qsort(b->r, n, sizeof(struct bundle_record), comp_str);
	if (luaL_newmetatable(L, "BUNDLE_META")) {
		luaL_Reg l[] = {
			{ "__newindex", setvalue },
			{ "__index", getvalue },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);
	lua_pushlightuserdata(L, b);
	b->n = n;
	return 2;
}

static int
getvalue_from_view(lua_State *L) {
	struct bundle ** view = (struct bundle **)lua_touserdata(L, 1);
	int i;
	const char * key = luaL_checkstring(L, 2);
	for (i=0;view[i];i++) {
		struct bundle_record * b = find_key(view[i], key);
		if (b) {
			if (b->value == NULL)
				return 0;
			lua_pushlightuserdata(L, b->value);
			return 1;
		}
	}
	return luaL_error(L, "Can't find %s in bundle view", key);
}

static int
lcreate_view(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = lua_rawlen(L, 1);
	struct bundle ** view = (struct bundle **)lua_newuserdatauv(L, (n+1) * sizeof(struct bundle *), 0);
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TLIGHTUSERDATA)
			return luaL_error(L, "[%d] is not a lightuserdata", i+1);
		view[i] = (struct bundle *)lua_touserdata(L, -1);
		if (view[i] == NULL) {
			return luaL_error(L, "[%d] is NULL", i+1);
		}
		lua_pop(L, 1);
	}
	view[n] = NULL;
	if (luaL_newmetatable(L, "BUNDLE_VIEW_META")) {
		luaL_Reg l[] = {
			{ "__index", getvalue_from_view },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lexist(lua_State *L) {
	struct bundle ** view = luaL_checkudata(L, 1, "BUNDLE_VIEW_META");
	int i;
	const char * key = luaL_checkstring(L, 2);
	for (i=0;view[i];i++) {
		struct bundle_record * b = find_key(view[i], key);
		if (b) {
			lua_pushboolean(L, 1);
			return 1;
		}
	}
	return 0;
}


static int
ltostr(lua_State *L) {
	switch (lua_type(L, 1)) {
	case LUA_TLIGHTUSERDATA:
		lua_pushstring(L, (const char*)lua_touserdata(L, 1));
		return 1;
	}
	return 0;
}

LUAMOD_API int
luaopen_bundle(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_bundle", lcreate_bundle },
		{ "create_view", lcreate_view },
		{ "exist", lexist },
		{ "tostr", ltostr },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}