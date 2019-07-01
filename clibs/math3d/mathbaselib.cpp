#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include "linalg.h"
	#include "math3d.h"
}

#include "util.h"

#include "meshbase/meshbase.h"

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/vector_relational.hpp>

#include <vector>
#include <array>
#include <cstring>
#include <unordered_map>
#include <string>

extern bool default_homogeneous_depth();
extern glm::vec3 to_viewdir(const glm::vec3 &e);

template<class ValueType>
static inline void
push_vec(lua_State *L, int num, ValueType &v) {
	lua_createtable(L, num, 0);
	for (int ii = 0; ii < num; ++ii) {
		lua_pushnumber(L, v[ii]);
		lua_seti(L, -2, ii + 1);
	}
};

template<class ValueType>
static inline void
fetch_vec(lua_State *L, int index, int num, ValueType &value) {
	for (int ii = 0; ii < num; ++ii) {
		lua_geti(L, index, ii + 1);
		value[ii] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}

template<class ValueType>
static inline void
fetch_vec(lua_State *L, int index, const char* name, int num, ValueType &value) {
	lua_getfield(L, index, name);
	fetch_vec(L, -1, num, value);
	lua_pop(L, 1);
};

struct Frustum {
	float l, r, t, b, n, f;
	bool ortho;
};

static inline void
pull_frustum(lua_State *L, int index, Frustum &f) {
	if (LUA_TNIL != lua_getfield(L, index, "ortho"))
		f.ortho = lua_toboolean(L, -1);
	else
		f.ortho = false;
	lua_pop(L, 1);

	lua_getfield(L, index, "n");
	f.n = luaL_optnumber(L, -1, 0.1f);
	lua_pop(L, 1);
	lua_getfield(L, index, "f");
	f.f = luaL_optnumber(L, -1, 100.0f);
	lua_pop(L, 1);

	if (lua_getfield(L, index, "fov") == LUA_TNUMBER) {
		float fov = lua_tonumber(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, index, "aspect");
		float aspect = luaL_checknumber(L, -1);
		lua_pop(L, 1);
		float ymax = f.n * tanf(fov * (M_PI / 360));
		float xmax = ymax * aspect;
		f.l = -xmax;
		f.r = xmax;
		f.b = -ymax;
		f.t = ymax;

	} else {
		lua_pop(L, 1);
		float* fv = &f.l;

		const char* elemnames[] = {
			"l", "r", "t", "b",
		};

		for (auto name : elemnames) {
			lua_getfield(L, index, name);
			*fv++ = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
	}
}

static inline glm::mat4x4
projection_mat(const Frustum &f) {
	if (f.ortho) {
		auto orthLH = default_homogeneous_depth() ? glm::orthoLH_NO<float> : glm::orthoLH_ZO<float>;
		return orthLH(f.l, f.r, f.b, f.t, f.n, f.f);
	}

	auto frustumLH = default_homogeneous_depth() ? glm::frustumLH_NO<float> : glm::frustumLH_ZO<float>;
	return frustumLH(f.l, f.r, f.b, f.t, f.n, f.f);
}

static inline void
pull_aabb(lua_State *L, int index, AABB &aabb) {
	fetch_vec(L, index, "min", 3, aabb.min);
	fetch_vec(L, index, "max", 3, aabb.max);
}

static inline void
pull_sphere(lua_State *L, int index, BoundingSphere &sphere) {
	fetch_vec(L, index, "center", 3, sphere.center);	
	lua_getfield(L, 3, "radius");
	sphere.radius = lua_tonumber(L, -1);
	lua_pop(L, 1);
}

static inline void
pull_obb(lua_State *L, int index, OBB &obb) {
	for (int ii = 0; ii < 4; ++ii)
		fetch_vec(L, index, 4, obb.m[ii]);
}

static inline void
push_aabb(lua_State *L, const AABB &aabb) {
	lua_createtable(L, 0, 2);
	{
		push_vec(L, 3, aabb.min);
		lua_setfield(L, -2, "min");

		push_vec(L, 3, aabb.max);
		lua_setfield(L, -2, "max");
	}
}

static inline void
push_sphere(lua_State *L, const BoundingSphere &sphere) {
	lua_createtable(L, 0, 2);
	{
		push_vec(L, 3, sphere.center);
		lua_setfield(L, -2, "center");

		lua_pushnumber(L, sphere.radius);
		lua_setfield(L, -2, "radius");
	}
}

static inline void
push_obb(lua_State *L, const OBB &obb) {
	lua_createtable(L, 16, 0);
	{
		for (int ii = 0; ii < 4; ++ii) {
			for (int jj = 0; jj < 4; ++jj) {
				lua_pushnumber(L, obb.m[ii][jj]);
				lua_seti(L, -2, ii * 4 + jj + 1);
			}
		}
	}
}

enum PlaneName : uint8_t {
	left = 0, right,
	top, bottom,
	near, far,
};

struct FrustumConer {
	PlaneName pnames[3];	
};

static inline std::string get_coner_name(const FrustumConer &c) {
	std::string name;
	const char* planenames[] = {
		"l", "r", "t", "b", "n", "f"
	};

	for (auto pn : c.pnames) {
		name += planenames[pn];
	}

	return name;
}

static inline void
frustum_planes_intersection_points(std::array<glm::vec4, 6> &planes, std::unordered_map<std::string, glm::vec3> &points) {
	auto calc_intersection_point = [](auto p0, auto p1, auto p2) {
		auto crossp0p1 = (glm::cross(glm::vec3(p0), glm::vec3(p1)));
		auto t = p0.w * (glm::cross(glm::vec3(p1), glm::vec3(p2))) +
			p1.w * (glm::cross(glm::vec3(p2), glm::vec3(p0))) +
			p2.w * crossp0p1;

		return t / glm::dot(crossp0p1, glm::vec3(p2));
	};

	FrustumConer coners[8] = {
		{PlaneName::left, PlaneName::top, PlaneName::near},
		{PlaneName::right, PlaneName::top, PlaneName::near},

		{PlaneName::left, PlaneName::top, PlaneName::far},
		{PlaneName::right, PlaneName::top, PlaneName::far},

		{PlaneName::left, PlaneName::bottom, PlaneName::near},
		{PlaneName::right, PlaneName::bottom, PlaneName::near},

		{PlaneName::left, PlaneName::bottom, PlaneName::far},
		{PlaneName::right, PlaneName::bottom, PlaneName::far},
	};

	for (const auto &c : coners) {		
		const auto& name = get_coner_name(c);
		points[name] = calc_intersection_point(planes[c.pnames[0]], planes[c.pnames[1]], planes[c.pnames[2]]);
	}
}


static inline void 
extract_planes(std::array<glm::vec4, 6> &planes, const glm::mat4x4 &m, bool normalize) {
	const auto &c0 = m[0], &c1 = m[1], &c2 = m[2], &c3 = m[3];

	auto &leftplane = planes[PlaneName::left];
	leftplane[0] = c0[0] + c0[3];
	leftplane[1] = c1[0] + c1[3];
	leftplane[2] = c2[0] + c2[3];
	leftplane[3] = c3[0] + c3[3];

	auto &rightplane = planes[PlaneName::right];	
	rightplane[0] = c0[3] - c0[0];
	rightplane[1] = c1[3] - c1[0];
	rightplane[2] = c2[3] - c2[0];
	rightplane[3] = c3[3] - c3[0];

	auto &bottomplane = planes[PlaneName::bottom];
	bottomplane[0] = c0[3] + c0[1];
	bottomplane[1] = c1[3] + c1[1];
	bottomplane[2] = c2[3] + c2[1];
	bottomplane[3] = c3[3] + c3[1];

	auto &topplane = planes[PlaneName::top];
	topplane[0] = c0[3] - c0[1];
	topplane[1] = c1[3] - c1[1];
	topplane[2] = c2[3] - c2[1];
	topplane[3] = c3[3] - c3[1];

	auto &nearplane = planes[PlaneName::near];
	if (default_homogeneous_depth()) {		
		nearplane[0] = c0[3] + c0[2];
		nearplane[1] = c1[3] + c1[2];
		nearplane[2] = c2[3] + c2[2];
		nearplane[3] = c3[3] + c3[2];
	} else {
		nearplane[0] = c0[2];
		nearplane[1] = c1[2];
		nearplane[2] = c2[2];
		nearplane[3] = c3[2];
	}

	auto &farplane = planes[PlaneName::far];	
	farplane[0] = c0[3] - c0[2];
	farplane[1] = c1[3] - c1[2];
	farplane[2] = c2[3] - c2[2];
	farplane[3] = c3[3] - c3[2];

	if (normalize){
		for (auto &p : planes) {
			auto len = glm::length(glm::vec3(p));
			if (glm::abs(len) >= glm::epsilon<float>())
				p /= len;
		}
	}
}

static inline void
calc_extreme_value(float v, float min, float max, float &tmin, float &tmax) {
	if (v > 0.f) {
		tmin += v * min;
		tmax += v * max;
	} else {
		tmin += v * max;
		tmax += v * min;
	}
}


static int
plane_intersect(const glm::vec4 &plane, const AABB &aabb) {
	float minD = 0, maxD = 0;
	for (int ii = 0; ii < 3; ++ii) {
		calc_extreme_value(plane[ii], aabb.min[ii], aabb.max[ii], minD, maxD);
	}
	
	if (minD >= plane.w)
		return 1;

	if (maxD <= plane.w)
		return -1;

	return 0;
}

static int
plane_intersect(const glm::vec4 &plane, const BoundingSphere &sphere) {
	assert(false && "not implement");
	return 0;
}

static inline void
pull_table_to_mat(lua_State *L, int index, glm::mat4x4 &matProj) {
	for (int ii = 0; ii < 16; ++ii) {
		lua_geti(L, 1, ii + 1);
		matProj[ii / 4][ii % 4] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}


static inline void 
pull_frustum_planes(lua_State *L, std::array<glm::vec4, 6> &planes, int index) {	
	const int type = lua_type(L, index);

	glm::mat4x4 matProj;
	if (type == LUA_TTABLE) {
		const size_t tlen = lua_rawlen(L, 1);

		if (tlen == 24) {
			for (int iPlane = 0; iPlane < 6; ++iPlane) {				
				for (int ii = 0; ii < 4; ++ii) {
					lua_geti(L, 1, iPlane * 4 + ii + 1);
					planes[iPlane][ii] = lua_tonumber(L, -1);
					lua_pop(L, 1);
				}
			}
			return;
		}

		if (tlen == 0) {
			Frustum f;
			pull_frustum(L, 1, f);

			matProj = projection_mat(f);
		} else if (tlen == 16) {
			pull_table_to_mat(L, 1, matProj);
		}
	} else if (type == LUA_TUSERDATA || type == LUA_TLIGHTUSERDATA) {
		matProj = *(reinterpret_cast<const glm::mat4x4*>(lua_touserdata(L, 1)));
	}

	extract_planes(planes, matProj, true);
}

static int
lextract_planes(lua_State *L) {
	std::array<glm::vec4, 6> planes;
	pull_frustum_planes(L, planes, 1);

	lua_createtable(L, 4 * 6, 0);
	for (int iPlane = 0; iPlane < 6; ++iPlane){
		for (int ii = 0; ii < 4; ++ii) {
			lua_pushnumber(L, planes[iPlane][ii]);
			lua_seti(L, -2, iPlane * 4 + ii + 1);
		}		
	}

	return 1;
}

template<class BoundingType>
static inline const char*
planes_intersect(const std::array<glm::vec4, 6> &planes, const BoundingType &aabb) {
	for (const auto &p : planes) {
		const int r = plane_intersect(p, aabb);
		if (r < 0)
			return "outside";

		if (r == 0)
			return "intersect";
	}

	return "inside";
}

static int
lintersect(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	std::array<glm::vec4, 6> planes;
	pull_frustum_planes(L, planes, 1);

	const char* intersectresult = nullptr;

	const char*boundingtype = luaL_checkstring(L, 2);
	if (strcmp(boundingtype, "aabb") == 0) {
		AABB aabb;
		pull_aabb(L, 3, aabb);

		intersectresult = planes_intersect(planes, aabb);
	} else if (strcmp(boundingtype, "sphere") == 0){
		BoundingSphere sphere;
		pull_sphere(L, 3, sphere);
		intersectresult = planes_intersect(planes, sphere);
	} else {
		luaL_error(L, "not support bounding type:%s", boundingtype);
	}

	lua_pushstring(L, intersectresult);
	return 1;
}

static inline void
transform_aabb(const glm::mat4x4 &trans, AABB &aabb) {
	const glm::vec3 pos = trans[3];
	AABB result(pos, pos);

	for (int icol = 0; icol < 3; ++icol)
		for (int irow = 0; irow < 3; ++irow) {
			calc_extreme_value(trans[icol][irow], aabb.min[irow], aabb.max[irow], result.min[irow], result.max[irow]);
		}
	aabb = result;
}

static int
lfrustum_points(lua_State *L) {
	std::array<glm::vec4, 6> planes;
	pull_frustum_planes(L, planes, 1);

	std::unordered_map<std::string, glm::vec3> points;
	frustum_planes_intersection_points(planes, points);

	lua_createtable(L, 0, 8);	
	for (const auto &p : points) {
		lua_createtable(L, 3, 0);
		const auto &point = p.second;
		for (int ii = 0; ii < 3; ++ii) {
			lua_pushnumber(L, point[ii]);
			lua_seti(L, -2, ii+1);
		}
		lua_setfield(L, -2, p.first.c_str());
	}
	return 1;
}

static inline struct lastack*
fetch_LS(lua_State* L, int index) {
	lua_getuservalue(L, index);
	struct boxstack* BS = (struct boxstack*)luaL_checkudata(L, -1, LINALG);
	return BS->LS;
}

static int
push_bounding(lua_State *L, const Bounding &bounding, int BS_index) {
	auto b = (Bounding*)lua_newuserdata(L, sizeof(Bounding));
	memcpy(b, &bounding, sizeof(Bounding));

	if (luaL_getmetatable(L, "BOUNDING_MT")){
		lua_setmetatable(L, -2);
	} else {
		luaL_error(L, "no meta table BOUNDING_MT");
	}

	luaL_checkudata(L, BS_index, LINALG);
	lua_pushvalue(L, BS_index);
	lua_setuservalue(L, -2);

	return 1;
}

static inline Bounding*
fetch_bounding(lua_State *L, int index){
	return (Bounding*)luaL_checkudata(L, index, "BOUNDING_MT");
}

static int
lbounding_transform(lua_State* L) {
	Bounding* b = fetch_bounding(L, 1);
	auto LS = fetch_LS(L, 1);

	int type;
	const glm::mat4x4* trans = (const glm::mat4x4*)lastack_value(LS, get_stack_id(L, LS, 2), &type);

	transform_aabb(*trans, b->aabb);
	b->sphere.Init(b->aabb);
	b->obb.Init(b->aabb);
	
	return 0;
}


static int
lbounding_merge(lua_State *L) {
	const int numboundings = lua_gettop(L);
	if (numboundings < 2){
		luaL_error(L, "invalid argument, at least 3 argument:(ms, bounding1, bounding2)");
	}
;
	Bounding *bounding = fetch_bounding(L, 1);

	for (int ii = 1; ii < numboundings; ++ii) {
		bounding->Merge(*fetch_bounding(L, ii+1));
	}

	return 0;
}

static int
lbounding_append_point(lua_State* L) {	
	Bounding* b = fetch_bounding(L, 1);
	auto LS = fetch_LS(L, 1);

	auto pt = get_vec_value(L, LS, 2);

	b->aabb.Append(*tov3(pt));
	b->sphere.Init(b->aabb);
	b->obb.Init(b->aabb);

	return 0;
}

static int
lbounding_new(lua_State* L) {
	const int numarg = lua_gettop(L);
	struct lastack* LS = getLS(L, 1);

	Bounding bounding;
	for (int ii = 1; ii < numarg; ++ii) {
		auto v = get_vec_value(L, LS, ii+1);
		bounding.aabb.Append(v);
	}

	bounding.sphere.Init(bounding.aabb);
	bounding.obb.Init(bounding.aabb);

	return push_bounding(L, bounding, 1);
}

static int
lbounding_string(lua_State *L){
	char buffers[512] = { 0 };
	const Bounding *b = fetch_bounding(L, 1);
	const auto& min = b->aabb.min;
	const auto& max = b->aabb.max;
	const auto& sphere = b->sphere;
	const auto& obb = b->obb;

	sprintf_s(buffers, "\
aabb:\n\
\tmin:(%2f, %2f, %2f), max:(%2f, %2f, %2f)\n\
sphere:\n\
\tcenter:(%2f, %2f, %2f), radius:%2f\n\
obb:\n\
\t(%2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f)",
		min.x, min.y, min.z, max.x, max.y, max.z,
		sphere.center.x, sphere.center.y, sphere.center.z, sphere.radius,
		obb.m[0][0], obb.m[0][1], obb.m[0][2], obb.m[0][3],
		obb.m[1][0], obb.m[1][1], obb.m[1][2], obb.m[1][3],
		obb.m[2][0], obb.m[2][1], obb.m[2][2], obb.m[2][3],
		obb.m[3][0], obb.m[3][1], obb.m[3][2], obb.m[3][3]);

	lua_pushstring(L, buffers);
	return 1;
}

static void
register_bounding_mt(lua_State *L){
	if (luaL_newmetatable(L, "BOUNDING_MT")){
		luaL_Reg l[] = {			
			{ "transform",	lbounding_transform},
			{ "merge",		lbounding_merge},
			{ "append",		lbounding_append_point},
			{ "__tostring", lbounding_string},

			{nullptr, nullptr}
		};

		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
}

static void
register_frustum_mt(lua_State *L){

}


extern "C"{
	LUAMOD_API int
	luaopen_math3d_baselib(lua_State *L){
		register_bounding_mt(L);
		register_frustum_mt(L);

		luaL_Reg l[] = {			
			{ "intersect",		lintersect },
			{ "extract_planes", lextract_planes},			
			{ "frustum_points", lfrustum_points},

			{ "new_bounding",	lbounding_new},
			{ NULL, NULL },
		};

		luaL_newlib(L, l);

		return 1;
	}
}