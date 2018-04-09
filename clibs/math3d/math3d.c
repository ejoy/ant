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

static const char *
get_typename(int t) {
	static const char * typename[] = {
		"matrix",
		"vector4",
		"vector3",
		"quaternion",
		"number",
	};
	if (t < 0 || t >= sizeof(typename)/sizeof(typename[0]))
		return "unknown";
	return typename[t];
}

static inline int64_t
pop(lua_State *L, struct lastack *LS) {
	int64_t v = lastack_pop(LS);
	if (v == 0)
		luaL_error(L, "pop empty stack");
	return v;
}

struct boxpointer {
	struct lastack *LS;
	int defautlHomogeneousDepth;
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
value_tostring(lua_State *L, const char * prefix, float *r, int type) {
	switch (type) {
	case LINEAR_TYPE_MAT:
		lua_pushfstring(L, "%sMAT (%f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f : %f,%f,%f,%f)",
			prefix,
			r[0],r[1],r[2],r[3],
			r[4],r[5],r[6],r[7],
			r[8],r[9],r[10],r[11],
			r[12],r[13],r[14],r[15]
		);
		break;
	case LINEAR_TYPE_VEC4:
		lua_pushfstring(L, "%sVEC4 (%f,%f,%f,%f)", prefix, r[0],r[1],r[2],r[3]);
		break;
	case LINEAR_TYPE_VEC3:
		lua_pushfstring(L, "%sVEC3 (%f,%f,%f,%f)", prefix, r[0],r[1],r[2]);
		break;
	case LINEAR_TYPE_QUAT:
		lua_pushfstring(L, "%sQUAT (%f,%f,%f,%f)", prefix, r[0],r[1],r[2],r[3]);
		break;
	case LINEAR_TYPE_NUM:
		lua_pushfstring(L, "%sNUMBER (%f)", prefix, r[0]);
		break;
	case LINEAR_TYPE_EULER:
		lua_pushfstring(L, "%sEULER (yaw(y) = %f, pitch(x) = %f, roll(z) = %f)", prefix, r[0], r[1], r[2]);
		break;
	default:
		lua_pushfstring(L, "%sUNKNOWN", prefix);
		break;
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

static inline float
get_table_value(lua_State *L, int idx) {
	lua_geti(L, -1, idx);
	float s = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return s;
}

static inline int64_t
get_ref_id(lua_State *L, struct lastack *LS, int index) {
	struct refobject * ref = lua_touserdata(L, index);
	if (lua_rawlen(L, index) != sizeof(*ref)) {
		luaL_error(L, "The userdata is not a ref object");
	}
	if (ref->LS == NULL) {
		ref->LS = LS;
	}
	else if (ref->LS != LS) {
		luaL_error(L, "ref object not belongs this stack");
	}

	return ref->id;
}

static inline int64_t
get_id_by_type(lua_State *L, struct lastack *LS, int lType, int index){
	return lType == LUA_TNUMBER ? get_id(L, index) : get_ref_id(L, LS, index);
}

static inline void
extract_scale_mat(lua_State *L, struct lastack *LS, int index, union matrix44 *m){	
	int stype = lua_getfield(L, index, "s");	
	if (stype == LUA_TNUMBER || stype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, stype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);
		switch (type)
		{
		case LINEAR_TYPE_VEC4:
		case LINEAR_TYPE_VEC3:
			matrix44_scalemat(m, value[0], value[1], value[2]);
			break;
		default:
			luaL_error(L, "linear type should be vec3/vec4, type is : %d", type);
			break;
		}
	} else if (stype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);
		float v[3];
		if (len == 1) {
			float s = get_table_value(L, 1);
			v[0] = v[1] = v[2] = s;
		} else if (len == 3) {
			for (int i = 0; i < 3; ++i)
				v[i] = get_table_value(L, i+1);
		} else {
			luaL_error(L, "using table for s element, format must be s = {1}/{1, 2, 3}, give number : %d", len);
		}
		matrix44_scalemat(m, v[0], v[1], v[2]);
	} else {
		matrix44_identity(m);
	}
	lua_pop(L, 1);
}

static inline void
extract_translate_mat(lua_State *L, struct lastack *LS, int index, union matrix44 *m){
	const int ttype = lua_getfield(L, index, "t");
	if (ttype == LUA_TNUMBER || ttype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, ttype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);
		if (type != LINEAR_TYPE_VEC3 && type != LINEAR_TYPE_VEC4)
			luaL_error(L, "t field should provide vec3/vec4, provide type is : %d", type);

		if (value == NULL)
			luaL_error(L, "invalid id : %ld, get NULL value", id);
		matrix44_trans(m, value[0], value[1], value[2]);
	} else if (ttype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);
		if (len != 3)
			luaL_error(L, "r field should : t={1, 2, 3}, only accept 3 value, %d is give", len);

		float v[3];
		for (int i = 0; i < 3; ++i)
			v[i] = get_table_value(L, i + 1);
		matrix44_trans(m, v[0], v[1], v[2]);
	} else {
		matrix44_identity(m);
	}

	lua_pop(L, 1);
}

static inline void
extract_rotation_mat(lua_State *L, struct lastack *LS, int index, union matrix44 *m){
	int rtype = lua_getfield(L, index, "r");

	if (rtype == LUA_TNUMBER || rtype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, rtype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);

		struct euler e;
		switch (type)
		{
		case LINEAR_TYPE_VEC4:
		case LINEAR_TYPE_VEC3:		
			e.pitch = value[0];
			e.yaw = value[1];
			e.roll = value[2];
			break;
		case LINEAR_TYPE_EULER:
			memcpy(&e, value, sizeof(struct euler));
			break;
		default:
			luaL_error(L, "linear type should be vec3/vec4/euler, type is : %d", type);
			break;
		}

		matrix44_rot(m, &e);
	} else if (rtype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);
		if (len != 3)
			luaL_error(L, "r field should : r={1, 2, 3}, only accept 3 value, %d is give", len);
		//the table is define as : rotate x-axis(pitch), rotate y-axis(yaw), rotate z-axis(roll)
		struct euler e = { get_table_value(L, 2), get_table_value(L, 1), get_table_value(L, 3) };	// x -> pitch, y -> yaw, z -> roll
		matrix44_rot(m, &e);
	} else {		
		matrix44_identity(m);
	}

	lua_pop(L, 1);
}

static void inline 
push_srt(lua_State *L, struct lastack *LS, int index) {
	union matrix44 s, r, t;
	matrix44_identity(&s);
	matrix44_identity(&r);
	matrix44_identity(&t);
	extract_scale_mat(L, LS, index, &s);
	extract_rotation_mat(L, LS, index, &r);
	extract_translate_mat(L, LS, index, &t);
	union matrix44 srt;
	matrix44_mul(&srt, &s, &r);
	matrix44_mul(&srt, &srt, &t);
	lastack_pushmatrix(LS, srt.x);
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
	if (type == MAT_PERSPECTIVE && lua_getfield(L, index, "fov") == LUA_TNUMBER) {
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
	int homogeneousDepth = 0;
	if (lua_isnil(L, -1)) {
		struct boxpointer *p = lua_touserdata(L, lua_upvalueindex(1));
		homogeneousDepth = p->defautlHomogeneousDepth;
	} else {
		homogeneousDepth = lua_toboolean(L, -1);
	}

	lua_pop(L, 1);

	union matrix44 m;
	if (type == MAT_PERSPECTIVE) {
		matrix44_perspective(&m, left, right, bottom, top, near, far, homogeneousDepth);
	} else {
		matrix44_ortho(&m, left, right, bottom, top, near, far, homogeneousDepth);
	}
	lastack_pushmatrix(LS, m.x);
}

static inline const char * 
get_type_field(lua_State *L, int index) {
	const char* type = NULL;
	if (lua_getfield(L, index, "type") == LUA_TSTRING) {
		type = lua_tostring(L, -1);
		lua_pop(L, 1);
	}

	return type;
}

static inline void
push_quat_with_axis_angle(lua_State* L, struct lastack *LS, int index) {
	// get axis
	lua_getfield(L, index, "axis");

	float axis[3];
	int axis_type = lua_type(L, -1);
	switch (axis_type) {
	case LUA_TTABLE: {
		for (int i = 0; i < 3; ++i) {
			lua_geti(L, -1, i + 1);
			axis[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		break;
	}
	case LUA_TNUMBER: {
		int64_t stackid = get_id(L, -1);
		int t;
		const float *address = lastack_value(LS, stackid, &t);
		memcpy(axis, address, sizeof(float) * 3);
		break;
	}
	case LUA_TSTRING: {
		const char* t = lua_tostring(L, -1);
		axis[0] = 0; axis[1] = 0; axis[2] = 0;
		if (strcmp(t, "x") == 0 || strcmp(t, "X") == 0)
			axis[0] = 1;
		else if (strcmp(t, "y") == 0 || strcmp(t, "Y") == 0)
			axis[1] = 1;
		else if (strcmp(t, "z") == 0 || strcmp(t, "X") == 0)
			axis[2] = 1;
		else
			luaL_error(L, "not support this string type : %s", t);
		break;
	}
	default:
		luaL_error(L, "quaternion axis angle init, only support table and number, type is : %d", axis_type);
	}

	lua_pop(L, 1);

	// get angle
	lua_getfield(L, index, "angle");
	int angle_type = lua_type(L, -1);
	if (angle_type != LUA_TTABLE) {
		luaL_error(L, "angle should define as angle = {xx}");
	}
	lua_geti(L, -1, 1);
	float angle = lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_pop(L, 1);

	struct quaternion q;
	quaternion_init_from_axis_angle(&q, axis, angle);
	lastack_pushquat(LS, &q.x);
}

static inline void
push_quat_with_euler(lua_State* L, struct lastack *LS, int index) {
	lua_getfield(L, index, "ypr");
	struct euler e;
	int luaType = lua_type(L, -1);
	switch (luaType)
	{
	case LUA_TTABLE: {
		float * v = euler_array(&e);
		for (int i = 0; i < 3; ++i) {
			lua_geti(L, -1, i + 1);
			v[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}

		break;
	}
	case LUA_TNUMBER: {
		int64_t stackid = get_id(L, -1);
		int type;
		float *value = lastack_value(LS, stackid, &type);
		if (type == LINEAR_TYPE_VEC3 || type == LINEAR_TYPE_VEC4 || type == LINEAR_TYPE_EULER) {
			memcpy(euler_array(&e), value, sizeof(float) * 3);
		} else {
			luaL_error(L, "using vec3/vec4 to define roll(z) pitch(x) yaw(y), type define is : %d", type);
		}

		break;
	}
	default:
		luaL_error(L, "create quaternion from euler failed, unknown type, %d", luaType);
	}

	lua_pop(L, 1);

	struct quaternion q;
	
	quaternion_init_from_euler(&q, &e);
	lastack_pushquat(LS, &(q.x));
}

static inline void 
push_quat(lua_State* L, struct lastack *LS, int index) {
	lua_getfield(L, index, "ypr");	// ypr -> yaw, pitch, roll
	int curType = lua_type(L, -1);
	lua_pop(L, 1);

	if (curType == LUA_TTABLE || curType == LUA_TNUMBER) {
		push_quat_with_euler(L, LS, index);
	} else {
		push_quat_with_axis_angle(L, LS, index);
	}
}

static inline void
push_euler(lua_State *L, struct lastack *LS, int index) {
	struct euler e = { 0 };
	size_t n = lua_rawlen(L, index);
	
	if (n == 3) {
		float *v = euler_array(&e);
		for (int i = 0; i < n; ++i) {
			lua_geti(L, index, i + 1);
			v[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
	} else {
		const char* names[] = { "yaw", "pitch", "roll" };
		float *v = euler_array(&e);
		for (int i = 0; i < (sizeof(names) / sizeof(names[0])); ++i) {
			lua_getfield(L, index, names[i]);
			if (lua_type(L, -1) != LUA_TNIL) {
				v[i] = lua_tonumber(L, -1);
			}
			lua_pop(L, 1);
		}
	}
	
	lastack_pusheuler(LS, euler_array(&e));
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
		const char * type = get_type_field(L, index);
		if (type == NULL || strcmp(type, "srt") == 0) {
			push_srt(L, LS, index);		
		} else if (strcmp(type, "proj") == 0) {
			push_mat(L, LS, index, MAT_PERSPECTIVE);
		} else if (strcmp(type, "ortho") == 0) {
			push_mat(L, LS, index, MAT_ORTHO);
		} else if (strcmp(type, "quat") == 0 || strcmp(type, "q") == 0) {
			push_quat(L, LS, index);
		} else if (strcmp(type, "euler") == 0 || strcmp(type, "e") == 0) {
			push_euler(L, LS, index);
		} else {
			luaL_error(L, "Invalid matrix type %s", type);
		}
		return;
	}
	luaL_checkstack(L, (int)n, NULL);
	for (i = 0; i < n; ++i) {
		lua_geti(L, index, i + 1);
		v[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	switch (n) {	
	case 1:
		lastack_pushnumber(LS, v[0]);
		break;
	case 3: {
		const char* type = get_type_field(L, index);
		if (type == NULL)
			lastack_pushvec3(LS, v);
		else
			push_euler(L, LS, index);
		break;
	}
	case 4:	{
		const char* type = get_type_field(L, index);
		if (type != NULL && strcmp(type, "quat") == 0)
			lastack_pushquat(LS, v);
		else
			lastack_pushvec4(LS, v);				
		break;
	}		
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
pop2_values(lua_State *L, struct lastack *LS, float *val[2], int types[2]) {
	int64_t v1 = pop(L, LS);
	int64_t v2 = pop(L, LS);

	val[1] = lastack_value(LS, v1, types);
	val[0] = lastack_value(LS, v2, types + 1);
	if (types[0] != types[1])
		luaL_error(L, "type mismatch");
}

static void
add_2values(lua_State *L, struct lastack *LS) {
	float *val[2];
	int types[2];
	pop2_values(L, LS, val, types);
	float ret[4];
	switch (types[0]) {
	case LINEAR_TYPE_NUM:
		ret[0] = val[0][0] + val[1][0];
		lastack_pushnumber(LS, ret[0]);
		break;
	case LINEAR_TYPE_VEC3:
		ret[0] = val[0][0] + val[1][0];
		ret[1] = val[0][1] + val[1][1];
		ret[2] = val[0][2] + val[1][2];
		lastack_pushvec3(LS, ret);
		break;
	case LINEAR_TYPE_VEC4:
		ret[0] = val[0][0] + val[1][0];
		ret[1] = val[0][1] + val[1][1];
		ret[2] = val[0][2] + val[1][2];
		ret[3] = val[0][3] + val[1][3];
		lastack_pushvec4(LS, ret);
		break;
	case LINEAR_TYPE_EULER:
		ret[0] = val[0][0] + val[1][0];
		ret[1] = val[0][1] + val[1][1];
		ret[2] = val[0][2] + val[1][2];
		lastack_pusheuler(LS, ret);
		break;
	default:
		luaL_error(L, "Invalid type %d to add", types[0]);
	}
}

static void
sub_2values(lua_State *L, struct lastack *LS) {
	float *val[2];
	int types[2];
	pop2_values(L, LS, val, types);
	float ret[4];
	switch (types[0]) {
	case LINEAR_TYPE_NUM:
		ret[0] = val[0][0] - val[1][0];
		lastack_pushnumber(LS, ret[0]);
		break;
	case LINEAR_TYPE_VEC3:
		ret[0] = val[0][0] - val[1][0];
		ret[1] = val[0][1] - val[1][1];
		ret[2] = val[0][2] - val[1][2];
		lastack_pushvec3(LS, ret);
	case LINEAR_TYPE_VEC4:
		ret[0] = val[0][0] - val[1][0];
		ret[1] = val[0][1] - val[1][1];
		ret[2] = val[0][2] - val[1][2];
		ret[3] = val[0][3] - val[1][3];
		lastack_pushvec4(LS, ret);
		break;
	case LINEAR_TYPE_EULER:
		ret[0] = val[0][0] - val[1][0];
		ret[1] = val[0][1] - val[1][1];
		ret[2] = val[0][2] - val[1][2];
		lastack_pusheuler(LS, ret);
		break;

	default:
		luaL_error(L, "Invalid type %d to add", types[0]);
	}
}

//static float *
//pop_value(lua_State *L, struct lastack *LS, int nt) {
//	int64_t v = pop(L, LS);
//	int t = 0;
//	float * r = lastack_value(LS, v, &t);
//	if (t != nt) {
//		luaL_error(L, "type mismatch, %s/%s", get_typename(t), get_typename(nt));
//	}
//	return r;
//}

static float *
pop_value(lua_State *L, struct lastack *LS, int *type) {
	int64_t v = pop(L, LS);
	int t = 0;
	float * r = lastack_value(LS, v, &t);	
	if (type)
		*type = t;
	return r;
}

static void
normalize_vector3(lua_State *L, struct lastack *LS) {
	int t;
	float *v = pop_value(L, LS, &t);
	float r[4];
	float invLen = 1.0f / vector3_length((struct vector3 *)v);
	r[0] = v[0] * invLen;
	r[1] = v[1] * invLen;
	r[2] = v[2] * invLen;
	if (t == LINEAR_TYPE_VEC4) {
		r[3] = v[3];
		lastack_pushvec4(LS, r);
	} else {
		lastack_pushvec3(LS, r);
	}
}

#define BINTYPE(v1, v2) (((v1) << LINEAR_TYPE_BITS_NUM) + (v2))

static void
mul_2values(lua_State *L, struct lastack *LS) {
	int64_t v1 = pop(L, LS);
	int64_t v0 = pop(L, LS);
	int t0,t1;
	float * val1 = lastack_value(LS, v1, &t1);
	float * val0 = lastack_value(LS, v0, &t0);
	int type = BINTYPE(t0,t1);
	switch (type) {
	case BINTYPE(LINEAR_TYPE_MAT,LINEAR_TYPE_MAT): {
		union matrix44 m;
		matrix44_mul(&m, (union matrix44 *)val0, (union matrix44 *)val1);
		lastack_pushmatrix(LS, m.x);
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_MAT): {
		float r[4];
		vector4_mul_matrix44(r, val0, (union matrix44 *)val1);
		lastack_pushvec4(LS, r);
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_NUM): {
		float r[4] = {
			val0[0] * val1[0],
			val0[1] * val1[0],
			val0[2] * val1[0],
			val0[3] * val1[0],
		};
		lastack_pushvec4(LS, r);
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC3, LINEAR_TYPE_NUM): {
		float r[3] = {
			val0[0] * val1[0],
			val0[1] * val1[0],
			val0[2] * val1[0],
		};
		lastack_pushvec3(LS, r);
		break;
	}
	case BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_QUAT): {
		struct quaternion result;
		quaternion_mul(&result, (const struct quaternion*)val0, (const struct quaternion*)val1);
		lastack_pushquat(LS, &(result.x));
		break;
	}
	case BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_VEC4): {
		const struct quaternion * q = (const struct quaternion *)val0;
		const struct vector4 * v = (const struct vector4*)val1;

		struct vector4 result;
		result.w = v->w;
		quaternion_rotate_vec4(&result, q, v);
		lastack_pushvec4(LS, &(result.x));
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_QUAT): {	
		const struct quaternion * q = (const struct quaternion *)val1;
		const struct vector4 * v = (const struct vector4 *)val0;
		
		struct vector4 result;
		result.w = v->w;
		vec4_rotate_quaternion(&result, v, q);
		lastack_pushvec4(LS, &(result.x));
		break;
	}

	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_EULER):
	case BINTYPE(LINEAR_TYPE_EULER, LINEAR_TYPE_VEC4):{
		const struct euler *e = (const struct euler*)(type == BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_EULER) ? val1 : val0);
		const struct vector4 *v = (const struct vector4*)(type == BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_EULER) ? val0 : val1);

		struct quaternion q;

		//struct quaternion qx, qy;
		//float axisx[3] = { 1, 0, 0 }, axisy[3] = { 0, 1, 0 };

		//// order is : yaw pitch roll
		//quaternion_init_from_axis_angle(&qy, axisy, e->yaw);
		//quaternion_init_from_axis_angle(&qx, axisx, e->pitch);
		//
		//quaternion_mul(&q, &qy, &qx);	
		quaternion_init_from_euler(&q, e);

		struct vector4 r;
		quaternion_rotate_vec4(&r, &q, v);
		lastack_pushvec4(LS, vector4_array(&r));
		break;
	}


	default:
		luaL_error(L, "Need support type %s * type %s", get_typename(t0),get_typename(t1));
	}
}

static void mulH_2values(lua_State *L, struct lastack *LS){
	int64_t v1 = pop(L, LS);
	int64_t v0 = pop(L, LS);
	int t0, t1;
	float * val1 = lastack_value(LS, v1, &t1);
	float * val0 = lastack_value(LS, v0, &t0);
	if (t0 != LINEAR_TYPE_VEC4 && t1 != LINEAR_TYPE_MAT)
		luaL_error(L, "'%' operator only support vec4 * mat, type0 is : %d, type1 is : %d", t0, t1);

	float r[4];
	vector4_mul_matrix44(r, val0, (union matrix44 *)val1);
	if (!is_zero(r[3]))
	{
		float invW = 1.f / fabs(r[3]);
		r[0] *= invW;
		r[1] *= invW;
		r[2] *= invW;
		r[3] = 1;
	}

	lastack_pushvec4(LS, r);
}

static void
transposed_matrix(lua_State *L, struct lastack *LS) {
	int t;
	float *mat = pop_value(L, LS, &t);
	if (t != LINEAR_TYPE_MAT)
		luaL_error(L, "transposed_matrix need mat4 type, type is : %d", t);
	union matrix44 m;
	memcpy(&m, mat, sizeof(m));
	matrix44_transposed(&m);
	lastack_pushmatrix(LS, m.x);
}

static void
inverted_matrix(lua_State *L, struct lastack *LS) {
	int t;
	float *mat = pop_value(L, LS, &t);
	if (t != LINEAR_TYPE_MAT)
		luaL_error(L, "inverted_matrix need mat4 type, type is : %d", t);
	
	union matrix44 r;
	matrix44_inverted(&r, (union matrix44 *)mat);
	lastack_pushmatrix(LS, r.x);
}

static void
top_tostring(lua_State *L, struct lastack *LS) {
	int64_t v = lastack_top(LS);
	if (v == 0)
		luaL_error(L, "top empty stack");
	int t = 0;
	float * r = lastack_value(LS, v, &t);
	value_tostring(L, "", r, t);
}

static void
lookat_matrix(lua_State *L, struct lastack *LS, int direction) {
	int t0, t1;
	float *at = pop_value(L, LS, &t0);
	float *eye = pop_value(L, LS, &t1);
	if (t0 != LINEAR_TYPE_VEC3 && t0 != LINEAR_TYPE_VEC4)
		luaL_error(L, "lookat_matrix, arg0 need vec3/vec4, arg0 is : %d", t0);
	if (t0 != t1)
		luaL_error(L, "lookat_matrix, arg0 and arg1 type mismatch, arg0 is : %d, arg1 is : %d", t0, t1);
	
	union matrix44 m;
	if (direction)
		matrix44_lookat_eye_direction(&m, (struct vector3*)eye, (struct vector3 *)at, NULL);
	else
		matrix44_lookat(&m, (struct vector3 *)eye, (struct vector3 *)at, NULL);
	lastack_pushmatrix(LS, m.x);
}

static void
unpack_top(lua_State *L, struct lastack *LS) {
	int64_t v = pop(L, LS);
	int t = 0;
	float * r = lastack_value(LS, v, &t);
	switch(t) {
	case LINEAR_TYPE_VEC4:
		lastack_pushnumber(LS, r[0]);
		lastack_pushnumber(LS, r[1]);
		lastack_pushnumber(LS, r[2]);
		lastack_pushnumber(LS, r[3]);
		break;
	case LINEAR_TYPE_MAT:
		lastack_pushvec4(LS, r+0);
		lastack_pushvec4(LS, r+4);
		lastack_pushvec4(LS, r+8);
		lastack_pushvec4(LS, r+12);
		break;
	case LINEAR_TYPE_QUAT: {
		float s = asinf(r[3]);
		if (is_zero(s))
			s = 0.00001f;

		float v[4] = {
			acosf(r[3]) * 2,
			r[0] / s,
			r[1] / s,
			r[2] / s,
		};

		lastack_pushvec4(LS, v);
		break;
	}		
	default:
		luaL_error(L, "Unpack invalid type %s", get_typename(t));
	}
}

static inline void
push_data_to_lua(struct lastack *LS, struct ref_stack *RS) {
	struct lua_State *L = RS->L;

	int64_t v = pop(L, LS);
	int type;
	float * val = lastack_value(LS, v, &type);
	lua_newtable(L);

#define TO_LUA_STACK(_VV, _LUA_STACK_IDX) lua_pushnumber(L, _VV);	lua_seti(L, -2, _LUA_STACK_IDX)
	switch (type)
	{
	case LINEAR_TYPE_MAT:
		for (int i = 0; i < 16; ++i) {
			TO_LUA_STACK(val[i], i + 1);
		}
		break;
	case LINEAR_TYPE_QUAT:
	case LINEAR_TYPE_VEC4:
		TO_LUA_STACK(val[3], 3 + 1);
	case LINEAR_TYPE_VEC3:
	case LINEAR_TYPE_EULER:
		for (int i = 0; i < 3; ++i) {
			TO_LUA_STACK(val[i], i + 1);
		}
		break;
	case LINEAR_TYPE_NUM:
		TO_LUA_STACK(val[0], 0 + 1);
		break;
	default:
		break;
	}
#undef TO_LUA_STACK

	// push type to table
	lua_pushstring(L, "type");
	lua_pushnumber(L, type);
	lua_settable(L, -3);
	refstack_pop(RS);
}

struct lnametype_pairs {
	const char* name;
	const char* alias;
	int type;
};

static inline void
get_lnametype_pairs(struct lnametype_pairs *p) {
#define SET(_P, _NAME, _ALIAS, _TYPE) (_P)->name = _NAME; (_P)->alias = _ALIAS; (_P)->type = _TYPE
	SET(p, "mat4x4",	"m",	LINEAR_TYPE_MAT);
	SET(p, "vec4",		"v",	LINEAR_TYPE_VEC4);
	SET(p, "vec3",		"v3",	LINEAR_TYPE_VEC3);
	SET(p, "quat",		"q",	LINEAR_TYPE_QUAT);
	SET(p, "num",		"n",	LINEAR_TYPE_NUM);	
}

static inline int
linear_name_to_type(const char* name) {
	struct lnametype_pairs pairs[LINEAR_TYPE_COUNT];
	get_lnametype_pairs(pairs);
	for (int i = 0; i < LINEAR_TYPE_COUNT; ++i) {
		const struct lnametype_pairs *p = pairs + i;
		if (strcmp(name, p->alias) == 0 || strcmp(name, p->name) == 0) {
			return p->type;
		}
	}

	return LINEAR_TYPE_NONE;
}

static inline void
convert_vec_to_euler(lua_State *L, struct lastack*LS) {
	int64_t id = pop(L, LS);
	int type;
	float *value = lastack_value(LS, id, &type);
	struct euler e = { 0 };
	if (lastack_is_vec_type(type)) {
		struct vector3 v = { value[0], value[1], value[2] };
		vector3_normalize(&v);
		vector3_to_rotation(&e, &v);
		euler_to_degree(&e);
	}

	lastack_pusheuler(LS, euler_array(&e));
}

static inline void
convert_rotation_to_view_dir(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float *v = lastack_value(LS, id, &type);
	switch (type){
		case LINEAR_TYPE_EULER:
		case LINEAR_TYPE_VEC3:
		case LINEAR_TYPE_VEC4:{
			struct euler e;
			if (type != LINEAR_TYPE_EULER){
				e.yaw = v[1], e.pitch = v[0], e.roll = v[2];
			} else {
				memcpy(&e, v, sizeof(e));
			}

			struct vector4 v4 = {0, 0, 1, 0};			
			if (!euler_is_identity(&e)){
				struct quaternion q;
				quaternion_init_from_euler(&q, &e);
				struct vector4 t = v4;
				quaternion_rotate_vec4(&v4, &q, &t);
				vector3_normalize(to_vector3(&v4));
			}
			lastack_pushvec4(LS, vector4_array(&v4));
			break;
		}
		default:
		luaL_error(L, "convect rotation to dir need euler/vec3/vec4 type, type given is : %d", type);
		break;
	}
}

static inline void
convert_view_dir_to_rotation(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float *v = lastack_value(LS, id, &type);
	switch (type){
		case LINEAR_TYPE_EULER:
		case LINEAR_TYPE_VEC3:
		case LINEAR_TYPE_VEC4: {
			struct euler e;
			if (type == LINEAR_TYPE_EULER){
				memcpy(&e, v, sizeof(e));
			} else {
				vector3_to_rotation(&e, (const struct vector3*)v);
				euler_to_degree(&e);
			}
			 
			struct vector4 v4 = {e.pitch, e.yaw, e.roll, 0};
			lastack_pushvec4(LS, vector4_array(&v4));
			break;
		}
	default:
		luaL_error(L, "view dir to rotation only accept vec3/vec4/euler, type given : %d", type);
		break;
	}
}

static inline void
split_mat_to_srt(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float* v = lastack_value(LS, id, &type);
	if (type != LINEAR_TYPE_MAT)
		luaL_error(L, "split operation '~' is only valid for mat4 type, type is : %d", type);
	
	const union matrix44 *mat = (const union matrix44*)v;

	// struct vector3 scale = {
	// 	vector3_length((const struct vector3*)(mat->c[0])),
	// 	vector3_length((const struct vector3*)(mat->c[1])),
	// 	vector3_length((const struct vector3*)(mat->c[2]))
	// };

	// struct vector3 rotation;
	// struct vector3 normalize_columns[3] = {
	// 	(*(const struct vector3*)(mat->c[0])),
	// 	(*(const struct vector3*)(mat->c[1])),
	// 	(*(const struct vector3*)(mat->c[2])),
	// };
	// for (int ii=0; ii<sizeof(normalize_columns)/sizeof(normalize_columns[0]); ++ii)
	// 	vector3_normalize(&normalize_columns[ii]);


	// rotation.y = asin(-normalize_columns[0].z);
	// if (is_zero(cos(rotation.y))){
	// 	rotation.x = atan2(-normalize_columns[2].x, normalize_columns[1].y);
	// 	rotation.z = 0;		
	// } else {
	// 	rotation.x = atan2(normalize_columns[1].z, normalize_columns[2].z);
	// 	rotation.z = atan2(normalize_columns[0].y, normalize_columns[0].x);
	// }

	// rotation.x = TO_DEGREE(rotation.x);
	// rotation.y = TO_DEGREE(rotation.y);
	// rotation.z = TO_DEGREE(rotation.z);

	// struct vector4 translate = {
	// 	mat->c[3][0],
	// 	mat->c[3][1],
	// 	mat->c[3][2],
	// 	1,
	// };

	struct vector3 scale, rotation, translate;
	matrix44_decompose2(mat, &translate, &rotation, &scale);

	rotation.x = TO_DEGREE(rotation.x);
	rotation.y = TO_DEGREE(rotation.y);
	rotation.z = TO_DEGREE(rotation.z);

	lastack_pushvec3(LS, vector3_array(&translate));
	lastack_pushvec3(LS, vector3_array(&rotation));
	lastack_pushvec3(LS, vector3_array(&scale));
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
	//case 'f':
	//	lua_pushnumber(L, pop_value(L,LS,LINEAR_TYPE_NUM)[0]);
	//	refstack_pop(RS);
	//	return 1;	
	case 'm':		
		lua_pushlightuserdata(L, pop_value(L, LS, NULL));
		return 1;

	case 'T': 	
		push_data_to_lua(LS, RS);
		return 1;
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
		int t0, t1;
		float * vec1 = pop_value(L, LS, &t0);
		float * vec2 = pop_value(L, LS, &t1);
		if (t0 != LINEAR_TYPE_VEC3 && t0 != LINEAR_TYPE_VEC4)
			luaL_error(L, "arg0 need vec3/vec4, t0 is : %d", t0);
		if (t0 != t1)
			luaL_error(L, "dot operation with type mismatch");
		
		lastack_pushnumber(LS, vector3_dot((struct vector3 *)vec1, (struct vector3 *)vec2));
		refstack_2_1(RS);
		break;
	}
	case 'x': {
		float r[4];
		int t1,t2;
		float * vec2 = pop_value(L, LS, &t1);
		float * vec1 = pop_value(L, LS, &t2);
		if (t1 != t2) {
			luaL_error(L, "cross type mismatch");
		}
		vector3_cross((struct vector3 *)r, (struct vector3 *)vec1, (struct vector3 *)vec2);
		if (t1 == LINEAR_TYPE_VEC3) {
			lastack_pushvec3(LS, r);
		} else {
			r[3] = 0.0f;
			lastack_pushvec4(LS, r);
		}
		refstack_2_1(RS);
		break;
	}
	case '*':
		mul_2values(L, LS);
		refstack_2_1(RS);
		break;

	case '%':
		mulH_2values(L, LS);
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
		sub_2values(L, LS);
		refstack_2_1(RS);
		break;
	case '+':
		add_2values(L, LS);
		refstack_2_1(RS);
		break;
	case 'l':
	case 'L': {
		int direction = cmd == 'L' ? 1 : 0;
		lookat_matrix(L, LS, direction);
		refstack_2_1(RS);
		break;
	}
	case '>':
		unpack_top(L, LS);
		refstack_pop(RS);
		refstack_push(RS);
		refstack_push(RS);
		refstack_push(RS);
		refstack_push(RS);
		break;	
	case 'e':
		convert_vec_to_euler(L, LS);
		refstack_1_1(RS);
		break;
	case 'd':
		convert_rotation_to_view_dir(L, LS);
		refstack_1_1(RS);
		break;
	case 'D':
		convert_view_dir_to_rotation(L, LS);
		refstack_1_1(RS);
		break;
	case '~':
		split_mat_to_srt(L, LS);
		refstack_pop(RS);
		refstack_push(RS);
		refstack_push(RS);
		refstack_push(RS);
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
		int64_t id = get_ref_id(L, LS, index);
		if (lastack_pushref(LS, id)) {
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
	int homogeneousDepth = 0;
	if (!lua_isnil(L, 1)) {
		homogeneousDepth = lua_toboolean(L, 1);
		lua_pop(L, 1);
	}
	struct boxpointer *bp = lua_newuserdata(L, sizeof(*bp));
	bp->defautlHomogeneousDepth = homogeneousDepth;	

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
	int t;
	int marked = lastack_marked(id, &t);
	lua_pushstring(L, get_typename(t));
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
