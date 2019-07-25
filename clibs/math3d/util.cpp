
extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include "linalg.h"
#include "math3d.h"
}

#include "util.h"

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

template<>
void
get_table_value(lua_State* L, int tblidx, int num, glm::mat4x4& v) {
	for (int ii = 0; ii < num; ++ii) {
		get_table_value(L, tblidx, 4, v[ii]);
	}
}

float get_table_item(lua_State* L, int tblidx, int idx) {
	lua_geti(L, tblidx, idx);
	float s = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return s;
}

struct lastack*
getLS(lua_State* L, int index) {
	int type = lua_type(L, index);
	struct boxstack* ret;
	if (type == LUA_TFUNCTION) {
		if (lua_getupvalue(L, index, 1) == NULL) {
			luaL_error(L, "Can't get linalg object");
		}
		ret = (struct boxstack*)luaL_checkudata(L, -1, LINALG);
		lua_pop(L, 1);
	}
	else {
		ret = (struct boxstack*)luaL_checkudata(L, index, LINALG);
	}
	return ret->LS;
}
