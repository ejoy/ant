#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

extern "C" {
	#include "linalg.h"	
	#include "refstack.h"
}

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtx/quaternion.hpp>

#include <glm/vector_relational.hpp>

#include <glm/gtx/euler_angles.hpp>


extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
}

#include <inttypes.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>

#include <vector>

#define LINALG "LINALG"
#define LINALG_REF "LINALG_REF"
#define MAT_PERSPECTIVE 0
#define MAT_ORTHO 1

static bool g_default_homogeneous_depth = false;

bool default_homogeneous_depth(){
	return g_default_homogeneous_depth;
}


static const char *
get_typename(uint32_t t) {
	static const char * type_names[] = {
		"matrix",
		"vector4",
		"vector3",
		"quaternion",
		"number",
	};
	if (t < 0 || t >= sizeof(type_names)/sizeof(type_names[0]))
		return "unknown";
	return type_names[t];
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
	
	struct boxpointer * ret =  (struct boxpointer *)luaL_checkudata(L, -1, LINALG);
	lua_pop(L, 1);
	return ret->LS;
}

static int
delLS(lua_State *L) {
	struct boxpointer *bp = (struct boxpointer *)lua_touserdata(L, 1);
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
	struct refobject * ref = (struct refobject *)lua_touserdata(L, 1);
	int sz;
	float * v = lastack_value(ref->LS, ref->id, &sz);
	if (v == NULL) {
		char tmp[64];
		return luaL_error(L, "Invalid ref object [%s]", lastack_idstring(ref->id, tmp));
	}
	value_tostring(L, "&", v, sz);
	return 1;
}

static inline const char*
get_linear_type_name(LinearType lt) {
	const char * names[] = {
		"mat", "v4", "quat", "num", "euler", "",
	};

	assert((sizeof(names) / sizeof(names[0])) > size_t(lt));
	return names[lt];
}

static inline void
push_obj_to_lua_table(lua_State *L, struct lastack *LS, int64_t id){
	int type;
	float * val = lastack_value(LS, id, &type);
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
	lua_pushstring(L, get_linear_type_name(LinearType(type)));	
	lua_setfield(L, -2, "type");
}

static inline int
is_ref_obj(lua_State *L){
	size_t si = lua_rawlen(L, 1);
	return si == sizeof(struct refobject);
}

static int
ref_to_value(lua_State *L) {
	if (!is_ref_obj(L)){
		luaL_error(L, "arg 1 is not a math3d refobject!");
	}

	struct refobject *ref = (struct refobject *)lua_touserdata(L, 1);
	push_obj_to_lua_table(L, ref->LS, ref->id);

	return 1;
}

static int 
lref_get(lua_State *L){
	int ltype = lua_type(L, 2);
	if (ltype != LUA_TSTRING){
		luaL_error(L, "ref object __index meta function only support index as string, type given is : %d", ltype);
	}

	const char* name = lua_tostring(L, 2);
	if (strcmp(name, "value") == 0){
		lua_pushcfunction(L, ref_to_value);
		return 1;
	}

	luaL_error(L, "not support index : %s", name);
	return 0;
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

static void
assign_ref(lua_State *L, struct refobject * ref, int64_t rid) {
	int64_t markid = lastack_mark(ref->LS, rid);
	if (markid == 0) {
		return luaL_error(L, "Mark invalid object id");
	}
	lastack_unmark(ref->LS, ref->id);
	ref->id = markid;
}

static int
lassign(lua_State *L) {
	struct refobject * ref = (struct refobject *)lua_touserdata(L, 1);
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
			return luaL_error(L, "assign operation : type mismatch");
		}

		assign_ref(L, ref, rid);
		break;
	}
	case LUA_TUSERDATA: {
		struct refobject *rv = (struct refobject *)lua_touserdata(L, 2);
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
	struct refobject * ref = (struct refobject *)lua_touserdata(L, 1);
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
	struct refobject * ref = (struct refobject *)lua_newuserdata(L, sizeof(*ref));
	ref->LS = NULL;
	ref->id = lastack_constant(cons);

	luaL_setmetatable(L, LINALG_REF);
	return 1;
}

static int
lisvalid(lua_State *L){
	int type = lua_type(L, 1);
	if (type == LUA_TNUMBER){
		int number = lua_tonumber(L, -1);
		struct boxpointer *p = (struct boxpointer *)lua_touserdata(L, lua_upvalueindex(1));
		void *value = lastack_value(p->LS, number, NULL);
		lua_pushboolean(L, value != NULL);
	} else if (type == LUA_TUSERDATA || type == LUA_TLIGHTUSERDATA){
		lua_pushboolean(L, is_ref_obj(L));
	} else {
		lua_pushboolean(L, 0);
	}
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
	struct refobject * ref = (struct refobject *)lua_touserdata(L, index);
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

static inline glm::vec3
extract_scale(lua_State *L, struct lastack *LS, int index){	
	glm::vec3 scale(1, 1, 1);
	int stype = lua_getfield(L, index, "s");	
	if (stype == LUA_TNUMBER || stype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, stype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);
		switch (type)
		{
		case LINEAR_TYPE_VEC4:
			scale = *(glm::vec3*)value;
			break;
		default:
			luaL_error(L, "linear type should be vec3/vec4, type is : %d", type);
			break;
		}
	} else if (stype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);		
		if (len == 1) {
			float s = get_table_value(L, 1);
			scale[0] = scale[1] = scale[2] = s;
		} else if (len == 3) {
			for (int i = 0; i < 3; ++i)
				scale[i] = get_table_value(L, i+1);
		} else {
			luaL_error(L, "using table for s element, format must be s = {1}/{1, 2, 3}, give number : %d", len);
		}		
	}
	lua_pop(L, 1);

	return scale;
}

static inline glm::vec3
extract_translate(lua_State *L, struct lastack *LS, int index){
	glm::vec3 translate(0, 0, 0);
	const int ttype = lua_getfield(L, index, "t");
	if (ttype == LUA_TNUMBER || ttype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, ttype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);
		if (type != LINEAR_TYPE_VEC4)
			luaL_error(L, "t field should provide vec4, provide type is : %d", type);

		if (value == NULL)
			luaL_error(L, "invalid id : %ld, get NULL value", id);
		
		translate = *((glm::vec3*)value);
	} else if (ttype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);
		if (len != 3)
			luaL_error(L, "t field should : t={1, 2, 3}, only accept 3 value, %d is give", len);

		for (int i = 0; i < 3; ++i)
			translate[i] = get_table_value(L, i + 1);

	}

	lua_pop(L, 1);
	return translate;
}

static inline void
extract_rotation_mat(lua_State *L, struct lastack *LS, int index, glm::mat4x4 &m){
	int rtype = lua_getfield(L, index, "r");

	if (rtype == LUA_TNUMBER || rtype == LUA_TUSERDATA) {
		int64_t id = get_id_by_type(L, LS, rtype, -1);
		int type;
		float *value = lastack_value(LS, id, &type);

		if (type != LINEAR_TYPE_VEC4 && type != LINEAR_TYPE_EULER)
			luaL_error(L, "ref object need should be vec4/euler!, type is : %d", type);

		m = glm::mat4x4(glm::quat(glm::radians(*(const glm::vec3*)value)));
	} else if (rtype == LUA_TTABLE) {
		size_t len = lua_rawlen(L, -1);
		if (len != 3)
			luaL_error(L, "r field should : r={1, 2, 3}, only accept 3 value, %d is give", len);
		//the table is define as : rotate x-axis(pitch), rotate y-axis(yaw), rotate z-axis(roll)

		glm::vec3 e;
		for (int ii = 0; ii < 3; ++ii)
			e[ii] = get_table_value(L, ii + 1);		

		// be careful here, glm::quat(euler_angles) result is different from eulerAngleXYZ()
		// keep the same order with glm::quat
		m = glm::mat4x4(glm::quat(glm::radians(e)));	
	} else {
		m = glm::mat4x4(1.f);
	}

	lua_pop(L, 1);
}

static void inline 
push_srt(lua_State *L, struct lastack *LS, int index) {
	glm::mat4x4 srt(1);

	const glm::vec3 scale = extract_scale(L, LS, index);
	srt[0][0] = scale[0];
	srt[1][1] = scale[1];
	srt[2][2] = scale[2];

	glm::mat4x4 rotMat(1);
	extract_rotation_mat(L, LS, index, rotMat);
	srt = rotMat * srt;

	const glm::vec3 translate = extract_translate(L, LS, index);	
	srt[3] = glm::vec4(translate, 1);
	lastack_pushmatrix(LS, &srt[0][0]);
}

static int
get_mat_type(lua_State *L, int index) {
	const int ret_type = lua_getfield(L, index, "ortho");
	if (ret_type == LUA_TNIL || ret_type == LUA_TNONE) {
		return MAT_PERSPECTIVE;
	}

	if (ret_type != LUA_TBOOLEAN) {
		luaL_error(L, "ortho field must be boolean type, get %d", ret_type);
	}

	const int mat_type = lua_toboolean(L, -1) != 0 ? MAT_ORTHO : MAT_PERSPECTIVE;
	lua_pop(L, 1);

	return mat_type;
}

static void
push_mat(lua_State *L, struct lastack *LS, int index) {
	float left,right,top,bottom;
	lua_getfield(L, index, "n");
	float near = luaL_optnumber(L, -1, 0.1f);
	lua_pop(L, 1);
	lua_getfield(L, index, "f");
	float far = luaL_optnumber(L, -1, 100.0f);
	lua_pop(L, 1);

	const int type = get_mat_type(L, index);
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

	lua_pop(L, 1);

	glm::mat4x4 m;
	if (type == MAT_PERSPECTIVE) {
		m = g_default_homogeneous_depth ?
			glm::frustumLH_NO(left, right, bottom, top, near, far):
			glm::frustumLH_ZO(left, right, bottom, top, near, far);		
	} else {
		m = g_default_homogeneous_depth ?
			glm::orthoLH_NO(left, right, bottom, top, near, far) :
			glm::orthoLH_ZO(left, right, bottom, top, near, far);
	}
	lastack_pushmatrix(LS, &m[0][0]);
}

static inline const char*
get_field(lua_State *L, int index, const char* name) {
	const char* field = NULL;
	if (lua_getfield(L, index, name) == LUA_TSTRING) {
		field = lua_tostring(L, -1);
		lua_pop(L, 1);
	}

	return field;
}

static inline const char * 
get_type_field(lua_State *L, int index) {
	return get_field(L, index, "type");
}

static inline void
push_quat_with_axis_angle(lua_State* L, struct lastack *LS, int index) {
	// get axis
	lua_getfield(L, index, "axis");

	glm::vec3 axis;
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
		memcpy(&axis.x, address, sizeof(float) * 3);
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

	glm::quat q = glm::angleAxis(glm::radians(angle), axis);
	lastack_pushquat(LS, &q.x);
}

static inline void
push_quat_with_euler(lua_State* L, struct lastack *LS, int index) {
	lua_getfield(L, index, "pyr");
	glm::vec3 e;
	int luaType = lua_type(L, -1);
	switch (luaType)
	{
	case LUA_TTABLE: {		
		for (int i = 0; i < 3; ++i) {
			lua_geti(L, -1, i + 1);
			e[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}

		break;
	}
	case LUA_TNUMBER: {
		int64_t stackid = get_id(L, -1);
		int type;
		float *value = lastack_value(LS, stackid, &type);
		if (type == LINEAR_TYPE_VEC4 || type == LINEAR_TYPE_EULER) {
			memcpy(&e, value, sizeof(float) * 3);
		} else {
			luaL_error(L, "using vec3/vec4 to define roll(z) pitch(x) yaw(y), type define is : %d", type);
		}

		break;
	}
	default:
		luaL_error(L, "create quaternion from euler failed, unknown type, %d", luaType);
	}

	lua_pop(L, 1);

	glm::quat q(glm::radians(e));
	lastack_pushquat(LS, &(q.x));
}

static inline void 
push_quat(lua_State* L, struct lastack *LS, int index) {
	lua_getfield(L, index, "pyr");	// pyr -> pitch, yaw, roll
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
	glm::vec3 e;
	uint32_t n = (uint32_t)lua_rawlen(L, index);
	
	if (n == 3) {		
		for (uint32_t i = 0; i < n; ++i) {
			lua_geti(L, index, i + 1);
			e[i] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
	} else {
		const char* names[] = { "pitch", "yaw", "roll" };		
		for (uint32_t i = 0; i < (sizeof(names) / sizeof(names[0])); ++i) {
			lua_getfield(L, index, names[i]);
			if (lua_type(L, -1) != LUA_TNIL) {
				e[i] = lua_tonumber(L, -1);
			}
			lua_pop(L, 1);
		}
	}	
	lastack_pusheuler(LS, &e.x);
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
		} else if (strcmp(type, "mat") == 0 || strcmp(type, "m") == 0) {
			push_mat(L, LS, index);
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
		if (type != NULL)
			push_euler(L, LS, index);
		else {
			v[3] = 0;
			lastack_pushvec4(LS, v);
		}			
		break;
	}
	case 4:	{
		const char* type = get_type_field(L, index);
		if (type != NULL && (strcmp(type, "quat") == 0 || strcmp(type, "q") == 0))
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
	if (types[0] != types[1]) {
		if (!lastack_is_vec_type(types[0]) && !lastack_is_vec_type(types[1]))
			luaL_error(L, "pop2_values : type mismatch, type0 = %d, type1 = %d", types[0], types[1]);
	}		
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
	case LINEAR_TYPE_VEC4:
		ret[0] = val[0][0] + val[1][0];
		ret[1] = val[0][1] + val[1][1];
		ret[2] = val[0][2] + val[1][2];
		ret[3] = val[0][3];		
		lastack_pushvec4(LS, ret);
		break;
	case LINEAR_TYPE_EULER:
		if (types[1] != LINEAR_TYPE_EULER)
			luaL_error(L, "Invalid type for euler to add, only support euler + euler, type0 = %d, type1 = %d", types[0], types[1]);
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
	case LINEAR_TYPE_VEC4:
		ret[0] = val[0][0] - val[1][0];
		ret[1] = val[0][1] - val[1][1];
		ret[2] = val[0][2] - val[1][2];		
		ret[3] = 0.f; // must be 0, dir - point is no meaning
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
normalize_vector(lua_State *L, struct lastack *LS) {
	int t;
	float *v = pop_value(L, LS, &t);
	assert(t == LINEAR_TYPE_VEC4);

	glm::vec4 r;
	float invLen = 1.0f / glm::length(*((glm::vec3*)v));
	r[0] = v[0] * invLen;
	r[1] = v[1] * invLen;
	r[2] = v[2] * invLen;
	
	r[3] = v[3];
	lastack_pushvec4(LS, &r.x);
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
		glm::mat4x4 m = *((const glm::mat4x4*)val1) * *((const glm::mat4x4*)val0);
		lastack_pushmatrix(LS, &m[0][0]);
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_MAT): {
		glm::vec4 r = *((const glm::mat4x4*)val1) * *((const glm::vec4*)val0);
		lastack_pushvec4(LS, &r.x);
		break;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_NUM):
	case BINTYPE(LINEAR_TYPE_NUM, LINEAR_TYPE_VEC4): {
		const glm::vec4 *v4 = (const glm::vec4 *)(type == BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_NUM) ? val0 : val1);
		const float *vv = type == BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_NUM) ? val1 : val0;

		glm::vec4 r = *v4 * *vv;		
		lastack_pushvec4(LS, &r.x);
		break;
	}
	case BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_QUAT): {
		glm::quat r = *((const glm::quat *)val0) * *((const glm::quat*)val1);
		lastack_pushquat(LS, &r.x);
		break;
	}
	case BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_VEC4):
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_QUAT): {
		const glm::quat *q = (const glm::quat*)(BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_VEC4) ? val0 : val1);
		const glm::vec4 *v = (const glm::vec4 *)(BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_VEC4) ? val1 : val0);

		glm::vec4 r = glm::rotate(*q, *v);
		lastack_pushvec4(LS, &r.x);
		break;
	}
	case BINTYPE(LINEAR_TYPE_EULER, LINEAR_TYPE_VEC4):
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_EULER): {
		const glm::vec3 *e = (const glm::vec3*)(BINTYPE(LINEAR_TYPE_EULER, LINEAR_TYPE_VEC4) ? val0 : val1);
		const glm::vec4 *v = (const glm::vec4 *)(BINTYPE(LINEAR_TYPE_EULER, LINEAR_TYPE_VEC4) ? val1 : val0);

		glm::vec4 r = glm::rotate(glm::quat(*e), *v);
		lastack_pushvec4(LS, &r.x);
		break;
	}

	default:
		luaL_error(L, "Need support type %s * type %s", get_typename(t0),get_typename(t1));
	}
}

template<typename T>
inline bool
is_zero(const T &a) {
	return glm::all(glm::equal(a, glm::zero<T>(), glm::epsilon<T>()));
}

template<>
inline bool 
is_zero<float>(const float &a) {
	return glm::equal(a, glm::zero<float>(), glm::epsilon<float>());
}

static void mulH_2values(lua_State *L, struct lastack *LS){
	int64_t v1 = pop(L, LS);
	int64_t v0 = pop(L, LS);
	int t0, t1;
	const glm::mat4x4 * mat = (const glm::mat4x4 *)lastack_value(LS, v1, &t1);
	const glm::vec4 * v = (const glm::vec4 *)lastack_value(LS, v0, &t0);
	if (t0 != LINEAR_TYPE_VEC4 && t1 != LINEAR_TYPE_MAT)
		luaL_error(L, "'%' operator only support vec4 * mat, type0 is : %d, type1 is : %d", t0, t1);

	glm::vec4 r = *mat * *v;	
	if (!is_zero(r)){
		r /= fabs(r.w);
		r.w = 1.f;
	}

	lastack_pushvec4(LS, &r.x);
}

static void
transposed_matrix(lua_State *L, struct lastack *LS) {
	int t;
	const glm::mat4x4 *mat = (glm::mat4x4*)pop_value(L, LS, &t);
	if (t != LINEAR_TYPE_MAT)
		luaL_error(L, "transposed_matrix need mat4 type, type is : %d", t);
	glm::mat4x4 r = glm::transpose(*mat);
	lastack_pushmatrix(LS, &r[0][0]);
}

static void
inverted_value(lua_State *L, struct lastack *LS) {
	int t;
	float *value = pop_value(L, LS, &t);
	switch (t)
	{
	case LINEAR_TYPE_MAT: {
		const glm::mat4x4 *m = (const glm::mat4x4*)value;
		glm::mat4x4 r = glm::inverse(*m);		
		lastack_pushmatrix(LS, &r[0][0]);
		break;
	}

	case LINEAR_TYPE_VEC4: {
		glm::vec4 r(-value[0], -value[1], -value[2], value[3]);
		lastack_pushvec4(LS, &r.x);
		break;
	}
	default:
		luaL_error(L, "inverted_value only support mat/vec3/vec4, type is : %d", t);
	}		
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
	if (t0 != LINEAR_TYPE_VEC4 || t1 != LINEAR_TYPE_VEC4)
		luaL_error(L, "lookat_matrix, arg0/arg1 need vec4, arg0/arg is : %d/", t0, t1);	
	
	
	glm::mat4x4 m;
	if (direction) {
		const glm::vec3 *dir = (const glm::vec3*)at;
		const glm::vec3 *veye = (const glm::vec3*)eye;
		const glm::vec3 vat = *veye + *dir;
		m = glm::lookAtLH(*veye, vat, glm::vec3(0, 1, 0));
	} else {
		m = glm::lookAtLH(*(const glm::vec3*)eye, *(const glm::vec3*)at, glm::vec3(0, 1, 0));
	}
		
	lastack_pushmatrix(LS, &m[0][0]);
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
		float sinTheth_2 = std::sqrt(1 - r[3] * r[3]);
		if (is_zero(sinTheth_2))
			sinTheth_2 = 0.00001f;

		glm::vec4 v(glm::normalize(*(glm::vec3*)r / sinTheth_2), 0);
		
		v.w = glm::degrees(acosf(r[3]) * 2);
		lastack_pushvec4(LS, &v.x);
		break;
	}		
	default:
		luaL_error(L, "Unpack invalid type %s", get_typename(t));
	}
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
	SET(p, "quat",		"q",	LINEAR_TYPE_QUAT);
	SET(p, "num",		"n",	LINEAR_TYPE_NUM);	
	SET(p, "euler",		"e",	LINEAR_TYPE_EULER);
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
convert_to_euler(lua_State *L, struct lastack*LS) {
	int64_t id = pop(L, LS);
	int type;
	float *value = lastack_value(LS, id, &type);
	glm::vec3 e;
	switch (type) {
		case LINEAR_TYPE_VEC4:{
			glm::vec3 v = glm::normalize(*(glm::vec3*)value);
			glm::quat q(glm::vec3(0, 0, 1), v);
			e = glm::eulerAngles(q);
			break;
		}
		case LINEAR_TYPE_MAT:{
			const glm::mat4x4 *m = (const glm::mat4x4*)value;			
			e = glm::eulerAngles(glm::quat(*m));
			break;
		}
		case LINEAR_TYPE_QUAT:{
			e = glm::eulerAngles(*(glm::quat *)value);			
			break;
		}
		default:
			luaL_error(L, "not support for converting to euler, type is : %d", type);
			break;
	}
	e = glm::degrees(e);
	lastack_pusheuler(LS, &e.x);
}

static inline void
convert_to_quaternion(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float *value = lastack_value(LS, id, &type);
	glm::quat q;

	switch (type){
		case LINEAR_TYPE_MAT: 		
			q = glm::quat_cast(*(const glm::mat4x4 *)value);
			break;		
		case LINEAR_TYPE_VEC4:
		case LINEAR_TYPE_EULER:	
			q = glm::quat(glm::radians(*(const glm::vec3*)value));
			break;
		default:
			luaL_error(L, "not support for converting to quaternion, type is : %d", type);
			break;
	}

	lastack_pushquat(LS, &q.x);
}

glm::vec3
to_viewdir(const glm::vec3 &e){
	return is_zero(e) ?
		glm::vec3(0, 0, 1) :
		glm::rotate(glm::quat(e), glm::vec3(0, 0, 1));		
}

static inline void
convert_rotation_to_viewdir(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float *v = lastack_value(LS, id, &type);
	switch (type){
		case LINEAR_TYPE_EULER:
		case LINEAR_TYPE_VEC4:{
			glm::vec4 v4(to_viewdir(glm::radians(*(const glm::vec3*)v)), 0);
			lastack_pushvec4(LS, &v4.x);
			break;
		}
		default:
		luaL_error(L, "convect rotation to dir need euler/vec3/vec4 type, type given is : %d", type);
		break;
	}
}

static inline void
convert_viewdir_to_rotation(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float *v = lastack_value(LS, id, &type);
	switch (type){		
		case LINEAR_TYPE_VEC4: {						
			glm::quat q(glm::vec3(0, 0, 1), *(const glm::vec3*)v);
			glm::vec4 e(glm::degrees(glm::eulerAngles(q)), 0);
			lastack_pushvec4(LS, &e.x);
			break;
		}
	default:
		luaL_error(L, "view dir to rotation only accept vec3/vec4/euler, type given : %d", type);
		break;
	}
}

static inline void
matrix_decompose(const glm::mat4x4 &m, glm::vec4 &scale, glm::vec4 &rot, glm::vec4 &trans) {
	trans = m[3];

	for (int ii = 0; ii < 3; ++ii)
		scale[ii] = glm::length(m[ii]);

	if (scale.x == 0 || scale.y == 0 || scale.z == 0) {
		rot.x = 0;
		rot.y = 0;
		rot.z = 0;
		return;
	}

	glm::mat3x3 rotMat(m);
	for (int ii = 0; ii < 3; ++ii) {
		rotMat[ii] /= scale[ii];		
	}


	rot = glm::vec4(glm::degrees(glm::eulerAngles(glm::quat_cast(rotMat))), 0);
}

static inline void
split_mat_to_srt(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float* v = lastack_value(LS, id, &type);
	if (type != LINEAR_TYPE_MAT)
		luaL_error(L, "split operation '~' is only valid for mat4 type, type is : %d", type);
	
	const glm::mat4x4 *mat = (const glm::mat4x4 *)v;
	glm::vec4 scale(1, 1, 1, 0), rotation(0, 0, 0, 0), translate(0, 0, 0, 0);
	matrix_decompose(*mat, scale, rotation, translate);
	
	lastack_pushvec4(LS, &translate.x);
	lastack_pushvec4(LS, &rotation.x);
	lastack_pushvec4(LS, &scale.x);	
}


static inline void
rotation_to_base_axis(lua_State *L, struct lastack *LS){
	int64_t id = pop(L, LS);
	int type;
	float* v = lastack_value(LS, id, &type);
	if (!lastack_is_vec_type(type))
		luaL_error(L, "convert to base axis, only support vec3/vec4");
	
	glm::vec4 zdir(to_viewdir(glm::radians(*(glm::vec3*)v)), 0);
	
	glm::vec4 xdir, ydir;
	if (is_zero(zdir - glm::vec4(0, 0, 1, 0))){
		ydir = glm::vec4(0, 1, 0, 0);
		xdir = glm::vec4(1, 0, 0, 0);
	} else {
		xdir = glm::vec4(glm::cross(glm::vec3(0, 1, 0), *((glm::vec3*)&zdir.x)), 0);
		ydir = glm::vec4(glm::cross(*(glm::vec3*)(&zdir.x), *((glm::vec3*)&xdir.x)), 0);
	}

	lastack_pushvec4(LS, &zdir.x);
	lastack_pushvec4(LS, &ydir.x);
	lastack_pushvec4(LS, &xdir.x);
}

static const char * s_command_desc[256];

static void 
init_command_desc() {
	s_command_desc['P'] = "pop as id";
	s_command_desc['m'] = "pop as pointer";
	s_command_desc['T'] = "pop as table";
	s_command_desc['V'] = "top as string";
	s_command_desc['='] = "assign to ref";
	s_command_desc['1'] = "dup 1";
	s_command_desc['2'] = "dup 2";
	s_command_desc['3'] = "dup 3";
	s_command_desc['4'] = "dup 4";
	s_command_desc['5'] = "dup 5";
	s_command_desc['6'] = "dup 6";
	s_command_desc['7'] = "dup 7";
	s_command_desc['8'] = "dup 8";
	s_command_desc['9'] = "dup 9";
	s_command_desc['S'] = "swap";
	s_command_desc['R'] = "remove";
	s_command_desc['.'] = "dot";
	s_command_desc['x'] = "cross";
	s_command_desc['*'] = "mul";
	s_command_desc['%'] = "mulH";
	s_command_desc['n'] = "normalize";
	s_command_desc['t'] = "transposed";
	s_command_desc['i'] = "inverted";
	s_command_desc['-'] = "sub";
	s_command_desc['+'] = "add";
	s_command_desc['l'] = "look at";
	s_command_desc['L'] = "look from";
	s_command_desc['>'] = "extract";
	s_command_desc['e'] = "to euler";
	s_command_desc['q'] = "to quaternion";
	s_command_desc['d'] = "to rotation";
	s_command_desc['D'] = "to direction";
	s_command_desc['~'] = "to srt";
	s_command_desc['b'] = "split matrix as x, y, z axis";
	s_command_desc['@'] = "pop everything";
	int i;
	for (i=0;i<256;i++) {
		if (s_command_desc[i] == NULL) {
			s_command_desc[i] = "undefined";
		}
	}
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

	case 'T': {
		struct lua_State *L = RS->L;

		int64_t id = pop(L, LS);
		push_obj_to_lua_table(L, LS, id);
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
		struct refobject * ref = (struct refobject *)lua_touserdata(L, index);
		assign_ref(L, ref, id);
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
		if (t0 != LINEAR_TYPE_VEC4 || t0 != t1)
			luaL_error(L, "dot operation with type mismatch");
		
		lastack_pushnumber(LS, glm::dot(*((const glm::vec3*)vec1), *((const glm::vec3*)vec2)));
		refstack_2_1(RS);
		break;
	}
	case 'x': {		
		int t1,t2;
		float * vec2 = pop_value(L, LS, &t1);
		float * vec1 = pop_value(L, LS, &t2);
		if (t1 != LINEAR_TYPE_VEC4 || t1 != t2) {
			luaL_error(L, "need vec4 type and cross type mismatch");
		}

		glm::vec4 r(glm::cross(*((const glm::vec3*)vec1), *((const glm::vec3*)vec2)), 0);		
		lastack_pushvec4(LS, &r.x);
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
		normalize_vector(L, LS);
		refstack_1_1(RS);
		break;
	case 't':
		transposed_matrix(L, LS);
		refstack_1_1(RS);
		break;
	case 'i':
		inverted_value(L, LS);
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
		convert_to_euler(L, LS);
		refstack_1_1(RS);
		break;
	case 'q':
		convert_to_quaternion(L, LS);
		refstack_1_1(RS);
		break;		
	case 'd':
		convert_rotation_to_viewdir(L, LS);
		refstack_1_1(RS);
		break;
	case 'D':
		convert_viewdir_to_rotation(L, LS);
		refstack_1_1(RS);
		break;
	case '~':
		split_mat_to_srt(L, LS);
		refstack_pop(RS);
		refstack_push(RS);
		refstack_push(RS);
		refstack_push(RS);
		break;
	case 'b':
		rotation_to_base_axis(L, LS);
		refstack_pop(RS);
		refstack_push(RS);
		refstack_push(RS);
		refstack_push(RS);
		break;
	case '@': {
		lua_Integer n = 0;
		lua_newtable(L);
		for (;;) {
			int64_t v = lastack_pop(LS);
			if (v == 0) {
				break;
			}
			int index = refstack_topid(RS);
			if (index < 0) {
				pushid(L, v);
			}
			else {
				lua_pushvalue(L, index);
			}
			lua_rawseti(L, -2, ++n);
			refstack_pop(RS);
		}
		return 1;
	}
	default:
		luaL_error(L, "Unknown command %c", cmd);
	}
	return 0;
}

static int
push_command(struct ref_stack *RS, struct lastack *LS, int index, bool *log) {
	lua_State *L = RS->L;
	int type = lua_type(L, index);
	int pushlog = -1;
	if (*log) {
		pushlog = lastack_gettop(LS);
	}
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
		pushlog = -1;
		luaL_checkstack(L, (int)(sz + 20), NULL);
		int i;
		int ret = 0;
		for (i=0;i<(int)sz;i++) {
			int c = cmd[i];
			switch(c) {
			case '#':
				*log = true;
				break;
			default:
				if (*log) {
					printf("MATHLOG [%c %s]: ", c, s_command_desc[c]);
					lastack_dump(LS, 0);
					ret += do_command(RS, LS, c);
					printf(" -> ");
					lastack_dump(LS, 0);
					printf("\n");
				} else {
					ret += do_command(RS, LS, c);
				}
				break;
			}
		}
		return ret;
	}
	default:
		return luaL_error(L, "Invalid command type %s at %d", lua_typename(L, type), index);
	}
	if (pushlog >= 0) {
		printf("MATHLOG [push]: ");
		lastack_dump(LS, pushlog);
		printf("\n");
	}
	return 0;
}

static int
commandLS(lua_State *L) {
	struct boxpointer *bp = (struct boxpointer *)lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	bool log = false;
	int top = lua_gettop(L);
	int i;
	int ret = 0;
	struct ref_stack RS;
	refstack_init(&RS, L);
	for (i=1;i<=top;i++) {
		ret += push_command(&RS, LS, i, &log);
	}
	return ret;
}

static int
lnew(lua_State *L) {	
	struct boxpointer *bp = (struct boxpointer *)lua_newuserdata(L, sizeof(*bp));	

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
lcommand_description(lua_State *L){
	lua_newtable(L);
	for (size_t c = 0; c < 256; ++c) {
		const char* desc = s_command_desc[c];
		if (desc && strcmp(desc, "undefined") != 0) {
			lua_pushstring(L, desc);
			char name[2] = { (char)(unsigned char)c, 0 };
			lua_setfield(L, -2, name);
		}
	}

	return 1;
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
		struct refobject * ref = (struct refobject *)lua_touserdata(L, 1);
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

extern "C" {
	LUAMOD_API int
	luaopen_math3d(lua_State *L) {
		init_command_desc();
		luaL_checkversion(L);
		luaL_Reg ref[] = {
			{ "__tostring", lreftostring },
			{ "__call", lassign },
			{ "__bnot", lpointer },
			{ "__index", lref_get},
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
			{ "isvalid", lisvalid},
			{ "cmd_description", lcommand_description},
			{ "homogeneous_depth", lhomogeneous_depth},
			{ NULL, NULL },
		};
		luaL_newlib(L, l);
		return 1;
	}
}