#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
}

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include <vector>
#include <cstring>

extern bool default_homogeneous_depth();
extern glm::vec3 to_viewdir(const glm::vec3 &e);

struct Frustum {
	float l, r, t, b, n, f;
};

static inline void
pull_frustum(lua_State *L, int index, Frustum &f) {
	float* fv = &f.l;

	const char* elemnames[] = {
		"l", "r", "t", "b", "n", "f",
	};

	for (auto name : elemnames) {
		lua_getfield(L, index, name);
		*fv++ = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
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
	lua_getfield(L, 2, "type");
	const char* type = lua_tostring(L, -1);
	Frustum f;
	pull_frustum(L, 2, f);
	
	glm::mat4x4 matProj;
	if (strcmp(type, "proj") == 0) {
		auto frustumLH = default_homogeneous_depth() ? glm::frustumLH_NO<float> : glm::frustumLH_ZO<float>;
		matProj = frustumLH(f.l, f.r, f.b, f.t, f.n, f.f);
	} else if (strcmp(type, "ortho") == 0) {
		auto orthLH = default_homogeneous_depth() ? glm::orthoLH_NO<float> : glm::orthoLH_ZO<float>;
		matProj = orthLH(f.l, f.r, f.b, f.t, f.n, f.f);
	}

	// get camera position & rotation
	glm::vec3 position, euler;
	luaL_checktype(L, 3, LUA_TTABLE);

	for (int ii = 0; ii < 3; ++ii) {
		lua_geti(L, 3, ii + 1);
		position[ii] = lua_tointeger(L, -1);
		lua_pop(L, 1);

		lua_geti(L, 4, ii + 1);
		euler[ii] = lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

	glm::vec3 viewDir = to_viewdir(glm::radians(euler));
	glm::mat4x4 matView = glm::lookAtLH(position, position + viewDir, glm::vec3(0, 1, 0));
	
	// get viewport size
	lua_getfield(L, 5, "w");
	float width = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 5, "h");
	float height = lua_tointeger(L, -1);
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
	
	const float * cv = &vv[0].x;
	lua_createtable(L, 6, 0);
	for (int ii = 0; ii < 6; ++ii) {
		lua_pushnumber(L, *cv++);
		lua_seti(L, -2, ii + 1);
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

static int
lcull_by_frustum(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	Frustum f;
	pull_frustum(L, 1, f);

	luaL_checktype(L, 2, LUA_TTABLE);
	AABB aabb;
	pull_aabb(L, 2, aabb);




	return 1;
}

extern "C"{

	LUAMOD_API int
	luaopen_math3d_baselib(lua_State *L){
		luaL_Reg l[] = {
			{ "screenpt_to_3d", lscreenpt_to_3d },
			{ NULL, NULL },
		};

		luaL_newlib(L, l);

		return 1;
	}
}