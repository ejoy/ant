#include <lua.h>
#include <lauxlib.h>
#include "linalg.h"
#include "math3d.h"

const char *
math3d_typename(uint32_t t) {
	static const char * type_names[] = {
		"mat",
		"v4",
		"num",
		"quat",
	};
	if (t < 0 || t >= sizeof(type_names)/sizeof(type_names[0]))
		return "unknown";
	return type_names[t];
}

const float *
math3d_get_value(lua_State *L, struct lastack *LS, int index, int request_type) {
	switch (lua_type(L, index)) {
	case LUA_TNUMBER:
	case LUA_TUSERDATA: {
		int type;
		const float *result = lastack_value(LS, math3d_stack_id(L, LS, index), &type);
		if (type != request_type)
			luaL_error(L, "type mismatch %s/%s", math3d_typename(type), math3d_typename(request_type));
		return result;
	}
	case LUA_TTABLE: {
		const int len = (int)lua_rawlen(L, index);
		float tmp[16];
		int i;
		for (i=0;i<len;i++) {
			if (lua_geti(L, index, i+1) != LUA_TNUMBER) {
				luaL_error(L, "Need a number in table %d", i+1);
			}
			tmp[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		switch (request_type) {
		case LINEAR_TYPE_MAT:
			if (len != 16)
				luaL_error(L, "matrix need 16 numbers (%d)", len);
			break;
		case LINEAR_TYPE_QUAT:
			if (len != 4)
				luaL_error(L, "quat need 4 numbers (%d)", len);
			break;
		case LINEAR_TYPE_NUM:
			if (len != 1)
				luaL_error(L, "number need 1 number (%d)", len);
			break;
		case LINEAR_TYPE_VEC4:
			if (len == 3) {
				tmp[3] = 1.0f;
			} else if (len != 4) {
				luaL_error(L, "vector need 3/4 numbers (%d)", len);
			}
			break;
		default:
			luaL_error(L, "Invalid request type %s", math3d_typename(request_type));
			break;
		}
		lastack_pushobject(LS, tmp, request_type);
		return lastack_value(LS, lastack_pop(LS), NULL);
	}
	case LUA_TLIGHTUSERDATA:{
		return (const float *)lua_touserdata(L, index);
	}
	default:
		luaL_error(L, "invalid data type, only support table/userdata(refvalue)/stack number");
		return NULL;
	}
}

struct lastack*
math3d_getLS(lua_State* L, int index) {
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
