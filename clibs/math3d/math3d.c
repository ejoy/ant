#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include <float.h>

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
static int g_origin_bottom_left = 0;

static size_t
getlen(lua_State *L, int index) {
	lua_len(L, index);
	if (lua_isinteger(L, -1)) {
		size_t len = lua_tointeger(L, -1);
		lua_pop(L, 1);
		return len;
	}
	return luaL_error(L, "lua_len returns %s", lua_typename(L, lua_type(L, -1)));
}

int
math3d_homogeneous_depth() {
	return g_default_homogeneous_depth;
}

int
math3d_origin_bottom_left(){
	return g_origin_bottom_left;
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
	return math3d_getLS(L);
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

static const void *
refobj_meta(lua_State *L) {
	struct boxstack *bs = lua_touserdata(L, lua_upvalueindex(1));
	return bs->refmeta;
}

static int64_t
get_id(lua_State *L, int index, int ltype) {
	if (ltype == LUA_TLIGHTUSERDATA) {
		return (int64_t)lua_touserdata(L, index);
	} else if (lua_getmetatable(L, index) && lua_topointer(L, -1) == refobj_meta(L)) {
		lua_pop(L, 1);	// pop metatable
		struct refobject * ref = lua_touserdata(L, index);
		return ref->id;
	}
	return luaL_argerror(L, index, "Need ref userdata");
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
unpack_numbers(lua_State *L, int index, float *v, size_t n) {
	size_t i;
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
	size_t n = getlen(L, index);
	if (n != 3 && n != 4)
		return luaL_error(L, "Vector need a array of 3/4 (%d)", n);
	float *v = lastack_allocvec4(LS);
	v[3] = 1.0f;
	unpack_numbers(L, index, v, n);
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
	size_t n = getlen(L, index);
	if (n == 0) {
		if (quat_from_axis(L, LS, index, "axis"))
			return luaL_error(L, "Quat invalid arguments");
	} else if (n == 3) {
		float e[3];
		unpack_numbers(L, index, e, 3);
		math3d_make_quat_from_euler(LS, e[0], e[1], e[2]);
	} else if (n == 4) {
		float *v = lastack_allocquat(LS);
		unpack_numbers(L, index, v, 4);
	} else {
		return luaL_error(L, "Quat need a array of 4 (quat) or 3 (eular), it's (%d)", n);
	}
	return lastack_pop(LS);
}


static int64_t
matrix_from_table(lua_State *L, struct lastack *LS, int index) {
	size_t n = getlen(L, index);
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
		float *v = lastack_allocmatrix(LS);
		unpack_numbers(L, index, v, 16);
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
	math3d_decompose_rot(mat, quat);
	math3d_make_srt(LS, scale, quat, trans);
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
	float *mat = lastack_allocmatrix(LS);
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
	return lastack_mark(LS, lastack_pop(LS));
}

static void
set_index_object(lua_State *L, struct lastack *LS, int64_t id);

static int
ref_set_number(lua_State *L){
	struct refobject *R = lua_touserdata(L, 1);
	struct lastack *LS = GETLS(L);
	const int64_t oid = R->id;

	set_index_object(L, LS, oid);
	R->id = lastack_mark(LS, lastack_pop(LS));
	lastack_unmark(LS, oid);
	return 0;
}

static int
ref_set_key(lua_State *L){
	struct refobject *R = lua_touserdata(L, 1);
	const char *key = luaL_checkstring(L, 2);
	struct lastack *LS = GETLS(L);
	int64_t oid = R->id;
	switch(key[0]) {
	case 'i': { // value id
		int64_t nid = get_id(L, 3, lua_type(L, 3));
		if (nid != oid) {
			R->id = lastack_mark(LS, nid);
		} else {
			// do not unmark oid
			return 0;
		}
		break; }
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
	lastack_unmark(LS, oid);
	return 0;
}

static int
lref_setter(lua_State *L) {
	int type = lua_type(L, 2);
	switch (type) {
	case LUA_TNUMBER:
		return ref_set_number(L);
	case LUA_TSTRING:
		return ref_set_key(L);
	default:
		return luaL_error(L, "Invalid key type %s", lua_typename(L, type));
	}
}

static void
to_table(lua_State *L, struct lastack *LS, int64_t id, int needtype) {
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
	if (needtype){
		lua_pushstring(L, lastack_typename(type));
		lua_setfield(L, -2, "type");
	}
}

static int64_t
extract_srt(struct lastack *LS, const float *mat, int what) {
	float *v;
	switch(what) {
	case 's':
		v = lastack_allocvec4(LS);
		math3d_decompose_scale(mat, v);
		break;
	case 'r':
		v = lastack_allocquat(LS);
		math3d_decompose_rot(mat, v);
		break;
	case 't':
		v = lastack_allocvec4(LS);
		v[0] = mat[3*4+0];
		v[1] = mat[3*4+1];
		v[2] = mat[3*4+2];
		v[3] = 1;
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
		to_table(L, LS, R->id, 1);
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
		case 1: {
			int ltype = lua_type(L, 1);
			struct lastack *LS = GETLS(L);
			if (ltype == LUA_TTABLE) {
				id = from_table(L, LS, 1);
			} else {
				id = get_id(L,1,ltype);
				if (lastack_type(LS, id) != type) {
					return luaL_error(L, "type mismatch %s %s", lastack_typename(type), lastack_type(LS, id));
				}
			}
			break; }
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
	int64_t id = get_id(L, index, lua_type(L, index));
	const float * v = lastack_value(LS, id, type);
	if (v == NULL)
		luaL_error(L, "Invalid id at stack %d", index);
	return v;
}

static const float *
vector_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * v = object_from_index(L, LS, index, LINEAR_TYPE_VEC4, vector_from_table);
	if (v == NULL)
		luaL_error(L, "Need a vector");
	return v;
}

static float *
alloc_vec4(lua_State *L, struct lastack *LS) {
	float * v = lastack_allocvec4(LS);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return v;
}

static int
ladd(lua_State *L) {
	struct lastack *LS = GETLS(L);
	int i;
	int top = lua_gettop(L);
	if (top < 2) {
		return luaL_error(L, "Need 2 or more vectors");
	}
	float *tmp = alloc_vec4(L, LS);
	const float *lv = vector_from_index(L, LS, 1);
	for (i=2;i<=top;i++) {
		const float *rv = vector_from_index(L, LS, 2);
		math3d_add_vec(LS, lv, rv, tmp);
		lv = tmp;
	}
	return 1;
}

static int
lsub(lua_State *L) {
	struct lastack *LS = GETLS(L);
	float *tmp = alloc_vec4(L, LS);
	const float *v0 = vector_from_index(L, LS, 1);
	const float *v1 = vector_from_index(L, LS, 2);
	math3d_sub_vec(LS, v0, v1, tmp);

	return 1;
}



static const float *
get_vec_or_number(lua_State *L, struct lastack *LS, int index, float tmp[4]) {
	if (lua_type(L, index) == LUA_TNUMBER) {
		tmp[0] = lua_tonumber(L, index);
		tmp[1] = tmp[0];
		tmp[2] = tmp[0];
		tmp[3] = tmp[0];
		return tmp;
	} else {
		return vector_from_index(L, LS, index);
	}
}

static int
lmuladd(lua_State *L) {
	struct lastack *LS = GETLS(L);
	float n1[4];
	float n2[4];
	const float *v0 = get_vec_or_number(L, LS, 1, n1);
	const float *v1 = get_vec_or_number(L, LS, 2, n2);
	const float *v2 = vector_from_index(L, LS, 3);

	float *result = lastack_allocvec4(LS);
	void *result_id = STACKID(lastack_pop(LS));
	math3d_mul_vec4(LS, v0, v1, result);
	math3d_add_vec(LS, result, v2, result);

	lua_pushlightuserdata(L, result_id);
	return 1;
}

static const float *
matrix_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * m = object_from_index(L, LS, index, LINEAR_TYPE_MAT, matrix_from_table);
	if (m == NULL)
		luaL_error(L, "Need a matrix");
	return m;
}

static const float *
quat_from_index(lua_State *L, struct lastack *LS, int index) {
	const float * q = object_from_index(L, LS, index, LINEAR_TYPE_QUAT, quat_from_table);
	if (q == NULL)
		luaL_error(L, "Need a quat");
	return q;
}

static int
lindex(lua_State *L) {
	int64_t id = get_id(L, 1, lua_type(L, 1));
	int idx = luaL_checkinteger(L, 2);
	return index_object(L, GETLS(L), id, idx);
}

static void
set_index_object(lua_State *L, struct lastack *LS, int64_t id){
	int type;
	const float * v = lastack_value(LS, id, &type);
	if (v == NULL) {
		luaL_error(L, "Invalid ref object");
		return;
	}

	int idx = luaL_checkinteger(L, 2);
	if (idx < 1 || idx > 4) {
		luaL_error(L, "Invalid index %d", idx);
		return;
	}
	--idx;

	switch (type)
	{
	case LINEAR_TYPE_MAT:{
		const float* nv = vector_from_index(L, LS, 3);
		float vv[16]; memcpy(vv, v, sizeof(vv));
		memcpy(vv + idx * 4, nv, sizeof(float) * 4);
		lastack_pushmatrix(LS, vv);
	}
		break;
	case LINEAR_TYPE_VEC4:
	case LINEAR_TYPE_QUAT:{
		float vv[4]; memcpy(vv, v, sizeof(vv));
		vv[idx] = luaL_checknumber(L, 3);
		lastack_pushvec4(LS, vv);
	}
		break;
	default:
		luaL_error(L, "invalid data type:%s", lastack_typename(type));
	}
}


static int
lset_index(lua_State *L){
	struct lastack *LS  = GETLS(L);
	int64_t id = get_id(L, 1, lua_type(L, 1));

	set_index_object(L, LS, id);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lmul(lua_State *L) {
	struct lastack *LS = GETLS(L);
	if (lua_isnumber(L, 1)) {
		// number * vertex
		float r[4];
		r[0] = lua_tonumber(L, 1);
		r[1] = r[0];
		r[2] = r[0];
		r[3] = r[0];
		math3d_mul_vec4(LS, r, vector_from_index(L, LS, 2), lastack_allocvec4(LS));
	} else {
		int type;
		const float *lv = get_object(L, LS, 1, &type);
		switch (type) {
		case LINEAR_TYPE_MAT:
			math3d_mul_matrix(LS, lv, matrix_from_index(L, LS, 2), lastack_allocmatrix(LS));
			break;
		case LINEAR_TYPE_QUAT:
			math3d_mul_quat(LS, lv, quat_from_index(L, LS, 2), lastack_allocquat(LS));
			break;
		case LINEAR_TYPE_VEC4:
			if (lua_isnumber(L, 2)) {
				float r[4];
				r[0] = lua_tonumber(L, 2);
				r[1] = r[0];
				r[2] = r[0];
				r[3] = r[0];
				math3d_mul_vec4(LS, lv, r, lastack_allocvec4(LS));
			} else {
				math3d_mul_vec4(LS, lv, vector_from_index(L, LS, 2), lastack_allocvec4(LS));
			}
			break;
		default:
			return luaL_error(L, "Invalid mul arguments %s or quaternion mul vector should use 'transform' function", lastack_typename(type));
		}
	}

	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
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
		struct lastack *LS = GETLS(L);
		int64_t id = get_id(L, 1, lua_type(L, 1));
		int type;
		const float * quat = lastack_value(LS, id, &type);
		if (quat && type == LINEAR_TYPE_QUAT) {
			math3d_quat_to_matrix(LS, quat);
			lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
			return 1;
		}
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
		if (!lua_isuserdata(L, 1)) {
			return luaL_error(L, "Should be (vector id , number)");
		}
		int64_t id = get_id(L, 1, lua_type(L, 1));
		int type;
		const float *vec3 = lastack_value(LS, id, &type);
		if (vec3 == NULL || type != LINEAR_TYPE_VEC4) {
			return luaL_error(L, "Need a vector, it's %s", vec3 == NULL? "Invalid" : lastack_typename(id));
		}
		float n4 = luaL_checknumber(L, 2);
		if (n4 == vec3[3]) {
			lua_pushlightuserdata(L, STACKID(id));
		} else {
			float *vec4 = alloc_vec4(L, LS);
			vec4[0] = vec3[0];
			vec4[1] = vec3[1];
			vec4[2] = vec3[2];
			vec4[3] = n4;
		}
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
	int type;
	const float *mat = get_object(L, LS, 1, &type);
	if (type != LINEAR_TYPE_MAT || mat == NULL){
		luaL_error(L, "invalid type:%s", lastack_typename(type));
	}
	math3d_decompose_matrix(LS, mat);
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
		float *iv = lastack_allocvec4(LS);
		iv[0] = -v[0];
		iv[1] = -v[1];
		iv[2] = -v[2];
		iv[3] = v[3];
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
linverse_fast(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float * mat = matrix_from_index(L, LS, 1);
	math3d_inverse_matrix_fast(LS, mat);

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
	to_table(L, LS, id, 1);
	return 1;
}

static int
ltovalue(lua_State *L){
	struct lastack *LS = GETLS(L);
	int64_t id = get_id(L, 1, lua_type(L, 1));
	to_table(L, LS, id, 0);
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
	float tmp[4];
	if (!lua_isnil(L, 3)){
		const float p = luaL_checknumber(L, 3);
		if (p != v[3]) {
			tmp[0] = v[0];
			tmp[1] = v[1];
			tmp[2] = v[2];
			tmp[3] = p;
			v = tmp;
		}
	}

	int type;
	const float *rotator = (const float *)lastack_value(LS, rotatorid, &type);
	if (rotator == NULL) {
		return luaL_error(L, "Invalid rotator id");
	}

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
lminmax(lua_State *L){
	struct lastack *LS = GETLS(L);

	luaL_checktype(L, 1, LUA_TTABLE);
	const int numpoints = (int)getlen(L, 1);

	const float* transform = lua_isnoneornil(L, 2) ? NULL : matrix_from_index(L, LS, 2);

	lastack_preallocfloat4(LS, 2);

	float *minv = alloc_vec4(L, LS);
	minv[0] = FLT_MAX;
	minv[1] = FLT_MAX;
	minv[2] = FLT_MAX;
	minv[3] = FLT_MAX;

	float *maxv = alloc_vec4(L, LS);
	maxv[0] = -FLT_MAX;
	maxv[1] = -FLT_MAX;
	maxv[2] = -FLT_MAX;
	maxv[3] = -FLT_MAX;

	for (int ii = 0; ii < numpoints; ++ii){
		lua_geti(L, 1, ii+1);
		const float *v = vector_from_index(L, LS, -1);
		lua_pop(L, 1);
		math3d_minmax(LS, transform, v, minv, maxv);
	}

	return 2;
}

static int
llerp(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *v0 = vector_from_index(L, LS, 1);
	const float *v1 = vector_from_index(L, LS, 1);

	const float ratio = luaL_checknumber(L, 3);

	float *r = alloc_vec4(L, LS);

	math3d_lerp(LS, v0, v1, ratio, r);
	return 1;
}

static int
lmatrix_scale(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *m = matrix_from_index(L, LS, 1);
	float *scale = lastack_allocvec4(LS);
	math3d_decompose_scale(m, scale);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lstacksize(lua_State *L) {
	struct lastack *LS = GETLS(L);
	lua_pushinteger(L, lastack_size(LS));
	return 1;
}

static int
lset_homogeneous_depth(lua_State *L){
	g_default_homogeneous_depth = lua_toboolean(L, 1) ? 1 : 0;
	return 0;
}

static int
lset_origin_bottom_left(lua_State *L){
	g_origin_bottom_left = lua_toboolean(L, 1) ? 1 : 0;
	return 0;
}

static int
lpack(lua_State *L) {
	size_t sz;
	const char * format = luaL_checklstring(L, 1, &sz);
	int n = lua_gettop(L);
	int i;
	if (n != 5 && n != 17) {
		return luaL_error(L, "need 5 or 17 arguments , it's %d", n);
	}
	--n;
	if (n != sz) {
		return luaL_error(L, "Invalid format %s", format);
	}
	union {
		float f[16];
		uint32_t n[16];
	} u;
	for (i=0;i<n;i++) {
		switch(format[i]) {
		case 'f':
			u.f[i] = luaL_checknumber(L, i+2);
			break;
		case 'd':
			u.n[i] = luaL_checkinteger(L, i+2);
			break;
		default:
			return luaL_error(L, "Invalid format %s", format);
		}
	}
	struct lastack *LS = GETLS(L);
	if (n == 4) {
		lastack_pushvec4(LS, u.f);
	} else {
		lastack_pushmatrix(LS, u.f);
	}
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static int
lisvalid(lua_State *L){
	struct lastack *LS = GETLS(L);
	int type;
	int64_t id = get_id(L, 1, lua_type(L, 1));
	const float * v = lastack_value(LS, id, &type);
	lua_pushboolean(L, v != NULL);
	return 1;
}

static int
lquat2euler(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *q = quat_from_index(L, LS, 1);
	float *euler = alloc_vec4(L, LS);

	math3d_quat_to_euler(LS, q, euler);

	return 1;
}

// input: view direction vector
// output: 
//		output radianX and radianY which can used to create quaternion that around x-axis and y-axis, 
//		multipy those quaternions can recreate view direction vector
static int
ldir2radian(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float* v = vector_from_index(L, LS, 1);
	float radians[2];
	math3d_dir2radian(LS, v, radians);
	lua_pushnumber(L, radians[0]);
	lua_pushnumber(L, radians[1]);
	return 2;
}

static int
lforward_dir(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *mat = matrix_from_index(L, LS, 1);
	const float v[4] = {0, 0, 1, 0};
	math3d_rotmat_transform(LS, mat, v);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return 1;
}

static inline void
init_aabb(float *aabb, const float *oriaabb){
	if (oriaabb){
		memcpy(aabb, oriaabb, sizeof(float) * 8);	// matrix col0 and col1 is min and max value
	} else {
		memset(aabb, 0, sizeof(float) * 16);
		for (int ii = 0; ii < 3; ++ii){
			aabb[ii] = FLT_MAX;
			aabb[ii+4] = -FLT_MAX;
		}
	}
}

static inline float *
alloc_aabb(lua_State *L, struct lastack *LS) {
	float *aabb = lastack_allocmatrix(LS);
	lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));
	return aabb;
}

static inline int
generate_aabb(lua_State *L, struct lastack *LS, const float *oriaabb){
	const int num = lua_gettop(L);
	float *aabb = alloc_aabb(L, LS);
	init_aabb(aabb, oriaabb);

	for (int ii = 0; ii < num; ++ii){
		const float *v = vector_from_index(L, LS, ii+1);
		math3d_aabb_append(LS, v, aabb);
	}

	return 1;
}

static int
laabb(lua_State *L){
	struct lastack *LS = GETLS(L);
	generate_aabb(L, LS, NULL);
	return 1;
}

static int
laabb_isvalid(lua_State *L){
	struct lastack *LS = GETLS(L);
	lua_pushboolean(L, math3d_aabb_isvalid(LS, matrix_from_index(L, LS, 1)));
	return 1;
}

static int
laabb_append(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *aabb = matrix_from_index(L, LS, 1);
	lua_remove(L, 1);
	generate_aabb(L, LS, aabb);
	return 1;
}

static int
laabb_merge(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *lhsaabb = matrix_from_index(L, LS, 1);
	const float *rhsaabb = matrix_from_index(L, LS, 1);
	float *aabb = alloc_aabb(L, LS);
	math3d_aabb_merge(LS, lhsaabb, rhsaabb, aabb);

	return 1;
}

// 1 : worldmat
// 2 : aabb (can be nil)
// 3 : srtmat (can be nil)
// return 1: aabb (nil if input aabb is nil)
// return 2: worldmat
static int
laabb_transform(lua_State *L) {
	struct lastack *LS = GETLS(L);
	const float * worldmat = matrix_from_index(L, LS, 1);
	const float * aabb = object_from_index(L, LS, 2, LINEAR_TYPE_MAT, matrix_from_table);
	const float * srt = object_from_index(L, LS, 3, LINEAR_TYPE_MAT, matrix_from_table);
	if (srt == NULL && aabb == NULL) {
		lua_pushnil(L);
		lua_pushvalue(L, 1);
		return 2;	// returns nil, worldmat
	}
	void * result_matid = NULL;
	if (srt) {
		float *mat = lastack_allocmatrix(LS);
		result_matid = STACKID(lastack_pop(LS));
		math3d_mul_matrix(LS, worldmat, srt, mat);
		worldmat = mat;
	}
	if (aabb) {
		float *aabb_result = lastack_allocmatrix(LS);
		lua_pushlightuserdata(L, STACKID(lastack_pop(LS)));

		math3d_aabb_transform(LS, worldmat, aabb, aabb_result);
	} else {
		lua_pushnil(L);
	}
	if (result_matid) {
		lua_pushlightuserdata(L, result_matid);
	} else {
		lua_pushvalue(L, 1);
	}
	return 2;
}

static int
laabb_center_extents(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *aabb = matrix_from_index(L, LS, 1);
	lastack_preallocfloat4(LS, 2);
	float *center = alloc_vec4(L, LS);
	float *extents= alloc_vec4(L, LS);
	math3d_aabb_center_extents(LS, aabb, center, extents);

	return 2;
}

static int
laabb_intersect_plane(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *aabb = matrix_from_index(L, LS, 1);
	const float *plane = vector_from_index(L, LS, 2);

	lua_pushinteger(L, math3d_aabb_intersect_plane(LS, aabb, plane));
	return 1;
}

//frustum
static int
lfrustum_planes(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *m = matrix_from_index(L, LS, 1);
	float *planes[6];
	int i;
	lua_createtable(L, 6, 0);
	lastack_preallocfloat4(LS, 6);
	for (i=0;i<6;i++) {
		planes[i] = alloc_vec4(L, LS);
		lua_seti(L, -2, i+1);
	}
	math3d_frustum_planes(LS, m, planes);

	return 1;
}

static inline void
fetch_vectors_from_table(lua_State *L, struct lastack *LS, int index, int checknum, const float** vectors){
	const size_t num = getlen(L, index);
	if (num != checknum){
		luaL_error(L, "table need contain %d planes:%d", checknum, num);
	}
	for (int ii = 0; ii < num; ++ii){
		lua_geti(L, index, ii+1);
		vectors[ii] = vector_from_index(L, LS, -1);
		lua_pop(L, 1);
	}
}

static inline void
fetch_frustum_planes(lua_State *L, struct lastack *LS, int index, const float* planes[6]){
	fetch_vectors_from_table(L, LS, index, 6, planes);
}

static inline void
fetch_frustum_points(lua_State *L, struct lastack *LS, int index, const float *points[8]){
	fetch_vectors_from_table(L, LS, index, 8, points);
}

static int
lfrustum_intersect_aabb(lua_State *L){
	struct lastack *LS = GETLS(L);
	luaL_checktype(L, 1, LUA_TTABLE);
	const float* planes[6];
	fetch_frustum_planes(L, LS, 1, planes);

	const float* aabb = matrix_from_index(L, LS, 2);
	lua_pushinteger(L, math3d_frustum_intersect_aabb(LS, planes, aabb));
	return 1;
}

static int
lfrustum_intersect_aabb_list(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float* planes[6];
	fetch_frustum_planes(L, LS, 1, planes);

	const int resultidx = lua_gettop(L)+1;
	lua_newtable(L);

	int haselem = 0;
	lua_pushnil(L);
	while (lua_next(L, 2) != 0){
		//	table: eid=value
		//		value: {aabb=...}
		const lua_Integer eid = lua_tointeger(L, -2);	//table key

		const float * aabb = (LUA_TNIL != lua_getfield(L, -1, "aabb")) ?
			object_from_index(L, LS, -1, LINEAR_TYPE_MAT, matrix_from_table) : NULL;
		lua_pop(L, 1);

		if (aabb == NULL || math3d_frustum_intersect_aabb(LS, planes, aabb) >= 0){
			lua_pushvalue(L, -1);	//-1 is table value
			lua_seti(L, resultidx, eid);
			haselem = 1;
		}

		lua_pop(L, 1);
	}

	return haselem;
}

static int
lfrustum_points(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *m = matrix_from_index(L, LS, 1);

	lua_createtable(L, 8, 0);
	float *points[8];
	int i;
	lastack_preallocfloat4(LS, 8);
	for (i=0;i<8;i++) {
		points[i] = alloc_vec4(L, LS);
		lua_seti(L, -2, i+1);
	}
	math3d_frustum_points(LS, m, points);
	return 1;
}

static int
lfrustum_aabb(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *points[8];
	fetch_frustum_points(L, LS, 1, points);

	float *aabb = alloc_aabb(L, LS);
	math3d_frusutm_aabb(LS, points, aabb);

	return 1;
}

static int
lfrustum_center(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *points[8];
	fetch_frustum_points(L, LS, 1, points);
	float *center = alloc_vec4(L, LS);
	math3d_frustum_center(LS, points, center);

	return 1;
}

static int
lfrustum_max_radius(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *points[8];
	fetch_frustum_points(L, LS, 1, points);

	const float *center = vector_from_index(L, LS, 2);
	lua_pushnumber(L, math3d_frustum_max_radius(LS, points, center));
	return 1;
}

static int
lfrustum_calc_near_far(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float* planes[6];
	fetch_frustum_planes(L, LS, 1, planes);

	float nearfar[2];
	math3d_frustum_calc_near_far(LS, planes, nearfar);
	lua_pushnumber(L, nearfar[0]);
	lua_pushnumber(L, nearfar[1]);
	return 2;
}

static int
lpoint2plane(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float *pt = vector_from_index(L, LS, 1);
	const float *plane = vector_from_index(L, LS, 2);

	lua_pushnumber(L, math3d_point2plane(LS, pt, plane));
	return 1;
}

static void
init_math3d_api(lua_State *L, struct boxstack *bs) {
		luaL_Reg l[] = {
		{ "ref", NULL },
		{ "tostring", ltostring },
		{ "matrix", lmatrix },
		{ "vector", lvector },
		{ "quaternion", lquaternion },
		{ "index", lindex },
		{ "set_index", lset_index},
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
		{ "inverse_fast", linverse_fast},
		{ "lookat", llookat },
		{ "lookto", llookto },
		{ "reciprocal", lreciprocal },
		{ "todirection", ltodirection },
		{ "torotation", ltorotation },
		{ "totable", ltotable},
		{ "tovalue", ltovalue},
		{ "base_axes", lbase_axes},
		{ "transform", ltransform},
		{ "transformH", ltransform_homogeneous_point },
		{ "projmat", lprojmat },
		{ "minmax", lminmax},
		{ "lerp", llerp},
		{ "matrix_scale", lmatrix_scale},
		{ "quat2euler", lquat2euler},
		{ "dir2radian", ldir2radian},
		{ "forward_dir",lforward_dir},
		{ "stacksize", lstacksize},
		{ "set_homogeneous_depth", lset_homogeneous_depth},
		{ "set_origin_bottom_left", lset_origin_bottom_left},
		{ "pack", lpack },
		{ "isvalid", lisvalid},

		//aabb
		{ "aabb", laabb},
		{ "aabb_isvalid", laabb_isvalid},
		{ "aabb_append", laabb_append},
		{ "aabb_merge", laabb_merge},
		{ "aabb_transform", laabb_transform},
		{ "aabb_center_extents", laabb_center_extents},
		{ "aabb_intersect_plane", laabb_intersect_plane},

		//frustum
		{ "frustum_planes", 		lfrustum_planes},
		{ "frustum_intersect_aabb", lfrustum_intersect_aabb},
		{ "frustum_intersect_aabb_list", lfrustum_intersect_aabb_list},
		{ "frustum_points", 		lfrustum_points},
		{ "frustum_aabb",			lfrustum_aabb},
		{ "frustum_center",			lfrustum_center},
		{ "frustum_max_radius",		lfrustum_max_radius},
		{ "frustum_calc_near_far",  lfrustum_calc_near_far},

		//primitive
		{ "point2plane",	lpoint2plane},
		{ NULL, NULL },
	};

	luaL_newlibtable(L,l);
	lua_pushlightuserdata(L, bs);
	luaL_setfuncs(L,l,1);
}

LUAMOD_API int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg ref_mt[] = {
		{ "__newindex", lref_setter },
		{ "__index", lref_getter },
		{ "__tostring", lref_tostring },
		{ "__gc", lref_gc },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,ref_mt);
	int refmeta = lua_gettop(L);

	struct boxstack * bs = lua_newuserdatauv(L, sizeof(struct boxstack), 0);
	bs->LS = lastack_new();
	bs->refmeta = lua_topointer(L, refmeta);
	finalize(L, boxstack_gc);
	lua_setfield(L, LUA_REGISTRYINDEX, MATH3D_STACK);

	init_math3d_api(L, bs);

	lua_pushlightuserdata(L, bs);	// upvalue 1 of .ref

	// init reobject meta table, it's upvalue 2 of .ref
	lua_pushvalue(L, refmeta);
	lua_pushlightuserdata(L, bs);
	luaL_setfuncs(L,ref_mt, 1);

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
