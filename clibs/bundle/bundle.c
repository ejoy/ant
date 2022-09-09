#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

struct view_record {
	const char *key;
	void *value;
};

struct bundle_view {
	int n;
	struct view_record r[1];
};

struct bundle_box {
	struct bundle_view *view;
};

static int
comp_str(const void *aa, const void *bb) {
	const struct view_record * a = (const struct view_record *)aa;
	const struct view_record * b = (const struct view_record *)bb;
	return strcmp(a->key, b->key);
}

static int
count_table(lua_State *L, int index) {
	lua_pushnil(L);
	int n = 0;
	while (lua_next(L, index) != 0) {
		++n;
		lua_pop(L, 1);
	}
	return n;
}

static int
lcreate_bundle_view(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = luaL_optinteger(L, 2, 0);
	if (n <= 0) {
		n = count_table(L, 1);
	}
	struct bundle_view * b = (struct bundle_view *)lua_newuserdatauv(L, sizeof(*b) + sizeof(b->r[0]) * (n-1), 0);	
	b->n = n;
	lua_pushnil(L);
	while (lua_next(L, 1) != 0) {
		--n;
		if (n < 0) {
			luaL_error(L, "Invalid table size");
		}
		void * v = NULL;
		if (lua_isuserdata(L, -1)) {
			v = lua_touserdata(L, -1);
		}
		b->r[n].key = lua_tostring(L, -2);
		b->r[n].value = v;
		lua_pop(L, 1);
	}
	if (n != 0) {
		luaL_error(L, "Invalid table size");
	}
	qsort(b->r, n, sizeof(b->r[0]), comp_str);
	lua_pushlightuserdata(L, b);
	return 2;
}

static struct view_record *
index_view(lua_State *L, struct bundle_view *view, const char *key) {
	if (view == NULL)
		luaL_error(L, "Invalid bundle view");
	int begin = 0;
	int end = view->n;
	while (begin < end) {
		int mid = (begin + end) / 2;
		int c = strcmp(key, view->r[mid].key);
		if (c == 0)
			return &view->r[mid];
		else if (c < 0) {
			end = mid;
		} else {
			begin = mid + 1;
		}
	}
	return NULL;
}

static int
lget_view(lua_State *L) {
	struct bundle_box * box = (struct bundle_box *)lua_touserdata(L, 1);
	const char * key = luaL_checkstring(L, 2);
	struct view_record * r = index_view(L, box->view, key);
	if (r == NULL)
		return luaL_error(L, "%s not found", key);
	if (r->value == NULL)
		return 0;
	lua_pushlightuserdata(L, r->value);
	return 1;
}

static int
lset_view(lua_State *L) {
	struct bundle_box * box = (struct bundle_box *)lua_touserdata(L, 1);
	const char * key = luaL_checkstring(L, 2);
	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	void * value = lua_touserdata(L, 3);
	struct view_record * r = index_view(L, box->view, key);
	if (r == NULL)
		return luaL_error(L, "%s not found", key);
	r->value = value;
	return 0;
}

static int
lrelease_view(lua_State *L) {
	struct bundle_box * box = (struct bundle_box *)lua_touserdata(L, 1);
	lua_pushlightuserdata(L, box->view);
	box->view = NULL;
	return 1;
}

static int
lbox_bundle_view(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct bundle_box * box = (struct bundle_box *)lua_newuserdatauv(L, sizeof(*box), 0);
	box->view = lua_touserdata(L, 1);
	if (luaL_newmetatable(L, "BUNDLE_VIEW")) {
		luaL_Reg l[] = {
			{ "__index", lget_view },
			{ "__newindex", lset_view },
			{ "__call", lrelease_view },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);
	return 1;
}

LUAMOD_API int
luaopen_bundle_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_view", lcreate_bundle_view },
		{ "box_view", lbox_bundle_view },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}