#define LUA_LIB

#include "meshbase/meshbase.h"
#include "glm/glm.hpp"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <limits>
#include <algorithm>
#include <vector>

struct heightfield_data{
	uint32_t w, h;
	const float *data;
};
static inline float
get_heightfield_data(const heightfield_data &hfdata, float percentW, float percentH, uint32_t x, uint32_t z){
	if (hfdata.data == nullptr)
		return 0.f;

	const uint32_t sampleX = uint32_t(x * percentW), sampleZ = uint32_t(z * percentH);

	assert((sampleZ * hfdata.w + sampleX) < (hfdata.w * hfdata.h));
	return hfdata.data[sampleZ * hfdata.w + sampleX];
}

static int
lterrain_alloc(lua_State* L){
	const uint32_t grid_width = (uint32_t)lua_tointeger(L, 1);
	const uint32_t grid_height = (uint32_t)lua_tointeger(L, 2);

	const float grid_unit = lua_isnoneornil(L, 3) ? 1.f : (float)lua_tonumber(L, 3);

	Bounding *bounding = lua_isnoneornil(L, 4) ? nullptr : (Bounding*)luaL_checkudata(L, 4, "BOUNDING_MT");
	
	heightfield_data hfdata = {0};
	if (!lua_isnoneornil(L, 5)){
		lua_geti(L, 4, 1);
		hfdata.w = (uint32_t)lua_tointeger(L, -1);
		lua_geti(L, 4, 2);
		hfdata.h = (uint32_t)lua_tointeger(L, -1);
		lua_geti(L, 4, 3);
		hfdata.data = (const float*)lua_touserdata(L, 4);
		lua_pop(L, 3);
	}

	const uint32_t vertex_width = grid_width 	+ 1;
	const uint32_t vertex_height = grid_height 	+ 1;  

	const float offsetX = lua_isnoneornil(L, 6) ? grid_width * -0.5f : (float)lua_tonumber(L, 6);
	const float offsetZ = lua_isnoneornil(L, 7) ? grid_height * -0.5f : (float)lua_tonumber(L, 7);

	const uint32_t buffersize = vertex_width * vertex_height * sizeof(glm::vec3);
	auto positions = (glm::vec3*)lua_newuserdatauv(L, buffersize, 0);
	const uint32_t triangle_num = grid_width * grid_height * 2;
	auto indices = (glm::uvec3*)lua_newuserdatauv(L, triangle_num * sizeof(glm::uvec3), 0);
	auto normals = (glm::vec3*)lua_newuserdatauv(L, buffersize, 0);

	const float hf_percentW = hfdata.data ? hfdata.w / float(vertex_width) : 1.f, 
				hf_percentH = hfdata.data ? hfdata.h / float(vertex_height) : 1.f;

	for (uint32_t iz = 0; iz < vertex_height; ++iz){
		for (uint32_t ix = 0; ix < vertex_width; ++ix){
			auto ip = iz * vertex_width + ix;
			const float x = (float(ix) + offsetX) * grid_unit;
			const float y = get_heightfield_data(hfdata, hf_percentW, hf_percentH, ix, iz);
			const float z = (float(iz) + offsetZ) * grid_unit;

			auto p = glm::vec3(x, y, z);
			positions[ip] = p;

			if (bounding)
				bounding->aabb.Append(p);
		}
	}

	if (bounding){
		bounding->sphere.Init(bounding->aabb);
		bounding->obb.Init(bounding->aabb);
	}

	auto calc_normal = [positions](uint32_t idx0, uint32_t idx1, uint32_t idx2){
			const auto& p0 = positions[idx0], 
						p1 = positions[idx1], 
						p2 = positions[idx2];

			const auto e0 = p1 - p0,
						e1 = p2 - p0;
			return glm::normalize(glm::cross(e0, e1));
	};

	uint32_t itriangle = 0;
	for (uint32_t iz = 0; iz < grid_height; ++iz){
		for (uint32_t ix = 0; ix < grid_width; ++ix){
			// quad indices
			const uint32_t idx0 = (iz * vertex_width) + ix;
			const uint32_t idx1 = (iz+1) * vertex_width + ix;
			const uint32_t idx2 = (iz * vertex_width) + (ix + 1);
			
			normals[idx0] = calc_normal(idx0, idx1, idx2);

			const uint32_t idx3 = (iz+1) * vertex_width + (ix + 1);
			indices[itriangle++] = glm::uvec3(idx0, idx1, idx2);
			indices[itriangle++] = glm::uvec3(idx3, idx2, idx1);
		}
	}

	for (uint32_t ii = 0; ii < grid_height; ++ii){
		const uint32_t idx0 = (vertex_width * ii + grid_width),
						idx1 = (vertex_width * ii + grid_width - 1),
						idx2 = (vertex_width * ii + 1 + grid_width);

		normals[idx0] = calc_normal(idx0, idx1, idx2);
	}

	for (uint32_t ii = 0; ii < grid_width; ++ii){
		const uint32_t idx0 = (grid_height * vertex_width + ii),
						idx1 = (grid_height * vertex_width + ii + 1),
						idx2 = ((grid_height - 1) * vertex_width + ii);

		normals[idx0] = calc_normal(idx0, idx1, idx2);
	}

	{
		const uint32_t idx0 = grid_height * vertex_width + grid_width,
						idx1 = (grid_height - 1) * vertex_width + grid_width,
						idx2 = grid_height * vertex_width + grid_width - 1;
		normals[idx0] = calc_normal(idx0, idx1, idx2);
	}
	
	return 3;
}

static int 
lterrain_min_max_height(lua_State *L){
	const uint32_t grid_width = (uint32_t)lua_tointeger(L, 1);
	const uint32_t grid_height = (uint32_t)lua_tointeger(L, 2);

	const uint32_t vertex_width = grid_width + 1;
	const uint32_t vertex_height = grid_height + 1;

	glm::vec3 *positions = (glm::vec3*)lua_touserdata(L, 3);

	float minH = std::numeric_limits<float>::lowest(), 
			maxH = std::numeric_limits<float>::max();

	for (uint32_t iz = 0; iz < vertex_height; ++iz){
		for (uint32_t ix = 0; ix < vertex_width; ++ix){
			const auto& p = positions[iz * vertex_width + ix];
			minH = std::min(minH, p.y);
			maxH = std::max(maxH, p.y);
		}
	}

	lua_pushnumber(L, minH);
	lua_pushnumber(L, maxH);
	return 2;
}

static int
lterrain_aabb(lua_State *L){
	const auto positions = (glm::vec3*)lua_touserdata(L, 1);
	const auto num = (uint32_t)lua_tointeger(L, 2);
	auto bounding = (Bounding*)luaL_checkudata(L, 3, "BOUNDING_MT");

	bounding->Reset();

	for (uint32_t ii = 0; ii < num; ++ii){
		bounding->aabb.Append(positions[ii]);
	}

	bounding->sphere.Init(bounding->aabb);
	bounding->obb.Init(bounding->aabb);
	
	return 1;
}

extern "C" {
LUAMOD_API int
	luaopen_terrain(lua_State *L) {
	luaL_checkversion(L);
	
	luaL_Reg l[] = {
		{ "alloc",	lterrain_alloc},
		{ "calc_min_max_height", lterrain_min_max_height},
		{ "calc_aabb", lterrain_aabb},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
}




