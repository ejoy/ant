#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include <string.h>
#include <float.h>

#ifndef _MSC_VER
#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif
#endif // !_MSC_VER

#include "mathid.h"	
#include "math3d.h"
#include "math3dfunc.h"

#define MAT_PERSPECTIVE 0
#define MAT_ORTHO 1

struct refobject {
	math_t id;
};

static int g_default_homogeneous_depth = 0;
static int g_origin_bottom_left = 0;
int math3d_homogeneous_depth(){
	return g_default_homogeneous_depth;
}

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
math3d_origin_bottom_left(){
	return g_origin_bottom_left;
}

static inline math_t
HANDLE_TO_MATH(void *p) {
	math_t r;
	r.idx = (uint64_t)p;
	return r;
}

static inline void *
MATH_TO_HANDLE(math_t id) {
	return (void *)id.idx;
}

static inline math_t
LUAID(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TLIGHTUSERDATA);
	return HANDLE_TO_MATH(lua_touserdata(L, index));
}

static inline void
lua_pushmath(lua_State *L, math_t id) {
	lua_pushlightuserdata(L, MATH_TO_HANDLE(id));
}

static inline struct math_context *
GETMC(lua_State *L) {
	struct math3d_api *M = (struct math3d_api *)lua_touserdata(L, lua_upvalueindex(1));
	return M->MC;
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
	struct math3d_api *M = (struct math3d_api *)lua_touserdata(L, 1);
	if (M->MC) {
		math_delete(M->MC);
		M->MC = NULL;
	}
	return 0;
}

static const void *
refobj_meta(lua_State *L) {
	struct math3d_api *M = lua_touserdata(L, lua_upvalueindex(1));
	return M->refmeta;
}

static math_t
get_id_withtype(lua_State *L, struct math_context *M, int index, int ltype) {
	if (ltype == LUA_TLIGHTUSERDATA) {
		math_t id = HANDLE_TO_MATH(lua_touserdata(L, index));
		if (!math_valid(M, id)) {
			luaL_error(L, "Invalid math id");
		}
		return id;
	} else if (lua_getmetatable(L, index) && lua_topointer(L, -1) == refobj_meta(L)) {
		lua_pop(L, 1);	// pop metatable
		struct refobject * ref = lua_touserdata(L, index);
		return ref->id;
	}
	luaL_argerror(L, index, "Need ref userdata");
	return MATH_NULL;
}

static inline math_t
get_id(lua_State *L, struct math_context *M, int index) {
	return get_id_withtype(L, M, index, lua_type(L, index));
}

static math_t
get_id_api(lua_State *L, struct math_context *M, int index) {
	int ltype = lua_type(L, index);
	if (ltype == LUA_TLIGHTUSERDATA) {
		math_t id = HANDLE_TO_MATH(lua_touserdata(L, index));
		if (!math_valid(M, id)) {
			luaL_error(L, "Invalid math id");
		}
		return id;
	} else if (ltype == LUA_TUSERDATA) {
		if (lua_rawlen(L, index) != sizeof(struct refobject)) {
			luaL_argerror(L, index, "Invalid ref userdata");
		}
		struct refobject * ref = lua_touserdata(L, index);
		return ref->id;
	}
	luaL_argerror(L, index, "Need ref userdata");
	return MATH_NULL;
}

static int
lref(lua_State *L) {
	struct math_context *M = GETMC(L);
	lua_settop(L, 1);
	struct refobject * R = (struct refobject *)lua_newuserdatauv(L, sizeof(struct refobject), 0);
	if (lua_isnil(L, 1)) {
		R->id = MATH_NULL;
	} else {
		math_t id = get_id(L, M, 1);
		R->id = math_mark(M, id);
	}
	lua_pushvalue(L, lua_upvalueindex(2));
	lua_setmetatable(L, -2);
	return 1;
}

static int
lmark(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t id = get_id(L, M, 1);
	id = math_mark(M, id);
	lua_pushmath(L, id);
	return 1;
}

static int
lunmark(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	math_t id = HANDLE_TO_MATH(lua_touserdata(L, 1));
	math_unmark(GETMC(L), id);
	return 0;
}


// assign math id to refobject (mark it)
static math_t
assign_id(lua_State *L, struct math_context *M, int index, int mtype, int ltype) {
	switch (ltype) {
	case LUA_TNIL:
	case LUA_TNONE:
		// identity matrix
		return math_identity(mtype);
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA: {
		math_t id = get_id_withtype(L, M, index, ltype);
		int type = math_type(M, id);
		if (type != mtype) {
			if (mtype == MATH_TYPE_MAT && type == MATH_TYPE_QUAT) {
				id = math3d_quat_to_matrix(M, id);
			} else if (mtype == MATH_TYPE_QUAT && type == MATH_TYPE_MAT) {
				id = math3d_matrix_to_quat(M, id);
			} else {
				luaL_error(L, "%s type mismatch %s", math_typename(mtype), math_typename(type));
			}
		}
		return math_mark(M, id); }
	default:
		luaL_error(L, "Invalid type %s for %s ref", lua_typename(L, ltype), math_typename(mtype));
		break;
	}
	return MATH_NULL;
}

static void
unpack_numbers(lua_State *L, int index, float *v, size_t n) {
	size_t i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, index, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Need a number from index %d", i+1);
		}
		v[i] = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}

typedef math_t (*from_table_func)(lua_State *L, struct math_context *M, int index);

static math_t
vector_from_table(lua_State *L, struct math_context *M, int index) {
	size_t n = getlen(L, index);
	math_t id = math_vec4(M, NULL);
	float *v = math_init(M, id);
	if (n == 3) {
		v[3] = 1.0f;
	} else if (n != 4) {
		luaL_error(L, "Vector need a array of 3/4 (%d)", n);
	}
	unpack_numbers(L, index, v, n);
	return id;
}

static math_t
aabb_from_table(lua_State *L, struct math_context *M, int index) {
	size_t n = getlen(L, index);
	math_t id = math_import(M, NULL, MATH_TYPE_VEC4, 2);
	float *v = math_init(M, id);
	if (n != 6) {
		luaL_error(L, "AABB need a array of 6 (%d)", n);
	}
	unpack_numbers(L, index, v, n);
	v[7] = 0;
	v[6] = v[5];
	v[5] = v[4];
	v[4] = v[3];
	v[3] = 0;
	return id;
}

static math_t
object_from_index(lua_State *L, struct math_context *M, int index, int mtype, from_table_func from_table) {
	int ltype = lua_type(L, index);
	math_t result = MATH_NULL;
	switch(ltype) {
	case LUA_TNIL:
	case LUA_TNONE:
		break;
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA: {
		result = get_id_withtype(L, M, index, ltype);
		int type = math_type(M, result);
		if (type != mtype) {
			luaL_error(L, "Need a %s , it's a %s.", math_typename(mtype), math_typename(type));
		}
		break; }
	case LUA_TTABLE:
		result = from_table(L, M, index);
		break;
	default:
		luaL_error(L, "Invalid lua type %s", lua_typename(L, ltype));
	}
	return result;
}

static math_t
object_from_field(lua_State *L, struct math_context *M, int index, const char *key, int mtype, from_table_func from_table) {
	lua_getfield(L, index, key);
	math_t result = object_from_index(L, M, -1, mtype, from_table);
	lua_pop(L, 1);
	return result;
}

static math_t
quat_from_axis(lua_State *L, struct math_context *M, int index, const char *key) {
	if (lua_getfield(L, index, key) == LUA_TNIL) {
		luaL_error(L, "Quat invalid arguments");
	}

	math_t axis = object_from_index(L, M, -1, MATH_TYPE_VEC4, vector_from_table);
	lua_pop(L, 1);

	if (lua_getfield(L, index, "r") != LUA_TNUMBER) {
		luaL_error(L, "Need .r for quat");
	}
	float r = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);

	return math3d_make_quat_from_axis(M, axis, r);
}

static math_t
quat_from_table(lua_State *L, struct math_context *M, int index) {
	size_t n = getlen(L, index);
	if (n == 0) {
		return quat_from_axis(L, M, index, "axis");
	} else if (n == 3) {
		math_t tmp = math_vec4(M, NULL);
		float *e = math_init(M, tmp);
		unpack_numbers(L, index, e, 3);
		return math3d_make_quat_from_euler(M, tmp);
	} else if (n == 4) {
		math_t r = math_quat(M, NULL);
		float *v = math_init(M, r);
		unpack_numbers(L, index, v, 4);
		return r;
	} else {
		luaL_error(L, "Quat need a array of 4 (quat) or 3 (eular), it's (%d)", n);
		return MATH_NULL;
	}
}

static math_t
matrix_from_table(lua_State *L, struct math_context *M, int index) {
	size_t n = getlen(L, index);
	if (n == 0) {
		math_t s;
		if (lua_getfield(L, index, "s") == LUA_TNUMBER) {
			s = math_vec4(M, NULL);
			float *tmp = math_init(M, s);
			tmp[0] = (float)lua_tonumber(L, -1);
			tmp[1] = tmp[0];
			tmp[2] = tmp[0];
			tmp[3] = 0;
		} else {
			s = object_from_index(L, M, -1, MATH_TYPE_VEC4, vector_from_table);
		}
		lua_pop(L, 1);
		math_t q = object_from_field(L, M, index, "r", MATH_TYPE_QUAT, quat_from_table);
		math_t t = object_from_field(L, M, index, "t", MATH_TYPE_VEC4, vector_from_table);
		return math3d_make_srt(M,s,q,t);
	} else if (n != 16) {
		luaL_error(L, "Matrix need a array of 16 (%d)", n);
		return MATH_NULL;
	} else {
		math_t r = math_matrix(M, NULL);
		float *v = math_init(M, r);
		unpack_numbers(L, index, v, 16);
		return r;
	}
}

static math_t
assign_object(lua_State *L, struct math_context *M, int index, int mtype, from_table_func from_table) {
	int ltype = lua_type(L, index);
	if (ltype == LUA_TTABLE) {
		math_t id = from_table(L, M, index);
		return math_mark(M, id);
	}
	return assign_id(L, M, index, mtype, ltype);
}

static math_t
assign_matrix(lua_State *L, struct math_context *M, int index) {
	return assign_object(L, M, index, MATH_TYPE_MAT, matrix_from_table);
}

static math_t
assign_vector(lua_State *L, struct math_context *M, int index) {
	return assign_object(L, M, index, MATH_TYPE_VEC4, vector_from_table);
}

static math_t
assign_quat(lua_State *L, struct math_context *M, int index) {
	return assign_object(L, M, index, MATH_TYPE_QUAT, quat_from_table);
}

static int
ref_set_key(lua_State *L){
	struct refobject *R = lua_touserdata(L, 1);
	const char *key = luaL_checkstring(L, 2);
	struct math_context *M = GETMC(L);
	math_t oid = R->id;
	switch(key[0]) {
	case 'v':	// should be vector
		R->id = assign_vector(L, M, 3);
		break;
	case 'q':	// should be quat
		R->id = assign_quat(L, M, 3);
		break;
	case 'm':	// should be matrix
		R->id = assign_matrix(L, M, 3);
		break;
	default:
		return luaL_error(L, "Invalid set key %s with ref object", key); 
	}
	math_unmark(M, oid);
	return 0;
}

static math_t set_index_object(lua_State *L, struct math_context *M, math_t id);

static int
ref_set_number(lua_State *L){
	struct refobject *R = lua_touserdata(L, 1);
	struct math_context *M = GETMC(L);
	math_t oid = R->id;

	R->id = math_mark(M, set_index_object(L, M, oid));
	math_unmark(M, oid);

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
to_table(lua_State *L, struct math_context *M, math_t id, int needtype) {
	if (!math_valid(M, id)) {
		luaL_error(L, "Invalid math id");
	}
	const float * v = math_value(M, id);
	if (v == NULL) {
		lua_pushnil(L);
		return;
	}
	int type = math_type(M, id);
	int n = 4;
	if (type == MATH_TYPE_MAT)
		n = 16;
	int i;
	lua_createtable(L, n, 1);
	for (i=0;i<n;i++) {
		lua_pushnumber(L, v[i]);
		lua_rawseti(L, -2, i+1);
	}
	if (needtype){
		lua_pushstring(L, math_typename(type));
		lua_setfield(L, -2, "type");
	}
}

static math_t
extract_srt(struct math_context *M, math_t mat, int what) {
	switch(what) {
	case 's':
		return math3d_decompose_scale(M, mat);
	case 'r':
		return math3d_decompose_rot(M, mat);
	case 't':
		return math_vec4(M, &math_value(M, mat)[3*4]);
	default:
		return MATH_NULL;
	}
}

static int
ref_get_key(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	struct math_context * M = GETMC(L);
	const char *key = lua_tostring(L, 2);
	switch(key[0]) {
	case 'i':
		lua_pushmath(L, R->id);
		break;
	case 'p':
		lua_pushlightuserdata(L, math_init(M, R->id));
		break;
	case 'v':
		to_table(L, M, R->id, 1);
		break;
	case 's':
	case 'r':
	case 't': {
		if (math_type(M, R->id) != MATH_TYPE_MAT) {
			return luaL_error(L, "Not a matrix");
		}
		lua_pushmath(L, extract_srt(M, R->id, key[0]));
		break; }
	default:
		return luaL_error(L, "Invalid get key %s with ref object", key); 
	}
	return 1;
}

static int
index_object(lua_State *L, struct math_context *M, math_t id, int idx) {
	const float * v = math_value(M, id);
	int type = math_type(M, id);
	if (idx < 1 || idx > 4) {
		return luaL_error(L, "Invalid index %d", idx);
	}
	--idx;
	switch (type) {
	case MATH_TYPE_MAT:
		lua_pushmath(L, math_vec4(M, &v[idx * 4]));
		break;
	case MATH_TYPE_VEC4:
		lua_pushnumber(L, v[idx]);
		break;
	case MATH_TYPE_QUAT:
		lua_pushnumber(L, v[idx]);
		break;
	default:
		luaL_error(L, "Invalid math type %s", math_typename(type));
		return 0;
	}
	return 1;
}

static int
ref_get_number(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	struct math_context *M = GETMC(L);
	int idx = (int)lua_tointeger(L, 2);
	return index_object(L, M, R->id, idx);
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
id_tostring(lua_State *L, math_t id) {
	struct math_context *M = GETMC(L);
	const float * v = math_value(M, id);
	int type = math_type(M, id);
	int size = math_size(M, id);
	switch (type) {
	case MATH_TYPE_MAT:
		if (size == 1) {
			lua_pushfstring(L, "MAT (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
				v[0],v[1],v[2],v[3],
				v[4],v[5],v[6],v[7],
				v[8],v[9],v[10],v[11],
				v[12],v[13],v[14],v[15]);
		} else {
			lua_pushfstring(L, "MAT[%d]", size);
			int i;
			for (i=0;i<size;i++) {
				lua_pushfstring(L, " (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
					v[0],v[1],v[2],v[3],
					v[4],v[5],v[6],v[7],
					v[8],v[9],v[10],v[11],
					v[12],v[13],v[14],v[15]);
				v += 16;
			}
			lua_concat(L, size+1);
		}
		break;
	case MATH_TYPE_VEC4:
		if (size == 1) {
			lua_pushfstring(L, "VEC4 (%f,%f,%f,%f)",
				v[0], v[1], v[2], v[3]);
		} else {
			lua_pushfstring(L, "VEC4[%d]", size);
			int i;
			for (i=0;i<size;i++) {
				lua_pushfstring(L, " (%f,%f,%f,%f)",
					v[0], v[1], v[2], v[3]);
				v += 4;
			}
			lua_concat(L, size+1);
		}
		break;
	case MATH_TYPE_QUAT:
		if (size == 1) {
			lua_pushfstring(L, "QUAT (%f,%f,%f,%f)",
				v[0], v[1], v[2], v[3]);
		} else {
			lua_pushfstring(L, "QUAT[%d]", size);
			int i;
			for (i=0;i<size;i++) {
				lua_pushfstring(L, " (%f,%f,%f,%f)",
					v[0], v[1], v[2], v[3]);
				v += 4;
			}
			lua_concat(L, size+1);
		}
		break;
	case MATH_TYPE_NULL:
		lua_pushstring(L, "NULL");
		break;
	default:
		lua_pushstring(L, "UNKNOWN");
		break;
	}
	return 1;
}

static int
lref_tostring(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	return id_tostring(L, R->id);
}

static int
ltostring(lua_State *L) {
	math_t id = get_id(L, GETMC(L), 1);
	return id_tostring(L, id);
}

static int
lref_gc(lua_State *L) {
	struct refobject *R = lua_touserdata(L, 1);
	math_unmark(GETMC(L), R->id);
	R->id = MATH_NULL;
	return 0;
}

static math_t
new_object_(lua_State *L, int type, from_table_func from_table, int narray) {
	int argn = lua_gettop(L);
	math_t id;
	if (argn == narray) {
		int i;
		float tmp[16];
		struct math_context *M = GETMC(L);
		for (i=0;i<argn;i++) {
			tmp[i] = (float)luaL_checknumber(L, i+1);
		}
		id = math_import(M, tmp, type, 1);
	} else {
		switch(argn) {
		case 0:
			id = math_identity(type);
			break;
		case 1: {
			int ltype = lua_type(L, 1);
			struct math_context *M = GETMC(L);
			if (ltype == LUA_TTABLE) {
				id = from_table(L, M, 1);
			} else {
				id = get_id_withtype(L, M, 1,ltype);
				if (math_type(M, id) != type) {
					luaL_error(L, "type mismatch %s %s", math_typename(type), math_typename(math_type(M, id)));
				}
			}
			break; }
		default:
			luaL_error(L, "Invalid %s argument number %d", math_typename(type), argn);
		}
	}
	return id;
}

static int
new_object(lua_State *L, int type, from_table_func from_table, int narray) {
	math_t id = new_object_(L, type, from_table, narray);
	lua_pushmath(L, id);
	return 1;
}

static int
lreset(lua_State *L) {
	math_frame(GETMC(L));
	return 0;
}

static inline math_t
vector_from_index(lua_State *L, struct math_context *M, int index) {
	return object_from_index(L, M, index, MATH_TYPE_VEC4, vector_from_table);
}

static inline math_t
aabb_from_index(lua_State *L, struct math_context *M, int index) {
	math_t aabb = object_from_index(L, M, index, MATH_TYPE_VEC4, aabb_from_table);
	if (math_size(M, aabb) != 2)
		luaL_error(L, "Invalid AABB");
	return aabb;
}

static inline math_t
matrix_from_index(lua_State *L, struct math_context *M, int index) {
	return object_from_index(L, M, index, MATH_TYPE_MAT, matrix_from_table);
}

static inline math_t
quat_from_index(lua_State *L, struct math_context *M, int index) {
	return object_from_index(L, M, index, MATH_TYPE_QUAT, quat_from_table);
}

static inline math_t
frustum_planes_from_index(lua_State *L, struct math_context *M, int index){
	math_t planes = object_from_index(L, M, index, MATH_TYPE_VEC4, vector_from_table);
	if (math_size(M, planes) != 6)
		luaL_error(L, "Invalid Frustum Planes");
	return planes;
}

static inline math_t
frustum_points_from_index(lua_State *L, struct math_context *M, int index){
	math_t points = object_from_index(L, M, index, MATH_TYPE_VEC4, vector_from_table);
	if (math_size(M, points) != 8)
		luaL_error(L, "Invalid Frustum Planes");
	return points;
}

typedef math_t (*from_index)(lua_State *, struct math_context *, int);

static math_t
create_array(lua_State *L, struct math_context *M, int array_index, int type, int asize, int esize, from_index func) {
	math_t result = math_import(M, NULL, type, asize);
	float *v = math_init(M, result);
	int i;
	for (i=1;i<=asize;i++) {
		lua_geti(L, array_index, i);
		math_t e = func(L, M, -1);
		lua_pop(L, 1);
		memcpy(v, math_value(M, e), esize * sizeof(float));
		v += esize;
	}

	return result;
}

static inline math_t
array_from_index(lua_State *L, struct math_context *M, int index, int type, int expsize) {
	if (lua_isuserdata(L, index)) {
		math_t id = get_id(L, M, index);
		if (math_type(M, id) != type) {
			luaL_error(L, "Type mismatch %s != %s", math_typename(type), math_typename(math_type(M, id)));
		}
		if (expsize != 0 && math_size(M, id) != expsize) {
			luaL_error(L, "Size mismatch %d != %d", expsize, math_size(M, id));
		}
		return id;
	}
	luaL_checktype(L, index, LUA_TTABLE);
	int n = (int)lua_rawlen(L, index);
	if (expsize != 0 && expsize != n) {
		luaL_error(L, "Need size of table %d/%d", expsize, n);
	}

	from_index func;
	int esize;

	switch (type) {
	case MATH_TYPE_VEC4:
		func = vector_from_index;
		esize = 4;
		break;
	case MATH_TYPE_MAT:
		func = matrix_from_index;
		esize = 16;
		break;
	case MATH_TYPE_QUAT:
		func = quat_from_index;
		esize = 4;
		break;
	default:
		luaL_error(L, "Unsupport array type %s", math_typename(type));
		return MATH_NULL;
	}

	return create_array(L, M, index, type, n, esize, func);
}

static math_t
object_to_quat(lua_State *L, struct math_context *M, int index) {
	math_t id = get_id(L, M, index);
	int type = math_type(M, id);
	switch(type) {
	case MATH_TYPE_MAT:
		return math3d_matrix_to_quat(M, id);
	case MATH_TYPE_QUAT:
		return id;
	case MATH_TYPE_VEC4:
		return math3d_make_quat_from_euler(M, id);
		break;
	default:
		luaL_error(L, "Invalid type %s for quat", math_typename(type));
		return MATH_NULL;
	}
}

static int
lmatrix(lua_State *L) {
	if (lua_isuserdata(L, 1)) {
		struct math_context *M = GETMC(L);
		math_t id = get_id(L, M, 1);
		int type = math_type(M, id);
		if (type == MATH_TYPE_QUAT) {
			id = math3d_quat_to_matrix(M, id);
			lua_pushmath(L, id);
			return 1;
		}
	}
	return new_object(L, MATH_TYPE_MAT, matrix_from_table, 16);
}

static int
lvector(lua_State *L) {
	int top = lua_gettop(L);
	if (top == 3) {
		lua_pushnumber(L, 0.0f);
	} else if (top == 2) {
		struct math_context *M = GETMC(L);
		if (!lua_isuserdata(L, 1)) {
			return luaL_error(L, "Should be (vector id , number)");
		}
		math_t id = get_id(L, M, 1);
		int type = math_type(M, id);
		if (type != MATH_TYPE_VEC4) {
			return luaL_error(L, "Need a vector, it's %s", math_typename(type));
		}
		float n4 = (float)luaL_checknumber(L, 2);
		const float *vec3 = math_value(M, id);
		if (n4 != vec3[3]) {
			id = math_vec4(M, NULL);
			float *vec4 = math_init(M, id);
			vec4[0] = vec3[0];
			vec4[1] = vec3[1];
			vec4[2] = vec3[2];
			vec4[3] = n4;
		}
		lua_pushmath(L, id);
		return 1;
	}
	return new_object(L, MATH_TYPE_VEC4, vector_from_table, 4);
}

static int
lquaternion(lua_State *L) {
	const int n = lua_gettop(L);
	if (n == 1 && lua_isuserdata(L, 1)){
		math_t id = object_to_quat(L, GETMC(L), 1);
		lua_pushmath(L, id);
		return 1;
	}

	if (n == 2 && lua_isuserdata(L, 1) && lua_isuserdata(L, 2)){
		struct math_context *M = GETMC(L);
		math_t id1 = get_id(L, M, 1);
		math_t id2 = get_id(L, M, 2);
		math_t r = math3d_quat_between_2vectors(M, id1, id2);
		lua_pushmath(L, r);
		return 1;
	}

	return new_object(L, MATH_TYPE_QUAT, quat_from_table, 4);
}


static int
larray_matrix_ref(lua_State *L) {
	struct math_context *M = GETMC(L);
	float *ptr = (float *)lua_touserdata(L, 1);
	if (ptr == NULL) {
		return luaL_error(L, "Invalid pointer (type = %s)", lua_typename(L, lua_type(L, 1)));
	}
	int sz = (int)luaL_checkinteger(L, 2);
	int off = (int)luaL_optinteger(L, 3, 0);
	ptr += off * 16;
	math_t id = math_ref(M, ptr, MATH_TYPE_MAT, sz);
	lua_pushmath(L, id);
	return 1;
}

static int
lmul_array(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t m = matrix_from_index(L, M, 1);
	math_t array = array_from_index(L, M, 2, MATH_TYPE_MAT, 0);
	math_t output = MATH_NULL;
	if (!lua_isnoneornil(L, 3)) {
		output = get_id(L, M, 3);
		if (!math_isref(M, output)) {
			return luaL_error(L, "Output is not ref");
		}
		int t = math_type(M, output);
		if (t != MATH_TYPE_MAT)
			return luaL_error(L, "Output is not matrix, it's %s", math_typename(t));
	}
	math_t r = math3d_mul_matrix_array(M, m, array, output);
	lua_pushmath(L, r);
	return 1;
}

static int
larray_vector(lua_State *L) {
	struct math_context *M = GETMC(L);
	lua_pushmath(L, array_from_index(L, M, 1, MATH_TYPE_VEC4, 0));
	return 1;
}

static int
larray_matrix(lua_State *L) {
	struct math_context *M = GETMC(L);
	lua_pushmath(L, array_from_index(L, M, 1, MATH_TYPE_MAT, 0));
	return 1;
}

static int
larray_quat(lua_State *L) {
	struct math_context *M = GETMC(L);
	lua_pushmath(L, array_from_index(L, M, 1, MATH_TYPE_QUAT, 0));
	return 1;
}

static int
larray_index(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = get_id(L, M, 1);
	int index = (int)luaL_checkinteger(L, 2) - 1;
	int size = math_size(M, v);
	if (index < 0 || index >= size) {
		return luaL_error(L, "Invalid array index (%d/%d)", index, size);
	}
	lua_pushmath(L, math_index(M, v, index));
	return 1;
}

static int
larray_size(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = get_id(L, M, 1);
	int size = math_size(M, v);
	lua_pushinteger(L, size);
	return 1;
}

static int
lindex(lua_State *L) {
	struct math_context *M = GETMC(L);
	const int num_indices = lua_gettop(L)-1;
	math_t id = get_id(L, M, 1);
	int ii;

	for (ii=0; ii<num_indices; ++ii){
		int idx = (int)luaL_checkinteger(L, ii+2);
		index_object(L, M, id, idx);
	}
	return num_indices;
}

static math_t
set_index_object(lua_State *L, struct math_context *M, math_t id) {
	const float * v = math_value(M, id);
	int type = math_type(M, id);
	int idx = (int)luaL_checkinteger(L, 2);
	if (idx < 1 || idx > 4) {
		luaL_error(L, "Invalid index %d", idx);
		return MATH_NULL;
	}
	--idx;

	const int n = lua_gettop(L);
	if (n < 3){
		luaL_error(L, "Invalid set_index argument number:%d, at least 3.", n);
	}

	const int valuenum = n - 2;

	if (idx + valuenum > 4){
		luaL_error(L, "Invalid argument number, start index is:%d, argument number:%d, start index + argument number should less than 4!", idx, valuenum);
	}

	switch (type) {
	case MATH_TYPE_MAT: {
		math_t id = math_matrix(M, NULL);
		float *vv = math_init(M, id);
		memcpy(vv, v, 16 * sizeof(float));
		int ii;
		for (ii=0; ii<valuenum; ++ii){
			const float* nv = math_value(M, vector_from_index(L, M, ii+3));
			memcpy(vv+(idx+ii)*4, nv, sizeof(float)*4);
		}
		return id; }
	case MATH_TYPE_VEC4:
	case MATH_TYPE_QUAT:{
		math_t id = math_vec4(M, NULL);
		float *vv = math_init(M, id);
		memcpy(vv, v, 4 * sizeof(float));
		int ii;
		for (ii=0; ii<valuenum; ++ii){
			vv[idx+ii] = (float)luaL_checknumber(L, ii+3);
		}
		return id; }
	default:
		luaL_error(L, "invalid data type:%s", math_typename(type));
		return MATH_NULL;
	}
}


static int
lset_index(lua_State *L){
	struct math_context *M  = GETMC(L);
	math_t id = get_id(L, M, 1);
	lua_pushmath(L, set_index_object(L, M, id));
	return 1;
}

static int
lset_columns(lua_State *L){
	struct math_context *M = GETMC(L);
	lua_settop(L, 5);
	const float *m = math_value(M, matrix_from_index(L, M, 1));
	math_t id = math_matrix(M, NULL);
	float *nm = math_init(M, id);
	memcpy(nm, m, sizeof(float) * 16);
	int ii;
	for (ii=2; ii <= 5; ++ii){
		const uint32_t offset = (ii-2) * 4;
		const float *v = lua_isnoneornil(L, ii) ?
			(m+offset) : 
			math_value(M, vector_from_index(L, M, ii));
		memcpy(nm+offset, v, sizeof(float)*4);
	}
	return 1;
}

static int
lsrt(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t mat = get_id(L, M, 1);
	int type = math_type(M, mat);
	if (type != MATH_TYPE_MAT) {
		luaL_error(L, "invalid type:%s", math_typename(type));
	}
	math_t r[3];
	math3d_decompose_matrix(M, mat, r);
	int i;
	for (i=0;i<3;i++) {
		lua_pushmath(L, r[i]);
	}
	return 3;	
}

static int
llength(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v3 = vector_from_index(L, M, 1);
	if (!lua_isnoneornil(L, 2)){
		math_t vv3 = vector_from_index(L, M, 2);
		v3 = math3d_sub_vec(M, vv3, v3);
	}

	float length = math3d_length(M, v3);
	lua_pushnumber(L, length);
	return 1;
}

static int
lfloor(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = vector_from_index(L, M, 1);
	lua_pushmath(L, math3d_floor(M, v));
	return 1;
}

static int
lceil(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = vector_from_index(L, M, 1);
	lua_pushmath(L, math3d_ceil(M, v));
	return 1;
}


static int
ldot(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v1 = vector_from_index(L, M, 1);
	math_t v2 = vector_from_index(L, M, 2);
	lua_pushnumber(L, math3d_dot(M, v1,v2));
	return 1;
}


static int
lcross(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v1 = vector_from_index(L, M, 1);
	math_t v2 = vector_from_index(L, M, 2);
	lua_pushmath(L, math3d_cross(M, v1, v2));
	return 1;
}

static int
lnormalize(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = get_id(L, M, 1);
	int type = math_type(M, v);
	math_t r;
	switch (type) {
	case MATH_TYPE_VEC4:
		r = math3d_normalize_vector(M, v);
		break;
	case MATH_TYPE_QUAT:
		r = math3d_normalize_quat(M, v);
		break;
	default:
		return luaL_error(L, "normalize don't support %s", math_typename(type));
	}
	lua_pushmath(L, r);
	return 1;
}


static int
ltranspose(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t mat = matrix_from_index(L, M, 1);
	lua_pushmath(L, math3d_transpose_matrix(M, mat));
	return 1;
}

static int
linverse(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t id = get_id(L, M, 1);
	int type = math_type(M, id);
	math_t r;
	switch (type) {
	case MATH_TYPE_VEC4: {
		r = math_vec4(M, NULL);
		float *iv = math_init(M, r);
		const float *v = math_value(M, id);
		iv[0] = -v[0];
		iv[1] = -v[1];
		iv[2] = -v[2];
		iv[3] = v[3];
		break; }
	case MATH_TYPE_QUAT:
		r = math3d_inverse_quat(M, id);
		break;
	case MATH_TYPE_MAT:
		r = math3d_inverse_matrix(M, id);
		break;
	default:
		return luaL_error(L, "inverse don't support %s", math_typename(type));
	}
	lua_pushmath(L, r);
	return 1;
}

static int
linverse_fast(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t mat = matrix_from_index(L, M, 1);
	lua_pushmath(L, math3d_inverse_matrix_fast(M, mat));
	return 1;
}

static inline int
look_(lua_State *L, int dir) {
	struct math_context *M = GETMC(L);
	math_t eye = vector_from_index(L, M, 1);
	math_t at = vector_from_index(L, M, 2);
	math_t up = object_from_index(L, M, 3, MATH_TYPE_VEC4, vector_from_table);	// Can be NULL

	lua_pushmath(L, math3d_lookat_matrix(M, dir, eye, at, up));
	return 1;
}

static int
llookat(lua_State *L) {
	return look_(L, 0);
}

static int
llookto(lua_State *L) {
	return look_(L, 1);
}

static int
lreciprocal(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = vector_from_index(L, M, 1);

	lua_pushmath(L, math3d_reciprocal(M, v));
	return 1;
}

static int
ltodirection(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = get_id(L, M, 1);
	int type = math_type(M, v);
	math_t r;
	switch (type) {
	case MATH_TYPE_QUAT:
		r = math3d_quat_to_viewdir(M, v);
		break;
	case MATH_TYPE_MAT:
		r = math3d_rotmat_to_viewdir(M, v);
		break;
	default:
		return luaL_error(L, "todirection don't support: %s", math_typename(type));
	}
	lua_pushmath(L, r);
	return 1;
}

static int
ltorotation(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = get_id(L, M, 1);
	int type = math_type(M, v);
	math_t r;
	switch (type) {
	case MATH_TYPE_VEC4:
		r = math3d_viewdir_to_quat(M, v);
		break;
	case MATH_TYPE_MAT:
		r = math3d_matrix_to_quat(M, v);
		break;
	default:
		return luaL_error(L, "torotation not support: %s", math_typename(type));
	}
	lua_pushmath(L, r);
	return 1;
}

static int
lvectors_quat(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t v0 = vector_from_index(L, M, 1);
	math_t v1 = vector_from_index(L, M, 2);
	lua_pushmath(L, math3d_quat_between_2vectors(M, v0, v1));
	return 1;
}

static int
ltotable(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t id = get_id(L, M, 1);
	to_table(L, M, id, 1);
	return 1;
}

static int
ltovalue(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t id = get_id(L, M, 1);
	to_table(L, M, id, 0);
	return 1;
}

static int
lbase_axes(lua_State *L) {
	struct math_context *M = GETMC(L);

	math_t forward = vector_from_index(L, M, 1);

	math_t r = math3d_base_axes(M, forward);

	lua_pushmath(L, math_index(M, r, 0));	// right
	lua_pushmath(L, math_index(M, r, 1));	// up

	return 2;
}

static int
ltransform(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t rotator = get_id(L, M, 1);

	if (lua_isnone(L, 3)){
		return luaL_error(L, "need argument 3, 0 for vector, 1 for point, 'nil' will use vector[4] value");
	}

	math_t v = vector_from_index(L, M, 2);
	if (!lua_isnil(L, 3)) {
		const float p = (float)luaL_checknumber(L, 3);
		const float *value = math_value(M, v);
		if (p != value[3]) {
			v = math_vec4(M, NULL);
			float *tmp = math_init(M, v);
			tmp[0] = value[0];
			tmp[1] = value[1];
			tmp[2] = value[2];
			tmp[3] = p;
		}
	}

	int type = math_type(M, rotator);

	math_t r;
	switch (type){
	case MATH_TYPE_QUAT:
		r = math3d_quat_transform(M, rotator, v);
		break;
	case MATH_TYPE_MAT:
		r = math3d_rotmat_transform(M, rotator, v);
		break;
	default: 
		return luaL_error(L, "only support quat/mat for rotate vector:%s", math_typename(type));
	}

	lua_pushmath(L, r);
	return 1;
}

static int
ltransform_homogeneous_point(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t mat = matrix_from_index(L, M, 1);
	math_t vec = vector_from_index(L, M, 2);

	lua_pushmath(L, math3d_mulH(M, mat, vec));
	return 1;
}

static inline float
read_number(lua_State *L, int index, const char* n, float opt){
	lua_getfield(L, index, n);
	const float num = (float)luaL_optnumber(L, -1, opt);
	lua_pop(L, 1);
	return num;
}

static math_t
create_proj_mat(lua_State *L, struct math_context *M, int index, int inv_z) {
	const char* nn, *ff;
	if (inv_z) {nn="f"; ff="n";}
	else { nn="n"; ff="f";}

	const float near = read_number(L, index, nn, 0.1f);
	const float far = read_number(L, index, ff, 100.f);

	if (lua_getfield(L, index, "fov") == LUA_TNUMBER) {
		float fov = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);

		fov *= (float)M_PI / 180.f;

		const float aspect = read_number(L, index, "aspect", 1.f);
		return math3d_perspectiveLH(M, fov, aspect, near, far, g_default_homogeneous_depth);
	} else {
		lua_pop(L, 1); //pop "fov"

		const float left = read_number(L, index, "l", -1.f);
		const float right = read_number(L, index, "r", 1.f);

		const float top = read_number(L, index, "t", 1.f);
		const float bottom = read_number(L, index, "b", -1.f);

		lua_getfield(L, index, "ortho");
		int ortho = lua_toboolean(L, -1);
		lua_pop(L, 1);
		if (ortho)
			return math3d_orthoLH(M, left, right, bottom, top, near, far, g_default_homogeneous_depth);
		else
			return math3d_frustumLH(M, left, right, bottom, top, near, far, g_default_homogeneous_depth);
	}
}

static int
lprojmat(lua_State *L) {
	struct math_context *M = GETMC(L);
	luaL_checktype(L, 1, LUA_TTABLE);
	const int inv_z = lua_isnoneornil(L, 2) ? 0 : lua_toboolean(L, 2);
	lua_pushmath(L, create_proj_mat(L, M, 1, inv_z));
	return 1;
}

static int
lminmax(lua_State *L) {
	struct math_context *M = GETMC(L);

	const math_t points = array_from_index(L, M, 1, MATH_TYPE_VEC4, 0);

	const math_t transform = object_from_index(L, M, 2, MATH_TYPE_MAT, matrix_from_table);	// can be null
	math_t minmax[2] = { MATH_NULL, MATH_NULL };

	const int numpoints = math_size(M, points);
	int ii;
	for (ii = 0; ii < numpoints; ++ii) {
		math_t v = math_index(M, points, ii);
		math3d_minmax(M, transform, v, minmax);
	}

	lua_pushmath(L, minmax[0]);
	lua_pushmath(L, minmax[1]);

	return 2;
}

static int
llerp(lua_State *L){
	struct math_context *M = GETMC(L);

	math_t v0 = get_id(L, M, 1);
	math_t v1 = get_id(L, M, 2);

	int type0 = math_type(M, v0);
	int type1 = math_type(M, v1);


	if (type0 != type1) {
		luaL_error(L, "not equal type for lerp:%s, %s", math_typename(type0), math_typename(type1));
	}

	const float ratio = (float)luaL_checknumber(L, 3);
	math_t r;

	switch (type0) {
	case MATH_TYPE_VEC4:
		r = math3d_lerp(M, v0, v1, ratio);
		break;
	case MATH_TYPE_QUAT:
		r = math3d_quat_lerp(M, v0, v1, ratio);
		break;
	default:
		return luaL_error(L, "%s type can not for lerp", math_typename(type0));
	}
	lua_pushmath(L, r);

	return 1;
}

static int
lslerp(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v0 = quat_from_index(L, M, 1);
	math_t v1 = quat_from_index(L, M, 2);
	const float ratio = (float)luaL_checknumber(L, 3);

	lua_pushmath(L, math3d_quat_slerp(M, v0, v1, ratio));

	return 1;
}

static int
lmemsize(lua_State *L) {
	struct math_context *M = GETMC(L);
	lua_pushinteger(L, math_memsize(M));
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
lget_homogeneous_depth(lua_State *L){
	lua_pushboolean(L, g_default_homogeneous_depth);
	return 1;
}

static int
lget_origin_bottom_left(lua_State *L){
	lua_pushboolean(L, g_origin_bottom_left);
	return 1;
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
			u.f[i] = (float)luaL_checknumber(L, i+2);
			break;
		case 'd':
			u.n[i] = (uint32_t)luaL_checkinteger(L, i+2);
			break;
		default:
			return luaL_error(L, "Invalid format %s", format);
		}
	}
	struct math_context *M = GETMC(L);
	math_t r;
	if (n == 4) {
		r = math_vec4(M, u.f);
	} else {
		r = math_matrix(M, u.f);
	}
	lua_pushmath(L, r);
	return 1;
}

static int
lisvalid(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t id = get_id(L, M, 1);
	lua_pushboolean(L, math_valid(M, id));
	return 1;
}

static int
lisequal(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t id0 = get_id(L, M, 1);
	math_t id1 = get_id(L, M, 2);
	int type0 = math_type(M, id0);
	int type1 = math_type(M, id1);

	if (type0 != type1) {
		lua_pushboolean(L, 0);
		return 1;
	}
	if (id0.idx == id1.idx) {
		lua_pushboolean(L, 1);
		return 1;
	}

	const float *v0 = math_value(M, id0);
	const float *v1 = math_value(M, id1);

	const float threshold = (float)luaL_optnumber(L, 3, 10e-6);

	int numelem = 0;
	switch (type0) {
		case MATH_TYPE_MAT: numelem = 16; break;
		case MATH_TYPE_VEC4: numelem = 3; break;
		case MATH_TYPE_QUAT: numelem = 4; break;
		default: luaL_error(L, "invalide type: %s", math_typename(type0));break;
	}

	int ii;

	for (ii=0; ii<numelem; ++ii) {
		if (fabs(v0[ii]-v1[ii]) > threshold){
			lua_pushboolean(L, 0);
			return 1;
		}
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int
lquat2euler(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t q = quat_from_index(L, M, 1);
	lua_pushmath(L, math3d_quat_to_euler(M, q));
	return 1;
}

// input: view direction vector
// output: 
//		output radianX and radianY which can used to create quaternion that around x-axis and y-axis, 
//		multipy those quaternions can recreate view direction vector
static int
ldir2radian(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v = vector_from_index(L, M, 1);
	float radians[2];
	math3d_dir2radian(M, v, radians);
	lua_pushnumber(L, radians[0]);
	lua_pushnumber(L, radians[1]);
	return 2;
}

static int
lforward_dir(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t mat = matrix_from_index(L, M, 1);
	math_t vv = math_matrix(M, NULL);
	float *v = math_init(M, vv);
	v[0] = 0;
	v[1] = 0;
	v[2] = 1;
	v[3] = 0;
	lua_pushmath(L, math3d_rotmat_transform(M, mat, vv));
	return 1;
}

static inline float *
alloc_aabb(lua_State *L, struct math_context *M, math_t *id) {
	*id = math_import(M, NULL, MATH_TYPE_VEC4, 2);
	return math_init(M, *id);
}

static math_t
append_aabb(lua_State *L, struct math_context *M, math_t aabb, int from_index, int to_index) {
	int i;
	math_t minmax[2] = {
		math_index(M, aabb, 0),
		math_index(M, aabb, 1),
	};
	for (i=from_index;i<=to_index;i++) {
		math_t v = vector_from_index(L, M, i);
		math3d_minmax(M, MATH_NULL, v, minmax);
	}
	if (math_issame(minmax[0], math_index(M, aabb, 0)) &&
		math_issame(minmax[1], math_index(M, aabb, 1))) {
		return aabb;
	} else {
		math_t id;
		float * r = alloc_aabb(L, M, &id);
		memcpy(r, math_value(M, minmax[0]), 4 * sizeof(float));
		memcpy(r+4, math_value(M, minmax[1]), 4 * sizeof(float));
		return id;
	}
}

static int
laabb(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t id;
	float *aabb = alloc_aabb(L, M, &id);
	aabb[0] = FLT_MAX;
	aabb[1] = FLT_MAX;
	aabb[2] = FLT_MAX;
	aabb[3] = 0;

	aabb[4+0] = -FLT_MAX;
	aabb[4+1] = -FLT_MAX;
	aabb[4+2] = -FLT_MAX;
	aabb[4+3] = 0;

	int top = lua_gettop(L);
	if (top > 1) {
		id = append_aabb(L, M, id, 1, top);
	}

	lua_pushmath(L, id);

	return 1;
}

static int
laabb_isvalid(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	lua_pushboolean(L, math3d_aabb_isvalid(M, aabb));
	return 1;
}

static int
laabb_append(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	aabb = append_aabb(L, M, aabb, 2, lua_gettop(L));
	lua_pushmath(L, aabb);
	return 1;
}

static int
laabb_merge(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb1 = aabb_from_index(L, M, 1);
	math_t aabb2 = aabb_from_index(L, M, 2);
	lua_pushmath(L, math3d_aabb_merge(M, aabb1, aabb2));

	return 1;
}

// 1 : worldmat
// 2 : aabb (can be nil)
// 3 : srtmat (can be nil)
// return 1: aabb (nil if input aabb is nil)
// return 2: worldmat
static int
laabb_transform(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t worldmat = matrix_from_index(L, M, 1);
	math_t aabb = object_from_index(L, M, 2, MATH_TYPE_VEC4, aabb_from_table);	// aabb can be NULL, check aabb later
	math_t srt = object_from_index(L, M, 3, MATH_TYPE_MAT, matrix_from_table);
	if (math_isnull(srt) && math_isnull(aabb)) {
		lua_pushnil(L);
		lua_pushvalue(L, 1);
		return 2;	// returns nil, worldmat
	}
	math_t result_matid = MATH_NULL;
	if (!math_isnull(srt)) {
		result_matid = math3d_mul_matrix(M, worldmat, srt);
		worldmat = result_matid;
	}
	if (!math_isnull(aabb)) {
		if (math_size(M, aabb) != 2) {
			return luaL_error(L, "Invalid AABB");
		}
		lua_pushmath(L, math3d_aabb_transform(M, worldmat, aabb));
	} else {
		lua_pushnil(L);
	}
	if (math_isnull(result_matid)) {
		lua_pushmath(L, result_matid);
	} else {
		lua_pushvalue(L, 1);
	}
	return 2;
}

static int
laabb_center_extents(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	math_t r = math3d_aabb_center_extents(M, aabb);
	lua_pushmath(L, math_index(M, r, 0));	// center
	lua_pushmath(L, math_index(M, r, 1));	// extents

	return 2;
}

static int
laabb_intersect_plane(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	math_t plane = vector_from_index(L, M, 2);

	lua_pushinteger(L, math3d_aabb_intersect_plane(M, aabb, plane));
	return 1;
}

static int
laabb_intersection(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t r = math3d_aabb_intersection(M, matrix_from_index(L, M, 1), matrix_from_index(L, M, 2));
	lua_pushmath(L, r);
	return 1;
}

static int
laabb_test_point(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	math_t v = vector_from_index(L, M, 2);

	lua_pushboolean(L, math3d_aabb_test_point(M, aabb, v));
	return 1;
}

static const char* s_frustum_field[] = {
	"l", "b", "n", "r", "t", "f",
};

static int
laabb_to_frustum(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t aabb_id = aabb_from_index(L, M, 1);
	const float *aabb = math_value(M, aabb_id);

	lua_createtable(L, 0, 7);
	lua_pushboolean(L, 1);
	lua_setfield(L, -2, "ortho");

	const float frustum[6] = {
		aabb[0], aabb[1], aabb[2],
		aabb[4], aabb[5], aabb[6],
	};

	int ii;

	for (ii = 0; ii < sizeof(s_frustum_field)/sizeof(s_frustum_field[0]); ++ii){
		lua_pushnumber(L, frustum[ii]);
		lua_setfield(L, -2, s_frustum_field[ii]);
	}

	return 1;
}

static int
laabb_points(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	math_t points[8];
	math3d_aabb_points(M, aabb, points);
	lua_createtable(L, 8, 0);
	int i;
	for (i=0;i<8;i++) {
		lua_pushmath(L, points[i]);
		lua_seti(L, -2, i+1);
	}
	return 1;
}

static int
laabb_expand(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t aabb = aabb_from_index(L, M, 1);
	math_t e = vector_from_index(L, M, 2);

	lua_pushmath(L, math3d_aabb_expand(M, aabb, e));
	return 1;
}

static int
lfrustum_to_aabb(lua_State *L){
	struct math_context *M = GETMC(L);
	luaL_checktype(L, 1, LUA_TTABLE);

	lua_getfield(L, 1, "ortho");
	const int isortho = lua_toboolean(L, -1);
	lua_pop(L, 1);

	if (!isortho) {
		luaL_error(L, "only support aabb to ortho frustum");
		return 0;
	}

	float frustum[6];
	for (int ii = 0; ii < sizeof(s_frustum_field)/sizeof(s_frustum_field[0]); ++ii){
		if (LUA_TNUMBER != lua_getfield(L, 1, s_frustum_field[ii])){
			luaL_error(L, "invalid field:%s in frustum", s_frustum_field[ii]);
			return 0;
		}
		frustum[ii] = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	
	math_t id;
	float * aabb = alloc_aabb(L, M, &id);
	aabb[0] = frustum[0],
	aabb[1] = frustum[1],
	aabb[2] = frustum[2];
	aabb[3] = 1.0f;
	aabb[4] = frustum[3],
	aabb[5] = frustum[4],
	aabb[6] = frustum[5];
	aabb[7] = 1.0f;

	lua_pushmath(L, id);
	return 1;
}

//frustum
static int
lfrustum_planes(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t m = matrix_from_index(L, M, 1);
	math_t planes = math3d_frustum_planes(M, m, g_default_homogeneous_depth);
	lua_pushmath(L, planes);
	return 1;
}

static int
lfrustum_intersect_aabb(lua_State *L) {
	struct math_context *M = GETMC(L);
	const math_t planes = frustum_planes_from_index(L, M, 1);
	const math_t aabb = aabb_from_index(L, M, 2);
	lua_pushinteger(L, math3d_frustum_intersect_aabb(M, planes, aabb));
	return 1;
}

static int
lfrustum_intersect_aabb_list(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t planes = frustum_planes_from_index(L, M, 1);

	luaL_checktype(L, 2, LUA_TTABLE);
	const int numelem = (int)lua_rawlen(L, 2);

	const int return_notvisible = lua_toboolean(L, 3);

	lua_createtable(L, numelem, 0);
	int returnidx = 0;
	int ii;
	for (ii=0; ii<numelem; ++ii){
		lua_geti(L, 2, ii+1);
		math_t aabb = aabb_from_index(L, M, -1);
		lua_pop(L, 1);

		int r = math3d_frustum_intersect_aabb(M, planes, aabb) >= 0;
		if (return_notvisible)
			r = !r;

		if (r){
			lua_pushinteger(L, ii+1);
			lua_seti(L, -2, ++returnidx);
		}
	}
	return 1;
}

static int
lfrustum_points(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t m = matrix_from_index(L, M, 1);
	math_t result = math3d_frustum_points(M, m, g_default_homogeneous_depth);
	lua_pushmath(L, result);
	return 1;
}

static int
lfrustum_calc_near_far(lua_State *L){
	struct math_context *M = GETMC(L);
	const math_t planes = frustum_planes_from_index(L, M, 1);

	float nearfar[2];
	math3d_frustum_calc_near_far(M, planes, nearfar);
	lua_pushnumber(L, nearfar[0]);
	lua_pushnumber(L, nearfar[1]);
	return 2;
}

static int
lpoint2plane(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t pt = vector_from_index(L, M, 1);
	math_t plane = vector_from_index(L, M, 2);

	lua_pushnumber(L, math3d_point2plane(M, pt, plane));
	return 1;
}

static int
ladd(lua_State *L) {
	struct math_context *M = GETMC(L);
	int i;
	int top = lua_gettop(L);
	if (top < 2) {
		return luaL_error(L, "Need 2 or more vectors");
	}
	math_t result = vector_from_index(L, M, 1);
	for (i=2;i<=top;i++) {
		result = math3d_add_vec(M, result, vector_from_index(L, M, i));
	}
	lua_pushmath(L, result);
	return 1;
}

static int
lsub(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t r = math3d_sub_vec(M, vector_from_index(L, M, 1), vector_from_index(L, M, 2));
	lua_pushmath(L, r);

	return 1;
}

static math_t
get_vec_or_number(lua_State *L, struct math_context *M, int index) {
	if (lua_type(L, index) == LUA_TNUMBER) {
		float tmp[4];
		tmp[0] = (float)lua_tonumber(L, index);
		tmp[1] = tmp[0];
		tmp[2] = tmp[0];
		tmp[3] = tmp[0];
		return math_vec4(M, tmp);
	} else {
		return vector_from_index(L, M, index);
	}
}

static int
lmuladd(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t v0 = get_vec_or_number(L, M, 1);
	math_t v1 = get_vec_or_number(L, M, 2);
	math_t v2 = get_vec_or_number(L, M, 3);

	math_t result = math3d_mul_vec(M, v0, v1);
	result = math3d_add_vec(M, result, v2);
	
	lua_pushmath(L, result);
	return 1;
}

static int
lmul(lua_State *L) {
	struct math_context *M = GETMC(L);
	math_t result;
	if (lua_isnumber(L, 1)) {
		// number * vertex
		float r[4];
		r[0] = (float)lua_tonumber(L, 1);
		r[1] = r[0];
		r[2] = r[0];
		r[3] = r[0];
		result = math3d_mul_vec(M, math_vec4(M, r), vector_from_index(L, M, 2));
	} else {
		math_t lv = get_id(L, M, 1);
		int type = math_type(M, lv);
		switch (type) {
		case MATH_TYPE_MAT:
			result = math3d_mul_matrix(M, lv, matrix_from_index(L, M, 2));
			break;
		case MATH_TYPE_QUAT:
			result = math3d_mul_quat(M, lv, quat_from_index(L, M, 2));
			break;
		case MATH_TYPE_VEC4:
			if (lua_isnumber(L, 2)) {
				float r[4];
				r[0] = (float)lua_tonumber(L, 2);
				r[1] = r[0];
				r[2] = r[0];
				r[3] = r[0];
				result = math3d_mul_vec(M, lv, math_vec4(M, r));
			} else {
				result = math3d_mul_vec(M, lv, vector_from_index(L, M, 2));
			}
			break;
		default:
			return luaL_error(L, "Invalid mul arguments %s or quaternion mul vector should use 'transform' function", math_typename(type));
		}
	}
	lua_pushmath(L, result);
	return 1;
}

static int
lpoints_center(lua_State *L) {
	struct math_context *M = GETMC(L);
	const math_t points = frustum_points_from_index(L, M, 1);
	const math_t center = math3d_frustum_center(M, points);
	lua_pushmath(L, center);

	return 1;
}

static int
lpoints_radius(lua_State *L) {
	struct math_context *M = GETMC(L);
	const math_t points = frustum_points_from_index(L, M, 1);
	const math_t center = vector_from_index(L, M, 2);
	lua_pushnumber(L, math3d_frustum_max_radius(M, points, center));
	return 1;
}

static int
lpoints_aabb(lua_State *L){
	struct math_context *M = GETMC(L);
	const math_t points = frustum_points_from_index(L, M, 1);
	lua_pushmath(L, math3d_frusutm_aabb(M, points));
	return 1;
}

static int
lplane(lua_State *L){
	struct math_context *M = GETMC(L);
	math_t r = math_vec4(M, NULL);
	float * tmp = math_init(M, r);

	math_t point = vector_from_index(L, M, 1);
	math_t normal_id = vector_from_index(L, M, 2);

	const float * normal = math_value(M, normal_id);

	tmp[0] = normal[0];
	tmp[1] = normal[1];
	tmp[2] = normal[2];
	tmp[3] = math3d_dot(M, point, normal_id);

	lua_pushmath(L, r);

	return 1;
}

static int
lplane_ray(lua_State *L) {
	/*
        ray: [o, d1], p(t) = o + t*d1, o is ray origin and d1 is the ray direction
        plane: [n, d], p dot n = d, p is a point in plane, which we want; n is the normal, d is the origin point to plane distance, is a scalar
        
        we assume ray and plane interset, so p(t) is plane's p:
            p(t) dot n = d
            (o+t*d1) dot n = d
        if we calculate t, we get the intersetion point:
            o dot n + t * (d1 dot n) = d
            t = (d - o dot n) / (d1 dot n)
    */
	struct math_context *M = GETMC(L);
	math_t ray_o = vector_from_index(L, M, 1);
	math_t ray_d = vector_from_index(L, M, 2);

	math_t plane = vector_from_index(L, M, 3);
	//t = (d - o dot n) / (d1 dot n)
	float dot_do = math3d_dot(M, ray_d, plane);

	//ray direction is parrall to plane normal, not interset
	if (fabs(dot_do) < 1e-7){
		lua_pushnumber(L, 0.f);
	} else {
		const float dis = math_value(M, plane)[3];
		float t = (dis - math3d_dot(M, ray_o, plane)) / dot_do;
		lua_pushnumber(L, t);
	}
	return 1;
}

/*
static int
lfrustum_calc_near_far(lua_State *L){
	struct lastack *LS = GETLS(L);
	const float* planes[6];
	fetch_vectors_from_table(L, LS, 1, 6, planes);

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
*/

static int
lvalue_ptr(lua_State *L){
	struct math3d_api *api = (struct math3d_api *)lua_touserdata(L, lua_upvalueindex(1));
	math_t id = math3d_from_lua_id(L, api, 1);
	int type;
	lua_pushlightuserdata(L, (void *)math3d_value(api, id, &type));
	return 1;
}

#define MATH_TYPE_AABB MATH_TYPE_COUNT

static int
lconstant(lua_State *L) {
	const char *tname = NULL;
	if (lua_type(L, 1) == LUA_TSTRING) {
		tname = lua_tostring(L, 1);
		lua_settop(L, 2);
	} else {
		luaL_checktype(L, 1, LUA_TTABLE);
		if (lua_getfield(L, 1, "type") != LUA_TSTRING)
			return luaL_error(L, "Need .type");
		tname = lua_tostring(L, -1);
		lua_settop(L, 1);
	}
	int type;
	if (strcmp(tname, math_typename(MATH_TYPE_NULL)) == 0) {
		lua_pushlightuserdata(L, MATH_TO_HANDLE(MATH_NULL));
		return 1;
	} else if (strcmp(tname, math_typename(MATH_TYPE_MAT)) == 0) {
		type = MATH_TYPE_MAT;
	} else if (strcmp(tname, math_typename(MATH_TYPE_VEC4)) == 0) {
		type = MATH_TYPE_VEC4;
	} else if (strcmp(tname, math_typename(MATH_TYPE_QUAT)) == 0) {
		type = MATH_TYPE_QUAT;
	} else if (strcmp(tname, "aabb") == 0) {
		type = MATH_TYPE_AABB;
	} else {
		return luaL_error(L, "Unknown type %s", tname);
	}
	if (lua_isnil(L, -1) || lua_rawlen(L, -1) == 0) {
		lua_pushlightuserdata(L, MATH_TO_HANDLE(math_identity(type)));
		return 1;
	}

	math_t id = MATH_NULL;
	struct math_context * M = GETMC(L);

	switch (type) {
	case MATH_TYPE_MAT:
		id = matrix_from_table(L, M, -1);
		break;
	case MATH_TYPE_VEC4:
		id = vector_from_table(L, M, -1);
		break;
	case MATH_TYPE_QUAT:
		id = quat_from_table(L, M, -1);
		break;
	case MATH_TYPE_AABB:
		id = aabb_from_table(L, M, -1);
		break;
	}
	lua_pushlightuserdata(L, MATH_TO_HANDLE(math_mark(M, id)));
	return 1;
}

static int
lconstant_array(lua_State *L) {
	const char *tname = luaL_checkstring(L, 1);
	int type;
	if (strcmp(tname, math_typename(MATH_TYPE_MAT)) == 0) {
		type = MATH_TYPE_MAT;
	} else if (strcmp(tname, math_typename(MATH_TYPE_VEC4)) == 0) {
		type = MATH_TYPE_VEC4;
	} else if (strcmp(tname, math_typename(MATH_TYPE_QUAT)) == 0) {
		type = MATH_TYPE_QUAT;
	} else {
		return luaL_error(L, "Unknown array type %s", tname);
	}

	struct math_context * M = GETMC(L);
	math_t id = array_from_index(L, M, 2, type, 0);
	lua_pushlightuserdata(L, MATH_TO_HANDLE(math_mark(M, id)));
	return 1;
}

static void
init_math3d_api(lua_State *L, struct math3d_api *M) {
	luaL_Reg l[] = {
		{ "ref", NULL },
		{ "mark", lmark },
		{ "unmark", lunmark },
		{ "constant", lconstant },
		{ "constant_array", lconstant_array },
		{ "tostring", ltostring },
		{ "matrix", lmatrix },
		{ "vector", lvector },
		{ "quaternion", lquaternion },
		{ "array_matrix_ref", larray_matrix_ref },
		{ "array_vector", larray_vector },
		{ "array_matrix", larray_matrix },
		{ "array_quat", larray_quat },
		{ "array_index", larray_index },
		{ "array_size", larray_size },
		{ "index", lindex },
		{ "set_index", lset_index},
		{ "set_columns", lset_columns},
		{ "reset", lreset },
		{ "mul", lmul },
		{ "mul_array", lmul_array },
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
		{ "vectors_quat", lvectors_quat},
		{ "totable", ltotable},
		{ "tovalue", ltovalue},
		{ "base_axes", lbase_axes},
		{ "transform", ltransform},
		{ "transformH", ltransform_homogeneous_point },
		{ "projmat", lprojmat },
		{ "minmax", lminmax},
		{ "lerp", llerp},
		{ "slerp", lslerp},
		{ "quat2euler", lquat2euler},
		{ "dir2radian", ldir2radian},
		{ "forward_dir",lforward_dir},
		{ "stacksize", lmemsize},	// todo : change name
		{ "set_homogeneous_depth", lset_homogeneous_depth},
		{ "set_origin_bottom_left", lset_origin_bottom_left},
		{ "get_homogeneous_depth", lget_homogeneous_depth},
		{ "get_origin_bottom_left", lget_origin_bottom_left},
		{ "pack", lpack },
		{ "isvalid", lisvalid},
		{ "isequal", lisequal},
		{ "value_ptr", lvalue_ptr},

		//points
		{ "points_center",	lpoints_center},
		{ "points_radius",	lpoints_radius},
		{ "points_aabb",	lpoints_aabb},
		
		//plane
		{ "plane",			lplane},
		{ "plane_ray",		lplane_ray},

		//aabb
		{ "aabb", 				 laabb},
		{ "aabb_isvalid", 		 laabb_isvalid},
		{ "aabb_append", 		 laabb_append},
		{ "aabb_merge", 		 laabb_merge},
		{ "aabb_transform", 	 laabb_transform},
		{ "aabb_center_extents", laabb_center_extents},
		{ "aabb_intersect_plane",laabb_intersect_plane},
		{ "aabb_intersection",	 laabb_intersection},
		{ "aabb_test_point",	 laabb_test_point},
		{ "aabb_to_frustum",	 laabb_to_frustum},
		{ "aabb_points",		 laabb_points},
		{ "aabb_expand",		 laabb_expand},

		//frustum
		{ "frustum_planes", 		lfrustum_planes},
		{ "frustum_intersect_aabb", lfrustum_intersect_aabb},
		{ "frustum_intersect_aabb_list", lfrustum_intersect_aabb_list},
		{ "frustum_points", 		lfrustum_points},
		{ "frustum_calc_near_far",  lfrustum_calc_near_far},
		{ "frustum_to_aabb",		lfrustum_to_aabb},

		//primitive
		{ "point2plane",	lpoint2plane},

		{ "CINTERFACE", NULL },

		{ NULL, NULL },
	};

	luaL_newlibtable(L,l);
	lua_pushlightuserdata(L, M);
	luaL_setfuncs(L,l,1);
	lua_pushlightuserdata(L, M);
	lua_setfield(L, -2, "CINTERFACE");
}

// util function

static math_t
math3d_from_lua_(lua_State *L, struct math_context *M, int index, int type) {
	math_t r;
	switch(type) {
	case MATH_TYPE_MAT:
		r = matrix_from_index(L, M, index);
		break;
	case MATH_TYPE_VEC4:
		r = vector_from_index(L, M, index);
		break;
	case MATH_TYPE_QUAT:
		r = quat_from_index(L, M, index);
		break;
	default:
		luaL_error(L, "Invalid math3d object type %d", type);
		return MATH_NULL;
	}
	return r;
}

static math_t
math3d_from_lua_id_(lua_State *L, struct math_context *M, int index) {
	math_t id = get_id_api(L, M, index);
	return id;
}

static void
math3d_push_(lua_State *L, struct math_context *M, const float *v, int type) {
	math_t id = math_import(M, v, type, 1);
	lua_pushlightuserdata(L, MATH_TO_HANDLE(id));
}

static void
math3d_ref_(lua_State *L, struct math_context *M, const float *v, int type) {
	math_t id = math_ref(M, v, type, 1);
	lua_pushlightuserdata(L, MATH_TO_HANDLE(id));
}

static math_t
math3d_mark_id_(lua_State *L, struct math_context *M, int idx) {
	math_t id = get_id_api(L, M, idx);
	return math_mark(M, id);
}

static void
math3d_unmark_id_(struct math_context *M, math_t id) {
	math_unmark(M, id);
}

static float *
math3d_getptr_(struct math_context *M, math_t id, int *type) {
	if (type) {
		*type = math_type(M, id);
	}
	return math_init(M, id);
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

	struct math3d_api * M = lua_newuserdatauv(L, sizeof(struct math3d_api), 0);
	M->MC = math_new();
	M->refmeta = lua_topointer(L, refmeta);
	M->from_lua = math3d_from_lua_;
	M->from_lua_id = math3d_from_lua_id_;
	M->mark_id = math3d_mark_id_;
	M->unmark_id = math3d_unmark_id_;
	M->push = math3d_push_;
	M->ref = math3d_ref_;
	M->getptr = math3d_getptr_;

	finalize(L, boxstack_gc);
	lua_setfield(L, LUA_REGISTRYINDEX, MATH3D_CONTEXT);

	init_math3d_api(L, M);

	lua_pushlightuserdata(L, M);	// upvalue 1 of .ref

	// init reobject meta table, it's upvalue 2 of .ref
	lua_pushvalue(L, refmeta);
	lua_pushlightuserdata(L, M);
	luaL_setfuncs(L,ref_mt, 1);

	lua_pushcclosure(L, lref, 2);
	lua_setfield(L, -2, "ref");

	return 1;
}
