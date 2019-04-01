#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include "linalg.h"
	#include "math3d.h"
}

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/vector_relational.hpp>

#include <vector>
#include <array>
#include <cstring>

extern bool default_homogeneous_depth();
extern glm::vec3 to_viewdir(const glm::vec3 &e);

struct Frustum {
	float l, r, t, b, n, f;
	bool ortho;
};

static inline void
pull_frustum(lua_State *L, int index, Frustum &f) {
	lua_getfield(L, 2, "type");
	const char* type = lua_tostring(L, -1);
	lua_pop(L, 1);

	f.ortho = strcmp(type, "ortho") == 0;

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

static int 
lscreenpt_to_3d(lua_State *L){
	int numarg = lua_gettop(L);
	if (numarg < 5){
		luaL_error(L, "5 arguments needed!", numarg);
	}

	// get 2d point, point.z is the depth in ndc space
	luaL_checktype(L, 1, LUA_TTABLE);

	size_t len = lua_rawlen(L, 1);
	std::vector<glm::vec3>	vv(len / 3);
	float * v = &vv[0].x;	

	for (size_t ii = 0; ii < len; ++ii) {
		lua_geti(L, 1, ii+1);
		*v++ = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}

	// get camera frustum
	luaL_checktype(L, 2, LUA_TTABLE);

	Frustum f;
	pull_frustum(L, 2, f);
	glm::mat4x4 matProj = projection_mat(f);

	// get camera position & rotation
	glm::vec3 *position = (glm::vec3*)lua_touserdata(L, 3);
	glm::vec3 *viewDir = (glm::vec3*)lua_touserdata(L, 4);

	glm::mat4x4 matView = glm::lookAtLH(*position, *position + *viewDir, glm::vec3(0, 1, 0));
	
	// get viewport size
	lua_getfield(L, 5, "w");
	float width = lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 5, "h");
	float height = lua_tonumber(L, -1);
	lua_pop(L, 1);


	//////////////////////////////////////////////////////////////////////////
	glm::mat4x4 matInverseVP = glm::inverse(matProj * matView);
	
	
	for (auto& pt : vv) {		
		auto remap0_1 = [](float v) {
			return v * 2.f - 1.f;
		};
		pt.x = remap0_1(pt.x / width);
		pt.y = remap0_1((height - pt.y) / height);
		

		auto tmp = matInverseVP * glm::vec4(pt, 1);
		pt = tmp / tmp.w;		
	}
	
	const auto count = vv.size();
	lua_createtable(L, (int)count * 3, 0);
	for (int ii = 0; ii < (int)count; ++ii) {
		const auto &p = vv[ii];
		for (int jj = 0; jj < 3; ++jj) {
			lua_pushnumber(L, p[jj]);
			lua_seti(L, -2, ii * 3 + jj + 1);
		}		
	}

	return 1;
}

struct AABB {
	glm::vec3 min, max;
};


static inline void
pull_aabb(lua_State *L, int index, AABB &aabb) {
	auto fetch_vec3 = [L, index](auto name, auto value) {
		lua_getfield(L, index, name);

		for (int ii = 0; ii < 3; ++ii) {
			lua_geti(L, -1, ii + 1);
			*value++ = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);
	};

	fetch_vec3("min", &aabb.min.x);
	fetch_vec3("max", &aabb.max.x);
}

static inline void
frustum_planes_intersection_points(std::array<glm::vec4, 6> &planes, std::array<glm::vec3, 8> &points) {
	enum PlaneName{
		left = 0, right,
		top, bottom,
		near, far
	};
	enum FrustumPointName {
		ltn = 0, rtn, ltf, rtf,
		lbn, rbn, lbf, rbf,
	};

	auto calc_intersection_point = [](auto p0, auto p1, auto p2) {
		auto crossp0p1 = (glm::cross(glm::vec3(p0), glm::vec3(p1)));
		auto t = p0.w * (glm::cross(glm::vec3(p1), glm::vec3(p2))) +
			p1.w * (glm::cross(glm::vec3(p2), glm::vec3(p0))) +
			p2.w * crossp0p1;

		return t / glm::dot(crossp0p1, glm::vec3(p2));
	};

	uint8_t defines[8][3] = {
		{PlaneName::left, PlaneName::top, PlaneName::near},
		{PlaneName::right, PlaneName::top, PlaneName::near},

		{PlaneName::left, PlaneName::top, PlaneName::far},
		{PlaneName::right, PlaneName::top, PlaneName::far},

		{PlaneName::left, PlaneName::bottom, PlaneName::near},
		{PlaneName::right, PlaneName::bottom, PlaneName::near},

		{PlaneName::left, PlaneName::bottom, PlaneName::far},
		{PlaneName::right, PlaneName::bottom, PlaneName::far},
	};

	for (int ii = 0; ii < 8; ++ii) {
		int idx0 = defines[ii][0], idx1 = defines[ii][1], idx2 = defines[ii][2];
		points[ii] = calc_intersection_point(planes[idx0], planes[idx1], planes[idx2]);
	}
}

static inline void
push_aabb(lua_State *L, const AABB &aabb, int32_t index) {
	auto push_value = [L, index](auto name, auto value) {
		lua_getfield(L, index, name);
		for (int ii = 0; ii < 3; ++ii) {
			lua_pushnumber(L, *value++);
			lua_seti(L, -2, ii + 1);
		}
		lua_pop(L, 1);
	};
	push_value("min", &aabb.min.x);
	push_value("max", &aabb.max.x);
}

static inline void 
extract_planes(std::array<glm::vec4, 6> &planes, const glm::mat4x4 &projMat, bool normalize) {
	// Left clipping plane
	planes[0][0] = projMat[3][0] + projMat[0][0];
	planes[0][1] = projMat[3][1] + projMat[0][1];
	planes[0][2] = projMat[3][2] + projMat[0][2];
	planes[0][3] = projMat[3][3] + projMat[0][3];
	// Right clipping plane
	planes[1][0] = projMat[3][0] - projMat[0][0];
	planes[1][1] = projMat[3][1] - projMat[0][1];
	planes[1][2] = projMat[3][2] - projMat[0][2];
	planes[1][3] = projMat[3][3] - projMat[0][3];
	// Top clipping plane
	planes[2][0] = projMat[3][0] - projMat[1][0];
	planes[2][1] = projMat[3][1] - projMat[1][1];
	planes[2][2] = projMat[3][2] - projMat[1][2];
	planes[2][3] = projMat[3][3] - projMat[1][3];
	// Bottom clipping plane
	planes[3][0] = projMat[3][0] + projMat[1][0];
	planes[3][1] = projMat[3][1] + projMat[1][1];
	planes[3][2] = projMat[3][2] + projMat[1][2];
	planes[3][3] = projMat[3][3] + projMat[1][3];
	// Near clipping plane
	if (default_homogeneous_depth()) {		
		planes[4][0] = projMat[3][0] + projMat[2][0];
		planes[4][1] = projMat[3][1] + projMat[2][1];
		planes[4][2] = projMat[3][2] + projMat[2][2];
		planes[4][3] = projMat[3][3] + projMat[2][3];
	} else {
		planes[4][0] = projMat[0][2];
		planes[4][1] = projMat[1][2];
		planes[4][2] = projMat[2][2];
		planes[4][3] = projMat[3][2];
	}

	// Far clipping plane
	planes[5][0] = projMat[3][0] - projMat[2][0];
	planes[5][1] = projMat[3][1] - projMat[2][1];
	planes[5][2] = projMat[3][2] - projMat[2][2];
	planes[5][3] = projMat[3][3] - projMat[2][3];
	// Normalize the plane equations, if requested
	if (normalize){
		for (auto &p : planes) {
			auto len = glm::length(glm::vec3(p));
			if (glm::abs(len) >= glm::epsilon<float>())
				p /= len;
		}
			
		//NormalizePlane(p_planes[0]);
		//NormalizePlane(p_planes[1]);
		//NormalizePlane(p_planes[2]);
		//NormalizePlane(p_planes[3]);
		//NormalizePlane(p_planes[4]);
		//NormalizePlane(p_planes[5]);
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

		if (tlen == 0) {
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

static inline const char*
planes_intersect(const std::array<glm::vec4, 6> &planes, AABB &aabb) {	
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
lintersect_frustum_and_aabb(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	std::array<glm::vec4, 6> planes;
	pull_frustum_planes(L, planes, 1);

	luaL_checktype(L, 2, LUA_TTABLE);
	AABB aabb;
	pull_aabb(L, 2, aabb);

	const char* result = planes_intersect(planes, aabb);
	lua_pushstring(L, result);
	return 1;
}

static inline void
transform_aabb(const glm::mat4x4 &trans, AABB &aabb) {
	AABB result = { trans[3], trans[3] };

	for (int icol = 0; icol < 3; ++icol)
		for (int irow = 0; irow < 3; ++irow) {
			calc_extreme_value(trans[icol][irow], aabb.min[irow], aabb.max[irow], result.min[irow], result.max[irow]);
		}
	aabb = result;
}

static int
ltransform_aabb(lua_State *L) {
	int type = lua_type(L, 1);
	glm::mat4x4 trans;
	if (type == LUA_TTABLE) {
		size_t len = lua_rawlen(L, 1);
		if (len == 16)
			pull_table_to_mat(L, 1, trans);
		else
			luaL_error(L, "matrix need 16 element!");
	} else if (type == LUA_TUSERDATA || type == LUA_TLIGHTUSERDATA) {
		const void* v = lua_touserdata(L, 1);
		memcpy(&trans, v, sizeof(trans));
	} else {
		luaL_error(L, "not support format to get matrix");
	}

	luaL_checktype(L, 2, LUA_TTABLE);
	AABB aabb;
	pull_aabb(L, 2, aabb);

	transform_aabb(trans, aabb);

	push_aabb(L, aabb, 2);
	return 1;
}

static int
lfrustum_points(lua_State *L) {
	std::array<glm::vec4, 6> planes;
	pull_frustum_planes(L, planes, 1);

	std::array<glm::vec3, 8> points;
	frustum_planes_intersection_points(planes, points);

	lua_createtable(L, 3 * 8, 0);
	for (int ipoint = 0; ipoint < 8; ++ipoint)
		for (int ii = 0; ii < 3; ++ii) {
			lua_pushnumber(L, points[ipoint][ii]);
			lua_seti(L, -2, ipoint * 3 + ii+1);
		}
	return 1;
}

extern "C"{
	LUAMOD_API int
	luaopen_math3d_baselib(lua_State *L){
		luaL_Reg l[] = {
			{ "screenpt_to_3d", lscreenpt_to_3d },
			{ "intersect", lintersect_frustum_and_aabb },
			{ "extract_planes", lextract_planes},
			{ "transform_aabb", ltransform_aabb},
			{ "frustum_points", lfrustum_points},
			{ NULL, NULL },
		};

		luaL_newlib(L, l);

		return 1;
	}
}