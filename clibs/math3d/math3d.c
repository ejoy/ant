#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <math.h>

#ifndef _MSC_VER
#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif
#endif // !_MSC_VER

#ifndef lua_newuserdata
// lua_newuserdata is a macro in Lua 5.4 
#define lua_newuserdatauv(L, sz, n) lua_newuserdata(L,sz)
#endif

#include "string.h"

#include "linalg.h"	
#include "math3d.h"
#include "math3dfunc.h"

#define MAT_PERSPECTIVE 0
#define MAT_ORTHO 1

static int g_default_homogeneous_depth = 0;

int
math3d_homogeneous_depth() {
	return g_default_homogeneous_depth;
}

static inline void *
STACKID(int64_t id) {
	return (void *)id;
}

static inline void *
REFID(struct refobject *R) {
	return STACKID(R->id);
}

static inline int64_t
LUAID(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TLIGHTUSERDATA);
	void * ud = lua_touserdata(L, index);
	return (int64_t)ud;
}

static inline struct lastack *
GETLS(lua_State *L) {
	return (struct lastack *)lua_touserdata(L, lua_upvalueindex(1));
}

static void
finalize(lua_State *L, lua_CFunction gc) {
	lua_createtable(L, 0, 1);
	lua_pushcfunction(L, gc);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
}

static int
boxstack_gc(lua_State *L) {
	struct boxstack *bs = lua_touserdata(L, 1);
	if (bs->LS) {
		lastack_delete(bs->LS);
		bs->LS = NULL;
	}
	return 0;
}

static int64_t
get_id(lua_State *L, int index, int ltype) {
	if (ltype == LUA_TLIGHTUSERDATA) {
		return (int64_t)lua_touserdata(L, index);
	} else if (ltype == LUA_TUSERDATA) {
		if (lua_rawlen(L, index) != sizeof(struct refobject)) {
			luaL_error(L, "Invalid ref userdata");
		}
		struct refobject * ref = lua_touserdata(L, index);
		return ref->id;
	}
	return luaL_argerror(L, index, "Need userdata");
}

static int
lref(lua_State *L) {
	lua_settop(L, 1);
	struct refobject * R = lua_newuserdatauv(L, sizeof(struct refobject), 0);
	if (lua_isnil(L, 1)) {
		R->id = 0;
	} else {
		int64_t id = get_id(L, 1, lua_type(L, 1));
		R->id = lastack_mark(GETLS(L), id);
	}
	lua_pushvalue(L, lua_upvalueindex(2));
	lua_setmetatable(L, -2);
	return 1;
}

static int64_t
assign_id(lua_State *L, struct lastack *LS, int index, int mtype, int ltype) {
	switch (ltype) {
	case LUA_TNIL:
	case LUA_TNONE:
		// identity matrix
		return lastack_constant(mtype);
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA: {
		int64_t id = get_id(L, index, ltype);
		int type;
		const float * v = lastack_value(LS, id, &type);
		if (type != mtype && v) {
			if (mtype == LINEAR_TYPE_MAT && type == LINEAR_TYPE_QUAT) {
				math3d_quat_to_matrix(LS, v);
				id = lastack_pop(LS);
			} else if (mtype == LINEAR_TYPE_QUAT && type == LINEAR_TYPE_MAT) {
				math3d_matrix_to_quat(LS, v);
				id = lastack_pop(LS);
			} else {
				return luaL_error(L, "%s type mismatch %s", lastack_typename(mtype), lastack_typename(type));
			}
		}
		return lastack_mark(LS, id); }
	default:
		return luaL_error(L, "Invalid type %s for %s ref", lua_typename(L, ltype), lastack_typename(mtype));
	}
}

static void
unpack_numbers(lua_State *L, int index, float *v, int n) {
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, index, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Need a number from index %d", i+1);
		}
		v[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}

typedef int64_t (*from_table_func)(lua_State *L, struct lastack *LS, int index);

static int64_t
vector_from_table(lua_State *L, struct lastack *LS, int index) {
	int n = lua_rawlen(L, index);
	if (n != 3 && n != 4)
		return luaL_error(L, "Vector need a array of 3/4 (%d)", n);
	float v[4];
	v[3] = 1.0f;
	unpack_numbers(L, index, v, n);
	lastack_pushvec4(LS, v);
	return lastack_pop(LS);
}

static const float *
object_from_index(lua_State *L, struct lastack *LS, int index, int mtype, from_table_func from_table) {
	int ltype = lua_type(L, index);
	const float * result = NULL;
	switch(ltype) {
	case LUA_TNIL:
	case LUA_TNONE:
		break;
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA: {
		int64_t id = get_id(L, index, ltype);
		int type;
		result = lastack_value(LS, id, &type);
		if (result == NULL || type != mtype) {
			luaL_error(L, "Need a %s , it's a %s.", lastack_typename(mtype), result == NULL ? "invalid" : lastack_typename(type));
		}
		break; }
	case LUA_TTABLE:
		result = lastack_value(LS, from_table(L, LS, index), NULL);
		break;
	default:
		luaL_error(L, "Invalid lua type %s", lua_typename(L, ltype));
	}
	return result;
}

static const float *
object_from_field(lua_State *L, struct lastack *LS, int index, const char *key, int mtype, from_table_func from_table) {
	lua_getfield(L, index, key);
	const float * result = object_from_index(L, LS, -1, mtype, from_table);
	lua_pop(L, 1);
	return result;
}

static int
quat_from_axis(lua_State *L, struct lastack *LS, int index, const char *key) {
	if (lua_getfield(L, index, key) == LUA_TNIL) {
		lua_pop(L, 1);
		return 1;
	}

	const float * axis = object_from_index(L, LS, -1, LINEAR_TYPE_VEC4, vector_from_table);
	lua_pop(L, 1);

	if (lua_getfield(L, index, "r") != LUA_TNUMBER) {
		return luaL_error(L, "Need .r for quat");
	}
	float r = lua_tonumber(L, -1);
	lua_pop(L, 1);

	math3d_make_quat_from_axis(LS, axis, r);
	return 0;
}

static int64_t
quat_from_table(lua_State *L, struct lastack *LS, int index) {
	int n = lua_rawlen(L, index);
	if (n == 0) {
		if (quat_from_axis(L, LS, index, "axis"))
			return luaL_error(L, "Quat invalid arguments");
	} else if (n == 3) {
		float e[3];
		unpack_numbers(L, index, e, 3);
		math3d_make_quat_from_euler(LS, e[0], e[1], e[2]);
	} else if (n == 4) {
		float v[4];
		unpack_numbers(L, index, v, 4);
		lastack_pushquat(LS, v);
	} else {
		return luaL_error(L, "Quat need a array of 4 (quat) or 3 (eular), it's (%d)", n);
	}
	return lastack_pop(LS);
}


static int64_t
matrix_from_table(lua_State *L, struct lastack *LS, int index) {
	int n = lua_rawlen(L, index);
	if (n == 0) {
		const float *s;
		float tmp[4];
		if (lua_getfield(L, index, "s") == LUA_TNUMBER) {
			tmp[0] = lua_tonumber(L, -1);
			tmp[1] = tmp[0];
			tmp[2] = tmp[0];
			tmp[3] = 0;
			s = tmp;
		} else {
			s = object_from_index(L, LS, -1, LINEAR_TYPE_VEC4, vector_from_table);
		}
		lua_pop(L, 1);
		const float *q = object_from_field(L, LS, index, "r", LINEAR_TYPE_QUAT, quat_from_table);
		const float *t = object_from_field(L, LS, index, "t", LINEAR_TYPE_VEC4, vector_from_table);
		math3d_make_srt(LS,s,q,t);
	} else if (n != 16) {
		return luaL_error(L, "Matrix need a array of 16 (%d)", n);
	} else {
		float v[16];
		unpack_numbers(L, index, v, 16);
		lastack_pushmatrix(LS, v);
	}
	return lastack_pop(LS);
}

static int64_t
assign_object(lua_State *L, struct lastack *LS, int index, int mtype, from_table_func from_table) {
	int ltype = lua_type(L, index);
	if (ltype == LUA_TTABLE) {
		int64_t id = from_table(L, LS, index);
		return lastack_mark(LS, id);
	}
	return assign_id(L, LS, index, mtype, ltype);
}

static int64_t
assign_matrix(lua_State *L, struct lastack *LS, int index) {
	return assign_object(L, LS, index, LINEAR_TYPE_MAT, matrix_from_table);
}

static int64_t
assign_vector(lua_State *L, struct lastack *LS, int index) {
	return assign_object(L, LS, index, LINEAR_TYPE_VEC4, vector_from_table);
}

static int64_t
assign_quat(lua_State *L, struct lastack *LS, int index) {
	return assign_object(L, LS, index, LINEAR_TYPE_QUAT, quat_from_table);
}

static inline void
copy_matrix(lua_State *L, struct lastack *LS, int64_t id, float result[64]) {
	int type;
	const float *mat = lastack_value(LS, id, &type);
	if (mat == NULL || type != LINEAR_TYPE_MAT)
		luaL_error(L, "Need a matrix to decompose, it's a %s.", mat == NULL ? "None" : lastack_typename(type));
	memcpy(result, mat, 16 * sizeof(float));
}

static int64_t
assign_scale(lua_State *L, struct lastack *LS, int index, int64_t oid) {
	float mat[64];
	float quat[4];
	float tmp[4];
	const float * scale = NULL;
	if (lua_type(L, index) == LUA_TNUMBER) {
		float us = lua_tonumber(L, index);
		if (us != 1.0f) {
			tmp[0] = tmp[1] = tmp[2] = us;
			tmp[3] = 0;
			scale = tmp;
		}
	} else {
		scale = object_from_index(L, LS, index, LINEAR_TYPE_VEC4, vector_from_table);
	}
	copy_matrix(L, LS, oid, mat);
	float *trans = &mat[3*4];
	math3d_make_srt(LS, scale, 
		math3d_decompose_rot(mat, quat) ? NULL : quat,
		trans);
	return lastack_mark(LS, lastack_pop(LS));
}

static int64_t
assign_rot(lua_State *L, struct lastack *LS, int index, int64_t oid) {
	float mat[64];
	float scale[4];
	copy_matrix(L, LS, oid, mat);
	math3d_decompose_scale(mat, scale);
	float *trans = &mat[3*4];
	const float * quat = object_from_index(L, LS, index, LINEAR_TYPE_QUAT, quat_from_table);
	math3d_make_srt(LS, scale, quat, trans);
	return lastack_mark(LS, lastack_pop(LS));
}

static int64_t
assign_trans(lua_State *L, struct lastack *LS, int index, int64_t oid) {
	float mat[64];
	copy_matrix(L, LS, oid, mat);
	const float * t = object_from_index(L, LS, index, LINEAR_TYPE_VEC4, vector_from_table);
	if (t == NULL) {
		mat[3*4+0] = 0;
		mat[3*4+1] = 0;
		mat[3*4+2] = 0;
		mat[3*4+3] = 1;
	} else {
		mat[3*4+0] = t[0];
		mat[3*4+1] = t[1];
		mat[3*4+2] = t[2];
		mat[3*4+3] = 1;
	}
	lastack_pushmatrix(LS, mat);
	return lastack_mark(LS, lastack_pop(LS));
}

static int
lref_setter(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	const char *key = luaL_checkstring(L, 2);
	struct lastack *LS = GETLS(L);
	int64_t oid = R->id;
	switch(key[0]) {
	case 'i':	// value id
		R->id = lastack_mark(LS, get_id(L, 3, lua_type(L, 3)));
		break;
	case 'v':	// should be vector
		R->id = assign_vector(L, LS, 3);
		break;
	case 'q':	// should be quat
		R->id = assign_quat(L, LS, 3);
		break;
	case 'm':	// should be matrix
		R->id = assign_matrix(L, LS, 3);
		break;
	case 's':
		R->id = assign_scale(L, LS, 3, oid);
		break;
	case 'r':
		R->id = assign_rot(L, LS, 3, oid);
		break;
	case 't':
		R->id = assign_trans(L, LS, 3, oid);
		break;
	default:
		return luaL_error(L, "Invalid set key %s with ref object", key); 
	}
	// we must unmark old id after assign, because 'v.i = v'
	lastack_unmark(LS, oid);
	return 0;
}

static void
to_table(lua_State *L, struct lastack *LS, int64_t id) {
	int type;
	const float * v = lastack_value(LS, id, &type);
	if (v == NULL) {
		lua_pushnil(L);
		return;
	}
	int n = lastack_typesize(type);
	int i;
	lua_createtable(L, n, 1);
	for (i=0;i<n;i++) {
		lua_pushnumber(L, v[i]);
		lua_rawseti(L, -2, i+1);
	}
	lua_pushstring(L, lastack_typename(type));
	lua_setfield(L, -2, "type");
}

static int64_t
extract_srt(struct lastack *LS, const float *mat, int what) {
	float v[4];
	switch(what) {
	case 's':
		math3d_decompose_scale(mat, v);
		lastack_pushvec4(LS, v);
		break;
	case 'r':
		if (math3d_decompose_rot(mat, v)) {
			return lastack_constant(LINEAR_TYPE_QUAT);
		} else {
			lastack_pushquat(LS, v);
		}
		break;
	case 't':
		v[0] = mat[3*4+0];
		v[1] = mat[3*4+1];
		v[2] = mat[3*4+2];
		v[3] = 1;
		lastack_pushvec4(LS, v);
		break;
	default:
		return 0;
	}
	return lastack_pop(LS);
}

static int
ref_get_key(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	struct lastack * LS = GETLS(L);
	const char *key = lua_tostring(L, 2);
	switch(key[0]) {
	case 'i':
		lua_pushlightuserdata(L, REFID(R));
		break;
	case 'p':
		lua_pushlightuserdata(L, (void *)(lastack_value(LS, R->id, NULL)));
		break;
	case 'v':
		to_table(L, LS, R->id);
		break;
	case 's':
	case 'r':
	case 't': {
		int type;
		const float *m = lastack_value(LS, R->id, &type);
		if (m == NULL || type != LINEAR_TYPE_MAT)
			return luaL_error(L, "Not a matrix");
		lua_pushlightuserdata(L, STACKID(extract_srt(LS, m ,key[0])));
		break; }
	default:
		return luaL_error(L, "Invalid get key %s with ref object", key); 
	}
	return 1;
}

static int
index_object(lua_State *L, struct lastack *LS, int64_t id, int idx) {
	int type;
	const float * v = lastack_value(LS, id, &type);
	if (v == NULL) {
		return luaL_error(L, "Invalid ref object");
	}
	if (idx < 1 || idx > 4) {
		return luaL_error(L, "Invalid index %d", idx);
	}
	--idx;
	switch (type) {
	case LINEAR_TYPE_MAT:
		lastack_pushvec4(LS, &v[idx*4]);
		lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
		break;
	case LINEAR_TYPE_VEC4:
		lua_pushnumber(L, v[idx]);
		break;
	case LINEAR_TYPE_QUAT:
		lua_pushnumber(L, v[idx]);
		break;
	default:
		return 0;
	}
	return 1;
}

static int
ref_get_number(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	struct lastack * LS = GETLS(L);
	int idx = lua_tointeger(L, 2);
	int type;
	const float * v = lastack_value(LS, R->id, &type);
	if (v == NULL) {
		return luaL_error(L, "Invalid ref object");
	}
	return index_object(L, LS, R->id, idx);
}


static int
lindex(lua_State *L) {
	int64_t id = get_id(L, 1, lua_type(L, 1));
	int idx = luaL_checkinteger(L, 2);
	return index_object(L, GETLS(L), id, idx);
	return 0;
}


static int
lref_getter(lua_State *L) {
	int type = lua_type(L, 2);
	switch (type) {
	case LUA_TNUMBER:
		return ref_get_number(L);
	case LUA_TSTRING:
		return ref_get_key(L);
	default:
		return luaL_error(L, "Invalid key type %s", lua_typename(L, type));
	}
}

static int
id_tostring(lua_State *L, int64_t id) {
	int type;
	const float * v = lastack_value(GETLS(L), id, &type);
	if (v == NULL) {
		lua_pushstring(L, "Invalid");
		return 1;
	}
	switch (type) {
	case LINEAR_TYPE_MAT:
		lua_pushfstring(L, "MAT (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
			v[0],v[1],v[2],v[3],
			v[4],v[5],v[6],v[7],
			v[8],v[9],v[10],v[11],
			v[12],v[13],v[14],v[15]);
		break;
	case LINEAR_TYPE_VEC4:
		lua_pushfstring(L, "VEC4 (%f,%f,%f,%f)",
			v[0], v[1], v[2], v[3]);
		break;
	case LINEAR_TYPE_QUAT:
		lua_pushfstring(L, "QUAT (%f,%f,%f,%f)",
			v[0], v[1], v[2], v[3]);
		break;
	default:
		lua_pushstring(L, "Unknown");
		break;
	}
	return 1;
}

static int
lref_tostring(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	if (R->id == 0) {
		lua_pushstring(L, "Null");
		return 1;
	}
	return id_tostring(L, R->id);
}

static int
ltostring(lua_State *L) {
	int64_t id = get_id(L, 1, lua_type(L, 1));
	return id_tostring(L, id);
}

static int
lref_gc(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	if (R->id) {
		lastack_unmark(GETLS(L), R->id);
		R->id = 0;
	}
	return 0;
}

static int
new_object(lua_State *L, int type, from_table_func from_table, int narray) {
	int argn = lua_gettop(L);
	int64_t id;
	if (argn == narray) {
		int i;
		float tmp[16];
		struct lastack *LS = GETLS(L);
		for (i=0;i<argn;i++) {
			tmp[i] = luaL_checknumber(L, i+1);
		}
		lastack_pushobject(LS, tmp, type);
		id = lastack_pop(LS);
	} else {
		switch(argn) {
		case 0:
			id = lastack_constant(type);
			break;
		case 1:
			luaL_checktype(L, 1, LUA_TTABLE);
			id = from_table(L, GETLS(L), 1);
			break;
		default:
			return luaL_error(L, "Invalid %s argument number %d", lastack_typename(type), argn);
		}
	}
	lua_pushlightuserdata(L, STACKID(id));
	return 1;
}

static int
lreset(lua_State *L) {
	lastack_reset(GETLS(L));
	return 0;
}

static const float *
get_object(lua_State *L, struct lastack *LS, int index, int *type) {
	int ltype = lua_type(L, index);
	if (ltype == LUA_TNUMBER) {
		float n[4] = { lua_tonumber(L, index),0,0,0 };
		lastack_pushvec4(LS, n);
		*type = LINEAR_TYPE_NUM;
		return lastack_value(LS, lastack_pop(LS), NULL);
	}
	int64_t id = get_id(L, index, ltype);
	const float * v = lastack_value(LS, id, type);
	if (v == NULL)
		luaL_error(L, "Invalid id at stack %d", index);
	return v;
}

static int
lmul(lua_State *L) {
	int top = lua_gettop(L);
	struct lastack *LS = GETLS(L);
	int i;
	float tmp[16];
	int lt,rt;
	if (top < 2) {
		return luaL_error(L, "Need 2 or more objects");
	}
	const float *lv = get_object(L, LS, 1, &lt);
	for (i=2;i<=top;i++) {
		const float *rv = get_object(L, LS, i, &rt);
		int result_type = math3d_mul_object(LS, lv, rv, lt, rt, tmp);
		if (result_type == LINEAR_TYPE_NONE) {
			return luaL_error(L, "Invalid mul arguments at %d, ltype = %d rtype = %d\nmatrix or quaternion mul vector should use 'transform' function", i, lt, rt);
		}
		lt = result_type;
		lv = tmp;
	}
	lastack_pushobject(LS, tmp, lt);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static const float *
vector_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * v = object_from_index(L, LS, index, LINEAR_TYPE_VEC4, vector_from_table);
	if (v == NULL)
		luaL_error(L, "Need a vector");
	return v;
}

static int
ladd(lua_State *L) {
	struct lastack *LS = GETLS(L);
	int i;
	float tmp[4];
	int top = lua_gettop(L);
	if (top < 2) {
		return luaL_error(L, "Need 2 or more vectors");
	}
	const float *lv = vector_from_index(L, LS, 1);
	for (i=2;i<=top;i++) {
		const float *rv = vector_from_index(L, LS, 2);
		math3d_add_vec(LS, lv, rv, tmp);
		lv = tmp;
	}
	lastack_pushvec4(LS, tmp);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lsub(lua_State *L) {
	struct lastack *LS = GETLS(L);
	float tmp[4];
	const float *v0 = vector_from_index(L, LS, 1);
	const float *v1 = vector_from_index(L, LS, 2);
	math3d_sub_vec(LS, v0, v1, tmp);

	lastack_pushvec4(LS, tmp);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lmuladd(lua_State *L){
	struct lastack *LS = GETLS(L);
	
	int ltype, rtype;
	const float *v0 = get_object(L, LS, 1, &ltype);
	if (ltype != LINEAR_TYPE_NUM && ltype != LINEAR_TYPE_VEC4){
		return luaL_error(L, "argument 1 must be number/vec4:%s", lastack_typename(ltype));
	}
	const float *v1 = get_object(L, LS, 2, &rtype);
	if (rtype != LINEAR_TYPE_NUM && rtype != LINEAR_TYPE_VEC4){
		return luaL_error(L, "argument 1 must be number/vec4:%s", lastack_typename(rtype));
	}

	if ((ltype == LINEAR_TYPE_NUM && rtype == LINEAR_TYPE_VEC4) ||
		(ltype == LINEAR_TYPE_VEC4 && rtype == LINEAR_TYPE_NUM) ||
		(ltype == LINEAR_TYPE_VEC4 && rtype == LINEAR_TYPE_VEC4)){
		float result[16];
		math3d_mul_object(LS, v0, v1, ltype, rtype, result);
		const float * v2 = vector_from_index(L, LS, 3);

		math3d_add_vec(LS, result, v2, result);
		lastack_pushvec4(LS, result);
		lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
		return 1;
	}

	return luaL_error(L, "argumen 1/2 must be one of them as vec4, argument 1:%s, argument 2:%s", lastack_typename(ltype), lastack_typename(rtype));
}

static const float *
matrix_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * m = object_from_index(L, LS, index, LINEAR_TYPE_MAT, matrix_from_table);
	if (m == NULL)
		luaL_error(L, "Need a vector");
	return m;
}

static const float *
quat_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * q = object_from_index(L, LS, index, LINEAR_TYPE_QUAT, quat_from_table);
	if (q == NULL)
		luaL_error(L, "Need a quat");
	return q;
}

static int64_t
quat_to_matrix(lua_State *L, struct lastack *LS, int index) {
	const float * quat = quat_from_index(L, LS, index);
	math3d_quat_to_matrix(LS, quat);
	return lastack_pop(LS);
}

static int64_t
object_to_quat(lua_State *L, struct lastack *LS, int index) {
	int64_t id = get_id(L, index, lua_type(L, index));
	int type;
	const float * v = lastack_value(LS, id, &type);
	switch(type) {
	case LINEAR_TYPE_MAT:
		math3d_matrix_to_quat(LS, v);
		break;
	case LINEAR_TYPE_QUAT:
		return id;
	case LINEAR_TYPE_VEC4:
		math3d_make_quat_from_euler(LS, v[0], v[1], v[2]);
		break;
	default:
		return luaL_error(L, "Invalid type %s for quat", lastack_typename(type));
	}
	return lastack_pop(LS);
}

static int
lmatrix(lua_State *L) {
	if (lua_isuserdata(L, 1)) {
		int64_t id = quat_to_matrix(L, GETLS(L), 1);
		lua_pushlightuserdata(L, STACKID(id));
		return 1;
	}
	return new_object(L, LINEAR_TYPE_MAT, matrix_from_table, 16);
}

static int
lvector(lua_State *L) {
	int top = lua_gettop(L);
	if (top == 3) {
		lua_pushnumber(L, 0.0f);
	} else if (top == 2) {
		struct lastack *LS = GETLS(L);
		const float * vec3 = vector_from_index(L, LS, 1);
		float n4 = luaL_checknumber(L, 2);
		float vec4 [4] = { vec3[0], vec3[1], vec3[2], n4 };
		lastack_pushvec4(LS, vec4);
		lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
		return 1;
	}
	return new_object(L, LINEAR_TYPE_VEC4, vector_from_table, 4);
}

static int
lquaternion(lua_State *L) {
	if (lua_isuserdata(L, 1)) {
		int64_t id = object_to_quat(L, GETLS(L), 1);
		lua_pushlightuserdata(L, STACKID(id));
		return 1;
	}
	return new_object(L, LINEAR_TYPE_QUAT, quat_from_table, 4);
}

static int
lsrt(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * mat = matrix_from_index(L, LS, 1);
	if (math3d_decompose_matrix(LS, mat)) {
		// failed
		return 0;
	}
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 3;	
}

static int
llength(lua_State *L) {
	const float * v3 = vector_from_index(L, GETLS(L), 1);
	lua_pushnumber(L, math3d_length(v3));
	return 1;
}

static int
lfloor(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v = vector_from_index(L, LS, 1);
	math3d_floor(LS, v);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lceil(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v = vector_from_index(L, LS, 1);
	math3d_ceil(LS, v);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ldot(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v1 = vector_from_index(L, LS, 1);
	const float * v2 = vector_from_index(L, LS, 2);
	lua_pushnumber(L, math3d_dot(v1,v2));
	return 1;
}

static int
lcross(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v1 = vector_from_index(L, LS, 1);
	const float * v2 = vector_from_index(L, LS, 2);
	math3d_cross(LS, v1, v2);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lnormalize(lua_State *L) {
	int type;
	struct lastack *LS = GETLS(L);
	const float *v = get_object(L, LS, 1, &type);
	switch (type) {
	case LINEAR_TYPE_VEC4:
		math3d_normalize_vector(LS, v);
		break;
	case LINEAR_TYPE_QUAT:
		math3d_normalize_quat(LS, v);
		break;
	default:
		return luaL_error(L, "normalize don't support %s", lastack_typename(type));
	}
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ltranspose(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * mat = matrix_from_index(L, LS, 1);
	math3d_transpose_matrix(LS, mat);

	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
linverse(lua_State *L) {
	int type;
	struct lastack *LS = GETLS(L);
	const float *v = get_object(L, LS, 1, &type);
	switch (type) {
	case LINEAR_TYPE_VEC4: {
		float iv[4] = { -v[0], -v[1], -v[2], v[3] };
		lastack_pushvec4(LS, iv);
		break; }
	case LINEAR_TYPE_QUAT:
		math3d_inverse_quat(LS, v);
		break;
	case LINEAR_TYPE_MAT:
		math3d_inverse_matrix(LS, v);
		break;
	default:
		return luaL_error(L, "inverse don't support %s", lastack_typename(type));
	}
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
llookat(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * eye = vector_from_index(L, LS, 1);
	const float * at = vector_from_index(L, LS, 2);
	const float * up = object_from_index(L, LS, 3, LINEAR_TYPE_VEC4, vector_from_table);

	math3d_lookat_matrix(LS, 0, eye, at, up);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
llookto(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * eye = vector_from_index(L, LS, 1);
	const float * at = vector_from_index(L, LS, 2);
	const float * up = object_from_index(L, LS, 3, LINEAR_TYPE_VEC4, vector_from_table);

	math3d_lookat_matrix(LS, 1, eye, at, up);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lreciprocal(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v = vector_from_index(L, LS, 1);

	math3d_reciprocal(LS, v);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ltodirection(lua_State *L) {
	struct lastack *LS = GETLS(L);
	int type;
	const float *v = get_object(L, LS, 1, &type);
	switch (type) {
	case LINEAR_TYPE_QUAT:
		math3d_quat_to_viewdir(LS, v);
		break;
	case LINEAR_TYPE_MAT:
		math3d_rotmat_to_viewdir(LS, v);
		break;
	default:
		return luaL_error(L, "todirection don't support %s", lastack_typename(type));
	}
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ltorotation(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * v = vector_from_index(L, LS, 1);
	math3d_viewdir_to_quat(LS, v);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ltotable(lua_State *L){
	struct lastack *LS = GETLS(L);
	int64_t id = get_id(L, 1, lua_type(L, 1));
	to_table(L, LS, id);
	return 1;
}

static int
lbase_axes(lua_State *L) {
	struct lastack *LS = GETLS(L);

	const float *forward = vector_from_index(L, LS, 1);

	math3d_base_axes(LS, forward);

	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));	// right
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));	// up
	return 2;
}

static int
ltransform(lua_State *L){
	struct lastack *LS = GETLS(L);
	const int64_t rotatorid = get_id(L, 1, lua_type(L, 1));

	if (lua_isnone(L, 3)){
		return luaL_error(L, "need argument 3, 0 for vector, 1 for point, 'nil' will use vector[4] value");
	}

	const float* v = vector_from_index(L, LS, 2);
	if (!lua_isnil(L, 3)){
		const int ispoint = luaL_checkinteger(L, 3);
		const float vv[4] = {v[0], v[1], v[2], ispoint ? 1.f : 0.f};
		lastack_pushvec4(LS, vv);
		v = lastack_value(LS, lastack_pop(LS), NULL);
	}

	int type;
	const float *rotator = (const float *)lastack_value(LS, rotatorid, &type);

	switch (type){
	case LINEAR_TYPE_QUAT:
		math3d_quat_transform(LS, rotator, v);
		break;
	case LINEAR_TYPE_MAT:
		math3d_rotmat_transform(LS, rotator, v);
		break;
	default: 
		return luaL_error(L, "only support quat/mat for rotate vector:%s", lastack_typename(type));
	}

	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
ltransform_homogeneous_point(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * mat = matrix_from_index(L, LS, 1);
	const float * vec = vector_from_index(L, LS, 2);

	math3d_mulH(LS, mat, vec);

	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static void
create_proj_mat(lua_State *L, struct lastack *LS, int index) {
	float left, right, top, bottom;
	lua_getfield(L, index, "n");
	float near = luaL_optnumber(L, -1, 0.1f);
	lua_pop(L, 1);
	lua_getfield(L, index, "f");
	float far = luaL_optnumber(L, -1, 100.0f);
	lua_pop(L, 1);

	int mattype = MAT_PERSPECTIVE;
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
	} else {
		lua_pop(L, 1); //pop "fov"
		lua_getfield(L, index, "ortho");
		if (lua_toboolean(L, -1)) {
			mattype = MAT_ORTHO;
		}
		lua_pop(L, 1); //pop "ortho"
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

	if (mattype == MAT_PERSPECTIVE) {
		math3d_frustumLH(LS, left, right, bottom, top, near, far, g_default_homogeneous_depth);
	} else {
		math3d_orthoLH(LS, left, right, bottom, top, near, far, g_default_homogeneous_depth);
	}

}

static int
lprojmat(lua_State *L) {
	struct lastack *LS = GETLS(L);
	luaL_checktype(L, 1, LUA_TTABLE);
	create_proj_mat(L, LS, 1);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lhomogeneous_depth(lua_State *L){
	int num = lua_gettop(L);
	if (num > 0){
		g_default_homogeneous_depth = lua_toboolean(L, 1) != 0;	
		return 0;
	}

	lua_pushboolean(L, g_default_homogeneous_depth ? 1 : 0);
	return 1;
}

LUAMOD_API int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);

	struct boxstack * bs = lua_newuserdatauv(L, sizeof(struct boxstack), 0);
	bs->LS = lastack_new();
	finalize(L, boxstack_gc);
	lua_setfield(L, LUA_REGISTRYINDEX, MATH3D_STACK);

	luaL_Reg l[] = {
		{ "ref", NULL },
		{ "tostring", ltostring },
		{ "matrix", lmatrix },
		{ "vector", lvector },
		{ "quaternion", lquaternion },
		{ "index", lindex },
		{ "reset", lreset },
		{ "mul", lmul },
		{ "add", ladd },
		{ "sub", lsub },
		{ "muladd", lmuladd},
		{ "srt", lsrt },
		{ "length", llength },
		{ "floor", lfloor },
		{ "ceil", lceil },
		{ "dot", ldot },
		{ "cross", lcross },
		{ "normalize", lnormalize },
		{ "transpose", ltranspose },
		{ "inverse", linverse },
		{ "lookat", llookat },
		{ "lookto", llookto },
		{ "reciprocal", lreciprocal },
		{ "todirection", ltodirection },
		{ "torotation", ltorotation },
		{ "totable", ltotable},
		{ "base_axes", lbase_axes},
		{ "transform", ltransform},
		{ "transformH", ltransform_homogeneous_point },
		{ "projmat", lprojmat },
		{ "homogeneous_depth", lhomogeneous_depth },
		{ NULL, NULL },
	};

	luaL_newlibtable(L,l);
	lua_pushlightuserdata(L, bs->LS);
	luaL_setfuncs(L,l,1);

	luaL_Reg ref_mt[] = {
		{ "__newindex", lref_setter },
		{ "__index", lref_getter },
		{ "__tostring", lref_tostring },
		{ "__gc", lref_gc },
		{ NULL, NULL },
	};

	lua_pushlightuserdata(L, bs->LS);

	luaL_newlibtable(L,ref_mt);
	lua_pushlightuserdata(L, bs->LS);
	luaL_setfuncs(L,ref_mt,1);

	lua_pushcclosure(L, lref, 2);
	lua_setfield(L, -2, "ref");

	return 1;
}

// util function

const float *
math3d_from_lua(lua_State *L, struct lastack *LS, int index, int type) {
	switch(type) {
	case LINEAR_TYPE_MAT:
		return matrix_from_index(L, LS, index);
	case LINEAR_TYPE_VEC4:
		return vector_from_index(L, LS, index);
	case LINEAR_TYPE_QUAT:
		return quat_from_index(L, LS, index);
	default:
		luaL_error(L, "Invalid math3d object type %d", type);
	}
	return NULL;
}

const float *
math3d_from_lua_id(lua_State *L, struct lastack *LS, int index, int *type) {
	int64_t id = get_id(L, index, lua_type(L, index));
	*type = LINEAR_TYPE_NONE;
	return lastack_value(LS, id, type);
}
