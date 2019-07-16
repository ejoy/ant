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
#include <sstream>

extern bool default_homogeneous_depth();
extern glm::vec3 to_viewdir(const glm::vec3 &e);

static inline struct lastack*
fetch_LS(lua_State* L, int index) {
	lua_getuservalue(L, index);
	struct boxstack* BS = (struct boxstack*)luaL_checkudata(L, -1, LINALG);
	return BS->LS;
}

struct Frustum {
	using Points = std::unordered_map<std::string, glm::vec3>;
	using Planes = std::array<glm::vec4, 6>;

	glm::mat4x4 mat;
	Planes planes;

	enum PlaneName : uint8_t {
		left = 0, right,
		top, bottom,
		near, far,
	};

	struct Corner {
		PlaneName pnames[3];
	};


	Frustum(const glm::mat4x4& m)
		: mat(m) {
		extract_planes(planes, mat, false);
	}

	static inline void
		extract_planes(std::array<glm::vec4, 6> & planes, const glm::mat4x4& m, bool normalize) {
		const auto& c0 = m[0], & c1 = m[1], & c2 = m[2], & c3 = m[3];

		auto& leftplane = planes[PlaneName::left];
		leftplane[0] = c0[0] + c0[3];
		leftplane[1] = c1[0] + c1[3];
		leftplane[2] = c2[0] + c2[3];
		leftplane[3] = c3[0] + c3[3];

		auto& rightplane = planes[PlaneName::right];
		rightplane[0] = c0[3] - c0[0];
		rightplane[1] = c1[3] - c1[0];
		rightplane[2] = c2[3] - c2[0];
		rightplane[3] = c3[3] - c3[0];

		auto& bottomplane = planes[PlaneName::bottom];
		bottomplane[0] = c0[3] + c0[1];
		bottomplane[1] = c1[3] + c1[1];
		bottomplane[2] = c2[3] + c2[1];
		bottomplane[3] = c3[3] + c3[1];

		auto& topplane = planes[PlaneName::top];
		topplane[0] = c0[3] - c0[1];
		topplane[1] = c1[3] - c1[1];
		topplane[2] = c2[3] - c2[1];
		topplane[3] = c3[3] - c3[1];

		auto& nearplane = planes[PlaneName::near];
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

		auto& farplane = planes[PlaneName::far];
		farplane[0] = c0[3] - c0[2];
		farplane[1] = c1[3] - c1[2];
		farplane[2] = c2[3] - c2[2];
		farplane[3] = c3[3] - c3[2];

		if (normalize) {
			for (auto& p : planes) {
				auto len = glm::length(glm::vec3(p));
				if (glm::abs(len) >= glm::epsilon<float>())
					p /= len;
			}
		}
	}

	static inline std::string
		get_coner_name(const Frustum::Corner& c) {
		std::string name;
		const char* planenames[] = {
			"l", "r", "t", "b", "n", "f"
		};

		for (auto pn : c.pnames) {
			name += planenames[pn];
		}

		return name;
	}

	inline void
		frustum_planes_intersection_points(Points& points) {
		auto invmat = glm::inverse(this->mat);

		const std::tuple<const char*, glm::vec4> pp[] = {
			{"lbn", glm::vec4(-1.f,-1.f,-1.f, 1.f)},
			{"ltn", glm::vec4(-1.f,1.f, -1.f, 1.f)},
			{"rbn", glm::vec4(1.f, -1.f,-1.f, 1.f)},
			{"rtn", glm::vec4(1.f, 1.f, -1.f, 1.f)},

			{"lbf", glm::vec4(-1.f,-1.f, 1.f, 1.f)},
			{"ltf", glm::vec4(-1.f,1.f,  1.f, 1.f)},
			{"rbf", glm::vec4(1.f, -1.f, 1.f, 1.f)},
			{"rtf", glm::vec4(1.f, 1.f,  1.f, 1.f)},
		};

		for (const auto p : pp){
			auto t = invmat * std::get<1>(p);
			t /= t.w;			
			points[std::get<0>(p)] = t;
		}
	}
};

static inline Frustum*
fetch_frustum(lua_State* L, int index) {
	return (Frustum*)luaL_checkudata(L, index, "FRUSTUM_MT");
}

static inline Bounding*
fetch_bounding(lua_State* L, int index) {
	return (Bounding*)luaL_checkudata(L, index, "BOUNDING_MT");
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

static void
get_aabb_points(const AABB& aabb, Frustum::Points& points) {
	points["ltn"] = glm::vec4(aabb.min.x, aabb.max.y, aabb.min.z, 1.f);
	points["lbn"] = glm::vec4(aabb.min, 1.f);
	points["rtn"] = glm::vec4(aabb.max.x, aabb.max.y, aabb.min.z, 1.f);
	points["rbn"] = glm::vec4(aabb.max.x, aabb.min.y, aabb.min.z, 1.f);

	points["ltf"] = glm::vec4(aabb.min.x, aabb.max.y, aabb.max.z, 1.f);
	points["rtf"] = glm::vec4(aabb.max, 1.f);

	points["lbf"] = glm::vec4(aabb.min.x, aabb.min.y, aabb.max.z, 1.f);
	points["rbf"] = glm::vec4(aabb.max.x, aabb.min.y, aabb.max.z, 1.f);
}


//static float
//which_plane_side(const glm::vec4& plane, const glm::vec4& p) {
//	const glm::vec3* n = tov3(plane);
//	return glm::dot(*n, *tov3(p)) + plane.w;
//}
//
//static int
//plane_intersect1(const glm::vec4& plane, const AABB& aabb) {
//	Frustum::Points points;
//	get_aabb_points(aabb, points);
//
//	int result = 0;
//	for (const auto &pt : points){
//		const float r = which_plane_side(plane, glm::vec4(pt.second, 1.f));
//		if (r < 0){
//			--result;
//		} else if (r > 0){
//			++result;
//		}
//	}
//	if (result == 8)
//		return 1;
//
//	if (result == -8)
//		return -1;
//
//	return 0;
//}

static int
plane_intersect(const glm::vec4 &plane, const AABB &aabb) {
	const glm::vec3& min = aabb.min;
	const glm::vec3& max = aabb.max;
	float minD, maxD;	
	if (plane.x > 0.0f){
		minD = plane.x * min.x;
		maxD = plane.x * max.x;
	} else {
		minD = plane.x * max.x;
		maxD = plane.x * min.x;
	}

	if (plane.y > 0.0f){
		minD += plane.y * min.y;
		maxD += plane.y * max.y;
	} else {
		minD += plane.y * max.y;
		maxD += plane.y * min.y;
	}

	if (plane.z > 0.0f){
		minD += plane.z * min.z;
		maxD += plane.z * max.z;
	} else {
		minD += plane.z * max.z;
		maxD += plane.z * min.z;
	}

	// in front of the plane
	if (minD > -plane.w){
		return 1;
	}

	// in back of the plane
	if (maxD < -plane.w){
		return -1;
	}

	// straddle of the plane
	return 0;
}

static int
plane_intersect(const glm::vec4 &plane, const BoundingSphere &sphere) {
	
	return 0;
}

template<class BoundingType>
static inline const char*
planes_intersect(const Frustum::Planes &planes, const BoundingType &bt) {
	for (const auto &p : planes) {
		const int r = plane_intersect(p, bt);
		if (r < 0)
			return "outside";

		if (r == 0)
			return "intersect";
	}

	return "inside";
}

static inline void
transform_aabb(const glm::mat4x4 &trans, AABB &aabb) {
	const glm::vec3 pos = trans[3];

	glm::vec3 right = trans[0];
	glm::vec3 up = trans[1];
	glm::vec3 forward = trans[2];

	glm::vec3 xa = right * aabb.min.x;
	glm::vec3 xb = right * aabb.max.x;

	glm::vec3 ya = up * aabb.min.y;
	glm::vec3 yb = up * aabb.max.y;

	glm::vec3 za = forward * aabb.min.z;
	glm::vec3 zb = forward * aabb.max.z;

	aabb = AABB(glm::min(xa, xb) + glm::min(ya, yb) + glm::min(za, zb) + pos,
			glm::max(xa, xb) + glm::max(ya, yb) + glm::max(za, zb) + pos);
}

static int
push_box_points(lua_State *L, const Frustum::Points &points){
	lua_createtable(L, 0, 8);
	for (const auto& p : points) {
		lua_createtable(L, 3, 0);
		const auto& point = p.second;
		for (int ii = 0; ii < 3; ++ii) {
			lua_pushnumber(L, point[ii]);
			lua_seti(L, -2, ii + 1);
		}
		lua_setfield(L, -2, p.first.c_str());
	}
	return 1;
}

static int
lfrustum_points(lua_State *L) {
	auto f = fetch_frustum(L, 1);
	
	Frustum::Points points;
	f->frustum_planes_intersection_points(points);

	return push_box_points(L, points);
}

static int
lfrustum_intersect(lua_State* L) {
	auto *f = fetch_frustum(L, 1);
	auto* bounding = fetch_bounding(L, 2);

	auto result = planes_intersect(f->planes, bounding->aabb);
	
	lua_pushstring(L, result);
	return 1;
}

static int
lfrustum_intersect_list(lua_State* L) {
	auto* f = fetch_frustum(L, 1);

	luaL_checktype(L, 2, LUA_TTABLE);

	if (lua_isnoneornil(L, 3)){
		luaL_error(L, "need 3 argument");
	}

	const int len = lua_tointeger(L, 3);
	lua_createtable(L, len, 0);
	for (int ii = 0; ii < len ; ++ii){
		lua_geti(L, 2, ii + 1);
		const Bounding* b = LUA_TUSERDATA == lua_type(L, -1) ? fetch_bounding(L, -1) : nullptr;		
		lua_pop(L, 1);

		if (b){
			auto result = planes_intersect(f->planes, b->aabb);
			lua_pushboolean(L, 0 != strcmp(result, "outside"));
		} else {
			lua_pushboolean(L, true);
		}
		lua_seti(L, -2, ii + 1);
	}

	return 1;
}

static int
lfrustum_string(lua_State* L) {
	auto f = fetch_frustum(L, 1);
	char buffer[512] = { 0 };

	const char* planenames[] = { "left", "right", "top", "bottom", "near", "far" };

	sprintf(buffer,
"mat:\n\
\t(%2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f,\n\
\t %2f, %2f, %2f, %2f)\n\
planes:\n\
\t%s: (%2f, %2f, %2f, %2f)\n\
\t%s: (%2f, %2f, %2f, %2f)\n\
\t%s: (%2f, %2f, %2f, %2f)\n\
\t%s: (%2f, %2f, %2f, %2f)\n\
\t%s: (%2f, %2f, %2f, %2f)\n\
\t%s: (%2f, %2f, %2f, %2f)\n",
f->mat[0][0], f->mat[0][1], f->mat[0][2], f->mat[0][3],
f->mat[1][0], f->mat[1][1], f->mat[1][2], f->mat[1][3],
f->mat[2][0], f->mat[2][1], f->mat[2][2], f->mat[2][3],
f->mat[3][0], f->mat[3][1], f->mat[3][2], f->mat[3][3],
planenames[Frustum::PlaneName::left], f->planes[0][0], f->planes[0][1], f->planes[0][2], f->planes[0][3],
planenames[Frustum::PlaneName::right], f->planes[1][0], f->planes[1][1], f->planes[1][2], f->planes[1][3],
planenames[Frustum::PlaneName::top], f->planes[2][0], f->planes[2][1], f->planes[2][2], f->planes[2][3],
planenames[Frustum::PlaneName::bottom], f->planes[3][0], f->planes[3][1], f->planes[3][2], f->planes[3][3],
planenames[Frustum::PlaneName::near], f->planes[4][0], f->planes[4][1], f->planes[4][2], f->planes[4][3],
planenames[Frustum::PlaneName::far], f->planes[5][0], f->planes[5][1], f->planes[5][2], f->planes[5][3]);

	lua_pushstring(L, buffer);
	return 1;
}

static inline int
push_frustum(lua_State* L, const Frustum& f, int BS_index) {
	auto* pf = (Frustum*)lua_newuserdata(L, sizeof(Frustum));
	*pf = f;

	if (luaL_getmetatable(L, "FRUSTUM_MT")) {
		lua_setmetatable(L, -2);
	} else {
		luaL_error(L, "no meta table BOUNDING_MT");
	}

	luaL_checkudata(L, BS_index, LINALG);
	lua_pushvalue(L, BS_index);
	lua_setuservalue(L, -2);

	return 1;
}

static int
lfrustum_new(lua_State* L) {
	auto LS = getLS(L, 1);

	int type;
	const glm::mat4x4* trans = (const glm::mat4x4*)lastack_value(LS, get_stack_id(L, LS, 2), &type);
	return push_frustum(L, Frustum(*trans), 1);
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
lbounding_merge_list(lua_State *L){
	Bounding* scenebounding = fetch_bounding(L, 1);
	auto LS = fetch_LS(L, 1);

	const uint32_t len = (uint32_t)lua_rawlen(L, 2);

	const bool has_trans = !lua_isnoneornil(L, 3);
	if (has_trans){
		const uint32_t len2 = (uint32_t)lua_rawlen(L, 3);
		if (len != len2) {
			luaL_error(L, "boundings numbers should equal to transform's list number:%d, %d", len, len2);
		}
	}

	AABB sceneaabb;
	for (uint32_t ii = 0; ii < len; ++ii){
		lua_geti(L, 2, ii + 1);
		const Bounding *b = fetch_bounding(L, -1);
		lua_pop(L, 1);

		if (has_trans){
			lua_geti(L, 3, ii + 1);
			int type;
			auto trans = (glm::mat4x4*)lastack_value(LS, get_stack_id(L, LS, -1), &type);			
			lua_pop(L, 1);

			AABB aabb = b->aabb;
			transform_aabb(*trans, aabb);
			sceneaabb.Merge(aabb);
		} else {
			sceneaabb.Merge(b->aabb);
		}
	}

	scenebounding->aabb.Merge(sceneaabb);
	scenebounding->sphere.Init(scenebounding->aabb);
	scenebounding->obb.Init(scenebounding->aabb);

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
		auto v = get_vec_value(L, LS, ii + 1);
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

	sprintf(buffers, "\
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

static int
lbounding_isvalid(lua_State *L){
	auto bounding = fetch_bounding(L, 1);
	lua_pushboolean(L, bounding->IsValid());
	return 1;
}

static int
lbounding_reset(lua_State *L){
	auto bounding = fetch_bounding(L, 1);
	bounding->Reset();

	return 0;
}

static int
lbounding_get(lua_State *L){
	auto bounding = fetch_bounding(L, 1);

	const std::string name = lua_tostring(L, 2);
	lua_createtable(L, 0, 0);
	if (name == "aabb"){
		lua_createtable(L, 3, 0);
		for (int ii = 0; ii < 3; ++ii){
			lua_pushnumber(L, bounding->aabb.min[ii]);
			lua_seti(L, -2, ii + 1);
		}
		lua_setfield(L, -2, "min");

		lua_createtable(L, 3, 0);
		for (int ii = 0; ii < 3; ++ii) {
			lua_pushnumber(L, bounding->aabb.max[ii]);
			lua_seti(L, -2, ii + 1);
		}
		lua_setfield(L, -2, "max");
	} else if (name == "sphere"){
		for (int ii = 0; ii < 3; ++ii){
			lua_pushnumber(L, bounding->sphere.center[ii]);
			lua_seti(L, -2, ii + 1);
		}

		lua_pushnumber(L, bounding->sphere.radius);
		lua_seti(L, -2, 4);
	} else if (name == "obb"){
		for (int ii = 0; ii < 4; ++ii)
			for(int jj = 0; jj < 4; ++jj){
				lua_pushnumber(L, bounding->obb.m[ii][jj]);
				lua_seti(L, -2, jj + 1 + ii * 4);
			}
	}

	return 1;
}

static int
lbounding_aabb_points(lua_State *L){
	auto b = fetch_bounding(L, 1);
	Frustum::Points points;
	get_aabb_points(b->aabb, points);
	return push_box_points(L, points);
}

static void
register_bounding_mt(lua_State* L) {
	if (luaL_newmetatable(L, "BOUNDING_MT")) {
		luaL_Reg l[] = {
			{ "transform",	lbounding_transform},
			{ "merge",		lbounding_merge},
			{ "merge_list", lbounding_merge_list},
			{ "append",		lbounding_append_point},
			{ "isvalid",	lbounding_isvalid},
			{ "reset",		lbounding_reset},
			{ "get",		lbounding_get},
			{ "aabb_points",lbounding_aabb_points},
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
	if (luaL_newmetatable(L, "FRUSTUM_MT")) {
		luaL_Reg l[] = {
			{ "intersect",	lfrustum_intersect},
			{ "intersect_list", lfrustum_intersect_list},
			{ "points", lfrustum_points},
			{ "__tostring", lfrustum_string},

			{nullptr, nullptr}
		};

		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
}

static int
lplane_intersect(lua_State *L){
	auto LS = getLS(L, 1);
	const glm::vec4 plane = get_vec_value(L, LS, 2);	
	auto b = fetch_bounding(L, 3);
	lua_pushinteger(L, plane_intersect(plane, b->aabb));
	return 1;
}

extern "C"{
	LUAMOD_API int
	luaopen_math3d_baselib(lua_State *L){
		register_bounding_mt(L);
		register_frustum_mt(L);

		luaL_Reg l[] = {			
			{ "new_bounding",	lbounding_new},
			{ "new_frustum",	lfrustum_new},
			{ "plane_interset",	lplane_intersect},
			{ NULL, NULL },
		};

		luaL_newlib(L, l);

		return 1;
	}
}