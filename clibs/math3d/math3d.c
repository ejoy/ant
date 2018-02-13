#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <inttypes.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <string.h>
#include "linalg.h"
#include "math3d.h"
#include "refstack.h"

#define LINALG "LINALG"
#define LINALG_REF "LINALG_REF"
#define MAT_PERSPECTIVE 0
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

struct refobject {
	struct lastack *LS;
	int64_t id;
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
value_tostring(lua_State *L, const char * prefix, float *r, int size) {
	if (size == 4) {
		lua_pushfstring(L, "%sVEC (%f,%f,%f,%f)", prefix, r[0],r[1],r[2],r[3]);
	} else {
		lua_pushfstring(L, "%sMAT (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
			prefix,
			r[0],r[1],r[2],r[3],
			r[4],r[5],r[6],r[7],
			r[8],r[9],r[10],r[11],
			r[12],r[13],r[14],r[15]
		);
	}
}

static int
lreftostring(lua_State *L) {
	struct refobject * ref = lua_touserdata(L, 1);
	int sz;
	float * v = lastack_value(ref->LS, ref->id, &sz);
	if (v == NULL) {
		char tmp[64];
		return luaL_error(L, "Invalid ref object [%s]", lastack_idstring(ref->id, tmp));
	}
	value_tostring(L, "&", v, sz);
	return 1;
}

static inline void
release_ref(lua_State *L, struct refobject *ref) {
	if (ref->LS) {
		ref->id = lastack_unmark(ref->LS, ref->id);
	}
}

static inline int64_t
get_id(lua_State *L, int index) {
	int64_t v;
	if (sizeof(lua_Integer) >= sizeof(int64_t)) {
		v = lua_tointeger(L, index);
	} else {
		v = (int64_t)lua_tonumber(L, index);
	}
	return v;
}

static int
lassign(lua_State *L) {
	struct refobject * ref = lua_touserdata(L, 1);
	int type = lua_type(L, 2);
	switch(type) {
	case LUA_TNIL:
	case LUA_TNONE:
		release_ref(L, ref);
		break;
	case LUA_TNUMBER: {
		if (ref->LS == NULL) {
			return luaL_error(L, "Init ref object first : use stack(ref, id, '=')");
		}
		int64_t rid = get_id(L, 2);
		if (!lastack_sametype(rid, ref->id)) {
			return luaL_error(L, "type mismatch");
		}

		int64_t markid = lastack_mark(ref->LS, rid);
		if (markid == 0) {
			return luaL_error(L, "Invalid object id");
		}
		lastack_unmark(ref->LS, ref->id);
		ref->id = markid;
		break;
	}
	case LUA_TUSERDATA: {
		struct refobject *rv = lua_touserdata(L, 2);
		if (lua_rawlen(L,2) != sizeof(*rv)) {
			return luaL_error(L, "Assign Invalid ref object");
		}
		if (!lastack_sametype(ref->id, rv->id)) {
			return luaL_error(L, "type mismatch");
		}
		if (ref->LS == NULL) {
			ref->LS = rv->LS;
			if (ref->LS) {
				ref->id = lastack_mark(ref->LS, rv->id);
			}
		} else {
			if (rv->LS == NULL) {
				lastack_unmark(ref->LS, ref->id);
				ref->id = rv->id;
			} else {
				if (ref->LS != rv->LS) {
					return luaL_error(L, "Not the same stack");
				}
				lastack_unmark(ref->LS, ref->id);
				ref->id = lastack_mark(ref->LS, rv->id);
			}
		}
		break;
	}
	default:
		return luaL_error(L, "Invalid lua type %s", lua_typename(L, type));
	}
	return 0;
}

static int
lpointer(lua_State *L) {
	struct refobject * ref = lua_touserdata(L, 1);
	float * v = lastack_value(ref->LS, ref->id, NULL);
	lua_pushlightuserdata(L, (void *)v);
	return 1;
}

static int
lref(lua_State *L) {
	const char * t = luaL_checkstring(L, 1);
	int cons;
	if (strcmp(t, "vector") == 0) {
		cons = LINEAR_CONSTANT_IVEC;
	} else if (strcmp(t, "matrix") == 0) {
		cons = LINEAR_CONSTANT_IMAT;
	} else {
		return luaL_error(L, "Unsupport type %s", t);
	}
	struct refobject * ref = lua_newuserdata(L, sizeof(*ref));
	ref->LS = NULL;
	ref->id = lastack_constant(cons);

	luaL_setmetatable(L, LINALG_REF);
	return 1;
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
	if (type == MAT_PERSPECTIVE) {
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
	if (type == MAT_PERSPECTIVE) {
		matrix44_perspective(&m, left, right, bottom, top, near, far, homogeneousDepth);
	} else {
		matrix44_ortho(&m, left, right, bottom, top, near, far, homogeneousDepth);
	}
	lastack_pushmatrix(LS, m.x);
}

static void
push_value(lua_State *L, struct lastack *LS, int index) {
	size_t n = lua_rawlen(L, index);
	size_t i;
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
			push_mat(L, LS, index, MAT_PERSPECTIVE);
		} else if (strcmp(type, "ortho") == 0) {
			push_mat(L, LS, index, MAT_ORTHO);		
		} else {
			luaL_error(L, "Invalid matrix type %s", type);
		}
		return;
	}
	luaL_checkstack(L, (int)n, NULL);
	for (i=0;i<n;i++) {
		lua_geti(L, index, i+1);
		v[i] = lua_tonumber(L, -1);
		lua_pop(L,1);
	}
	switch (n) {	
	case 1:
		// float
		v[1] = v[2] = v[0];
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
		float r[4];
		if (s1 == 16) {			
			vector4_mul_matrix44(r, val0, (union matrix44 *)val1);
			lastack_pushvector(LS, r);
			return;
		} else {
			// vec4 * vec4
			//luaL_error(L, "Don't support vector4 * vector4");			
			vector4_mul_vector4(r, val0, val1);
			lastack_pushvector(LS, r);
			return;
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
	value_tostring(L, "", r, sz);
}

static void
lookat_matrix(lua_State *L, struct lastack *LS) {
	float *at = pop_vector(L, LS);
	float *eye = pop_vector(L, LS);
	union matrix44 m;
	matrix44_lookat(&m, (struct vector3 *)eye, (struct vector3 *)at, NULL);
	lastack_pushmatrix(LS, m.x);
}

static inline void
push_float(struct lastack *LS, float v) {
	float t[4];
	t[0] = t[1] = t[2] = v;
	t[3] = 1.0f;
	lastack_pushvector(LS, t);
}

/*
	P : pop and return id
	v : pop and return vector4 pointer
	m : pop and return matrix pointer
	V : top to string for debug
	R : remove stack top
	M : mark stack top and pop
 */
static int
do_command(struct ref_stack *RS, struct lastack *LS, char cmd) {
	lua_State *L = RS->L;
	switch (cmd) {
	case 'P':
		pushid(L, pop(L, LS));
		refstack_pop(RS);
		return 1;
	case 'f':
		lua_pushnumber(L, pop_vector(L,LS)[0]);
		refstack_pop(RS);
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
		refstack_pop(RS);
		return 1;
	}
	case 'V':
		top_tostring(L, LS);
		return 1;
	case '=': {
		int64_t id = pop(L, LS);
		refstack_pop(RS);
		pop(L, LS);
		int index = refstack_topid(RS);
		if (index < 0) {
			luaL_error(L, "need a ref object for assign");
		}
		struct refobject * ref = lua_touserdata(L, index);
		ref->id = lastack_mark(LS, id);
		refstack_pop(RS);
		break;
	}
	case '1':	case '2':	case '3':	case '4':	case '5':
	case '6':	case '7':	case '8':	case '9':
	{
		int index = cmd-'1'+1;
		int64_t v = lastack_dup(LS, index);
		if (v == 0)
			luaL_error(L, "dup invalid stack index (%d)", index);
		refstack_dup(RS, index);
		break;
	}
	case 'S': {
		int64_t v = lastack_swap(LS);
		if (v == 0)
			luaL_error(L, "dup empty stack");
		refstack_swap(RS);
		break;
	}
	case 'R':
		pop(L, LS);
		refstack_pop(RS);
		break;
	case '.': {
		float * vec1 = pop_vector(L, LS);
		float * vec2 = pop_vector(L, LS);
		push_float(LS, vector3_dot((struct vector3 *)vec1, (struct vector3 *)vec2));
		refstack_2_1(RS);
		break;
	}
	case 'x': {
		float r[4];
		float * vec2 = pop_vector(L, LS);
		float * vec1 = pop_vector(L, LS);
		vector3_cross((struct vector3 *)r, (struct vector3 *)vec1, (struct vector3 *)vec2);
		r[3] = 1.0f;
		lastack_pushvector(LS, r);
		refstack_2_1(RS);
		break;
	}
	case '*':
		mul_2values(L, LS);
		refstack_2_1(RS);
		break;
	case 'n':
		normalize_vector3(L, LS);
		refstack_1_1(RS);
		break;
	case 't':
		transposed_matrix(L, LS);
		refstack_1_1(RS);
		break;
	case 'i':
		inverted_matrix(L, LS);
		refstack_1_1(RS);
		break;
	case '-':
		sub_vector4(L, LS);
		refstack_2_1(RS);
		break;
	case '+':
		add_vector4(L, LS);
		refstack_2_1(RS);
		break;
	case 'l':
		lookat_matrix(L, LS);
		refstack_2_1(RS);
		break;
	default:
		luaL_error(L, "Unknown command %c", cmd);
	}
	return 0;
}

static int
push_command(struct ref_stack *RS, struct lastack *LS, int index) {
	lua_State *L = RS->L;
	int type = lua_type(L, index);

	switch(type) {
	case LUA_TTABLE:
		push_value(L, LS, index);
		refstack_push(RS);
		break;
	case LUA_TNUMBER:
		if (lastack_pushref(LS, get_id(L, index))) {
			char tmp[64];
			return luaL_error(L, "Invalid id [%s]", lastack_idstring(get_id(L, index), tmp));
		}
		refstack_push(RS);
		break;
	case LUA_TUSERDATA: {
		struct refobject * ref = lua_touserdata(L, index);
		if (lua_rawlen(L, index) != sizeof(*ref)) {
			luaL_error(L, "The userdata is not a ref object");
		}
		if (ref->LS == NULL) {
			ref->LS = LS;
		} else if (ref->LS != LS) {
			luaL_error(L, "ref object not belongs this stack");
		}
		if (lastack_pushref(LS,  ref->id)) {
			luaL_error(L, "Push invalid ref object");
		}
		refstack_pushref(RS, index);
		break;
	}
	case LUA_TSTRING: {
		size_t sz;
		const char * cmd = luaL_checklstring(L, index, &sz);
		luaL_checkstack(L, (int)(sz + 20), NULL);
		int i;
		int ret = 0;
		for (i=0;i<(int)sz;i++) {
			ret += do_command(RS, LS, cmd[i]);
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
	struct ref_stack RS;
	refstack_init(&RS, L);
	for (i=1;i<=top;i++) {
		ret += push_command(&RS, LS, i);
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

static int
lconstant(lua_State *L) {
	const char *what = luaL_checkstring(L, 1);
	int cons;
	if (strcmp(what, "identvec") == 0) {
		cons = LINEAR_CONSTANT_IVEC;
	} else if (strcmp(what, "identmat") == 0) {
		cons = LINEAR_CONSTANT_IMAT;
	} else {
		return luaL_error(L, "Invalid constant %s", what);
	}
	pushid(L, lastack_constant(cons));
	return 1;
}

static int
ltype(lua_State *L) {
	int64_t id;
	switch(lua_type(L, 1)) {
	case LUA_TNUMBER:
		id = get_id(L, 1);
		break;
	case LUA_TUSERDATA: {
		struct refobject * ref = lua_touserdata(L, 1);
		if (lua_rawlen(L,1) != sizeof(*ref)) {
			return luaL_error(L, "Get invalid ref object type");
		}
		id = ref->id;
		break;
	}
	default:
		return luaL_error(L, "Invalid lua type %s", lua_typename(L, 1));
	}
	int size;
	int marked = lastack_marked(id, &size);
	if (size == 4) {
		lua_pushstring(L, "vector");
	} else {
		lua_pushstring(L, "matrix");
	}
	lua_pushboolean(L, marked);

	return 2;
}

LUAMOD_API int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg ref[] = {
		{ "__tostring", lreftostring },
		{ "__call", lassign },
		{ "__bnot", lpointer },
		{ NULL, NULL },
	};
	luaL_newmetatable(L, LINALG_REF);
	luaL_setfuncs(L, ref, 0);
	lua_pop(L, 1);

	luaL_Reg l[] = {
		{ "new", lnew },
		{ "reset", lreset },
		{ "constant", lconstant },
		{ "print", lprint },	// for debug
		{ "type", ltype },
		{ "ref", lref },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
