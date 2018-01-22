#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <inttypes.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include "linalg.h"
#include "math3d.h"

#define LINALG "LINALG"
#define MAT_PROJ 0
#define MAT_ORTHO 1

static inline int64_t
pop(lua_State *L, struct lastack *LS) {
	int64_t v = lastack_pop(LS);
	if (v == 0)
		luaL_error(L, "pop empty stack");
	return v;
}

struct boxpointer {
	struct lastack *LS;
};

static struct lastack *
getLS(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TFUNCTION);
	if (lua_getupvalue(L, index, 1) == NULL) {
		luaL_error(L, "Can't get linalg object");
	}
	struct boxpointer * ret = luaL_checkudata(L, -1, LINALG);
	lua_pop(L, 1);
	return ret->LS;
}

static int
delLS(lua_State *L) {
	struct boxpointer *bp = lua_touserdata(L, 1);
	if (bp->LS) {
		lastack_delete(bp->LS);
		bp->LS = NULL;
	}
	return 0;
}

static void
push_srt(lua_State *L, struct lastack *LS, int index) {
	union matrix44 m;
	if (lua_getfield(L, index, "s") == LUA_TNUMBER) {
		float s = lua_tonumber(L, -1);
		lua_pop(L, 1);
		matrix44_scalemat(&m, s,s,s);
	} else if (lua_getfield(L, index, "sx") == LUA_TNUMBER) {
		float sx = lua_tonumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "sy");
		float sy = luaL_optnumber(L, -1, 1.0f);
		lua_pop(L, 1);
		lua_getfield(L, index, "sz");
		float sz = luaL_optnumber(L, -1, 1.0f);
		lua_pop(L, 1);
		matrix44_scalemat(&m, sx,sy,sz);
	} else {
		matrix44_identity(&m);
	}
	if (lua_getfield(L, index, "rx") == LUA_TNUMBER) {
		float rx = lua_tonumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "ry");
		float ry = luaL_optnumber(L, -1, 0);
		lua_pop(L, 1);
		lua_getfield(L, index, "rz");
		float rz = luaL_optnumber(L, -1, 0);
		lua_pop(L, 1);
		matrix44_rot(&m, rx,ry,rz);
	}

	if (lua_getfield(L, index, "tx") == LUA_TNUMBER) {
		float tx = lua_tonumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "ty");
		float ty = luaL_optnumber(L, -1, 0);
		lua_pop(L, 1);
		lua_getfield(L, index, "tz");
		float tz = luaL_optnumber(L, -1, 0);
		lua_pop(L, 1);
		matrix44_trans(&m, tx,ty,tz);
	}
	lastack_pushmatrix(LS, m.x);
}

static void
push_mat(lua_State *L, struct lastack *LS, int index, int type) {
	float left,right,top,bottom;
	lua_getfield(L, index, "n");
	float near = luaL_optnumber(L, -1, 0.1f);
	lua_pop(L, 1);
	lua_getfield(L, index, "f");
	float far = luaL_optnumber(L, -1, 100.0f);
	lua_pop(L, 1);
	if (type == MAT_PROJ) {
		if (lua_getfield(L, index, "fov") == LUA_TNUMBER) {
			float fov = lua_tonumber(L, -1);
			lua_pop(L, 1);
			lua_getfield(L, index, "aspect");
			float aspect = luaL_checknumber(L, -1);
			lua_pop(L, 1);
			float ymax = near * tanf(fov * (M_PI / 360));
			float xmax = ymax * aspect;
			left = -xmax;
			right = xmax;
			bottom = -ymax;
			top = ymax;
		}
	} else {
		lua_getfield(L, index, "l");
		left = luaL_checknumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "r");
		right = luaL_checknumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "b");
		bottom = luaL_checknumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "t");
		top = luaL_checknumber(L, -1);
		lua_pop(L, 1);
	}
	lua_getfield(L, index, "h");
	int homogeneousDepth = lua_toboolean(L, -1);
	lua_pop(L, 1);

	union matrix44 m;
	if (type == MAT_PROJ) {
		matrix44_perspective(&m, left, right, bottom, top, near, far, homogeneousDepth);
	} else {
		matrix44_ortho(&m, left, right, bottom, top, near, far, homogeneousDepth);
	}
	lastack_pushmatrix(LS, m.x);
}

static void
push_value(lua_State *L, struct lastack *LS, int index) {
	int n = lua_rawlen(L, index);
	int i;
	float v[16];
	if (n > 16) {
		luaL_error(L, "Invalid value %d", n);
	}
	if (n == 0) {
		const char * type = NULL;
		if (lua_getfield(L, index, "type") == LUA_TSTRING) {
			type = lua_tostring(L, -1);
			lua_pop(L, 1);
		}
		if (type == NULL || strcmp(type, "srt") == 0) {
			push_srt(L, LS, index);
		} else if (strcmp(type, "proj") == 0) {
			push_mat(L, LS, index, MAT_PROJ);
		} else if (strcmp(type, "ortho") == 0) {
			push_mat(L, LS, index, MAT_ORTHO);
		} else {
			luaL_error(L, "Invalid matrix type %s", type);
		}
		return;
	}
	luaL_checkstack(L, n, NULL);
	for (i=0;i<n;i++) {
		lua_geti(L, index, i+1);
		v[i] = lua_tonumber(L, -1);
		lua_pop(L,1);
	}
	switch (n) {
	case 3:
		// vector 3
		v[3] = 1.0f;
	case 4:
		lastack_pushvector(LS, v);
		break;
	case 16:
		lastack_pushmatrix(LS, v);
		break;
	default:
		luaL_error(L, "Invalid value %d", n);
	}
}

static inline void
pushid(lua_State *L, int64_t v) {
	if (sizeof(lua_Integer) >= sizeof(int64_t)) {
		lua_pushinteger(L, v);
	} else {
		lua_pushnumber(L, (lua_Number)v);
	}
}

static inline void
pop2_vector4(lua_State *L, struct lastack *LS, float *val[2]) {
	int64_t v1 = pop(L, LS);
	int64_t v2 = pop(L, LS);
	int s1,s2;
	val[1] = lastack_value(LS, v1, &s1);
	val[0] = lastack_value(LS, v2, &s2);
	if (s1 != 4 || s2 != 4)
		luaL_error(L, "type mismatch (Need vector)");
}

static void
add_vector4(lua_State *L, struct lastack *LS) {
	float *val[2];
	pop2_vector4(L, LS, val);
	float ret[4];
	ret[0] = val[0][0] + val[1][0];
	ret[1] = val[0][1] + val[1][1];
	ret[2] = val[0][2] + val[1][2];
	ret[3] = val[0][3] + val[1][3];
	lastack_pushvector(LS, ret);
}

static void
sub_vector4(lua_State *L, struct lastack *LS) {
	float *val[2];
	pop2_vector4(L, LS, val);
	float ret[4];
	ret[0] = val[0][0] - val[1][0];
	ret[1] = val[0][1] - val[1][1];
	ret[2] = val[0][2] - val[1][2];
	ret[3] = val[0][3] - val[1][3];
	lastack_pushvector(LS, ret);
}

static float *
pop_vector(lua_State *L, struct lastack *LS) {
	int64_t v = pop(L, LS);
	int sz = 0;
	float * r = lastack_value(LS, v, &sz);
	if (sz != 4) {
		luaL_error(L, "type mismatch, need vector");
	}
	return r;
}

static float *
pop_matrix(lua_State *L, struct lastack *LS) {
	int64_t v = pop(L, LS);
	int sz = 0;
	float * r = lastack_value(LS, v, &sz);
	if (sz != 16) {
		luaL_error(L, "type mismatch, need matrix");
	}
	return r;
}

static void
normalize_vector3(lua_State *L, struct lastack *LS) {
	float *v = pop_vector(L, LS);
	float r[4];
	float invLen = 1.0f / vector3_length((struct vector3 *)v);
	r[0] = v[0] * invLen;
	r[1] = v[1] * invLen;
	r[2] = v[2] * invLen;
	r[3] = 1.0f;
	lastack_pushvector(LS, r);
}

static void
mul_2values(lua_State *L, struct lastack *LS) {
	int64_t v1 = pop(L, LS);
	int64_t v0 = pop(L, LS);
	int s0,s1;
	float * val1 = lastack_value(LS, v1, &s1);
	float * val0 = lastack_value(LS, v0, &s0);
	if (s0 == 4) {
		if (s1 == 16) {
			float r[4];
			vector4_mul_matrix44(r, val0, (union matrix44 *)val1);
			lastack_pushvector(LS, r);
			return;
		} else {
			// vec4 * vec4
			luaL_error(L, "Don't support vector4 * vector4");
		}
	} else {
		if (s1 == 16) {
			union matrix44 m;
			matrix44_mul(&m, (union matrix44 *)val0, (union matrix44 *)val1);
			lastack_pushmatrix(LS, m.x);
			return;
		} else {
			// matrix * vec4
			luaL_error(L, "Don't support matrix * vector4");
		}
	}
}

static void
transposed_matrix(lua_State *L, struct lastack *LS) {
	float *mat = pop_matrix(L, LS);
	union matrix44 m;
	memcpy(&m, mat, sizeof(m));
	matrix44_transposed(&m);
	lastack_pushmatrix(LS, m.x);
}

static void
inverted_matrix(lua_State *L, struct lastack *LS) {
	float *mat = pop_matrix(L, LS);
	union matrix44 r;
	matrix44_inverted(&r, (union matrix44 *)mat);
	lastack_pushmatrix(LS, r.x);
}

static void
top_tostring(lua_State *L, struct lastack *LS) {
	int64_t v = lastack_top(LS);
	if (v == 0)
		luaL_error(L, "top empty stack");
	int sz = 0;
	float * r = lastack_value(LS, v, &sz);
	if (sz == 4) {
		lua_pushfstring(L, "VEC (%f,%f,%f,%f)", r[0],r[1],r[2],r[3]);
	} else {
		lua_pushfstring(L, "MAT (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
			r[0],r[1],r[2],r[3],
			r[4],r[5],r[6],r[7],
			r[8],r[9],r[10],r[11],
			r[12],r[13],r[14],r[15]
		);
	}
}

static void
lookat_matrix(lua_State *L, struct lastack *LS) {
	float *at = pop_vector(L, LS);
	float *eye = pop_vector(L, LS);
	union matrix44 m;
	matrix44_lookat(&m, (struct vector3 *)eye, (struct vector3 *)at, NULL);
	lastack_pushmatrix(LS, m.x);
}

/*
	P : pop and return id
	v : pop and return vector4 pointer
	m : pop and return matrix pointer
	V : top to string for debug
	D : dup stack top
	R : remove stack top
	M : mark stack top and pop
 */
static int
do_command(lua_State *L, struct lastack *LS, char cmd) {
	switch (cmd) {
	case 'P':
		pushid(L, pop(L, LS));
		return 1;
	case 'f':
		lua_pushnumber(L, pop_vector(L,LS)[0]);
		return 1;
	case 'v':
		lua_pushlightuserdata(L, pop_vector(L, LS));
		return 1;
	case 'm':
		lua_pushlightuserdata(L, pop_matrix(L, LS));
		return 1;
	case 'T': {
		int64_t v = pop(L, LS);
		int sz;
		float * val = lastack_value(LS, v, &sz);
		lua_createtable(L, sz, 0);
		int i;
		for (i=0;i<sz;i++) {
			lua_pushnumber(L, val[i]);
			lua_seti(L, -2, i+1);
		}
		return 1;
	}
	case 'V':
		top_tostring(L, LS);
		return 1;
	case 'M': {
		int64_t v = lastack_mark(LS);
		if (v == 0)
			luaL_error(L, "mark empty stack or too many marked values");
		pushid(L, v);
		return 1;
	}
	case 'D': {
		int64_t v = lastack_dup(LS);
		if (v == 0)
			luaL_error(L, "dup empty stack");
		break;
	}
	case 'S': {
		int64_t v = lastack_swap(LS);
		if (v == 0)
			luaL_error(L, "dup empty stack");
		break;
	}
	case 'R':
		pop(L, LS);
		break;
	case '.': {
		float r[4] = { 0,0,0,1 };
		float * vec1 = pop_vector(L, LS);
		float * vec2 = pop_vector(L, LS);
		r[0] = vector3_dot((struct vector3 *)vec1, (struct vector3 *)vec2);
		lastack_pushvector(LS, r);
		break;
	}
	case 'x': {
		float r[4];
		float * vec2 = pop_vector(L, LS);
		float * vec1 = pop_vector(L, LS);
		vector3_cross((struct vector3 *)r, (struct vector3 *)vec1, (struct vector3 *)vec2);
		r[3] = 1.0f;
		lastack_pushvector(LS, r);
		break;
	}
	case '*':
		mul_2values(L, LS);
		break;
	case 'n':
		normalize_vector3(L, LS);
		break;
	case 't':
		transposed_matrix(L, LS);
		break;
	case 'i':
		inverted_matrix(L, LS);
		break;
	case '-':
		sub_vector4(L, LS);
		break;
	case '+':
		add_vector4(L, LS);
		break;
	case 'l':
		lookat_matrix(L, LS);
		break;
	}
	return 0;
}

static int
push_command(lua_State *L, struct lastack *LS, int index) {
	int type = lua_type(L, index);
	switch(type) {
	case LUA_TTABLE:
		push_value(L, LS, index);
		break;
	case LUA_TNUMBER: {
		int64_t v;
		if (sizeof(lua_Integer) >= sizeof(int64_t)) {
			v = lua_tointeger(L, index);
		} else {
			v = (int64_t)lua_tonumber(L, index);
		}
		if (lastack_pushref(LS, v)) {
			return luaL_error(L, "Invalid id %I", v);
		}
		break;
	}
	case LUA_TSTRING: {
		size_t sz;
		const char * cmd = luaL_checklstring(L, index, &sz);
		luaL_checkstack(L, sz + 20, NULL);
		int i;
		int ret = 0;
		for (i=0;i<(int)sz;i++) {
			ret += do_command(L, LS, cmd[i]);
		}
		return ret;
	}
	default:
		return luaL_error(L, "Invalid command type %s at %d", lua_typename(L, type), index);
	}
	return 0;
}

static int
commandLS(lua_State *L) {
	struct boxpointer *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	int top = lua_gettop(L);
	int i;
	int ret = 0;
	for (i=1;i<=top;i++) {
		ret += push_command(L, LS, i);
	}
	return ret;
}

static int
lnew(lua_State *L) {
	struct boxpointer *bp = lua_newuserdata(L, sizeof(*bp));
	bp->LS = NULL;
	if (luaL_newmetatable(L, LINALG)) {
		lua_pushcfunction(L, delLS);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	lua_pushcclosure(L, commandLS, 1);
	bp->LS = lastack_new();
	return 1;
}

static int
lreset(lua_State *L) {
	struct lastack *LS = getLS(L, 1);
	lastack_reset(LS);
	return 0;
}

static int
lprint(lua_State *L) {
	struct lastack *LS = getLS(L, 1);
	lastack_print(LS);
	return 0;
}

LUAMOD_API int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "new", lnew },
		{ "reset", lreset },
		{ "print", lprint },	// for debug
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
