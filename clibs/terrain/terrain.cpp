#define LUA_LIB

//#include "meshbase/meshbase.h"
#include "glm/glm.hpp"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <limits>
#include <algorithm>
#include <vector>
#include <cstring>

struct heightfield_data{
	uint32_t w, h;
	const float *data;
	float scale;
};
static inline float
get_heightfield_data(const heightfield_data &hfdata, float percentW, float percentH, uint32_t x, uint32_t z){
	const uint32_t sampleX = uint32_t(x * percentW), sampleZ = uint32_t(z * percentH);

	assert((sampleZ * hfdata.w + sampleX) < (hfdata.w * hfdata.h));
	return hfdata.data[sampleZ * hfdata.w + sampleX] * hfdata.scale;
}

static int 
lterrain_min_max_height(lua_State *L){
	const uint32_t grid_width = (uint32_t)lua_tointeger(L, 1);
	const uint32_t grid_height = (uint32_t)lua_tointeger(L, 2);

	const uint32_t vw = grid_width + 1;
	const uint32_t vertex_height = grid_height + 1;

	glm::vec3 *positions = (glm::vec3*)lua_touserdata(L, 3);

	float minH = std::numeric_limits<float>::lowest(), 
			maxH = std::numeric_limits<float>::max();

	for (uint32_t iz = 0; iz < vertex_height; ++iz){
		for (uint32_t ix = 0; ix < vw; ++ix){
			const auto& p = positions[iz * vw + ix];
			minH = std::min(minH, p.y);
			maxH = std::max(maxH, p.y);
		}
	}

	lua_pushnumber(L, minH);
	lua_pushnumber(L, maxH);
	return 2;
}

static int
lterrain_update_vertex_buffers(lua_State *L){
	//const auto hf = fetch_heightfield(L, 1);
	//auto positions = (glm::vec3*)lua_touserdata(L, 2);
	//auto normals = (glm::vec3*)lua_touserdata(L, 3);

	
	return 0;
}

struct render_data{
	glm::uvec3 *indices;
	glm::vec3 *positions;
	glm::vec3 *normals;
};

static const char* RD_MT = "TERRAIN_RENDERDATA";


static inline render_data*
get_rd(lua_State *L, int idx=1){
	return (render_data*)luaL_checkudata(L, idx, RD_MT);
}

static int
lrenderdata_delete(lua_State *L){
	auto rd = get_rd(L);
	auto del_array_func = [](auto &p) {
		if (p){
			delete[] p;
			p = nullptr;
		}
	};
	del_array_func(rd->indices);
	del_array_func(rd->positions);
	del_array_func(rd->normals);

	return 0;
}

static int
lrenderdata_init_index_buffer(lua_State *L){
	auto rd = get_rd(L, 1);
	const uint32_t w = (uint32_t)luaL_checkinteger(L, 2);
	const uint32_t h = (uint32_t)luaL_checkinteger(L, 3);
	const uint32_t pitchw = (uint32_t)luaL_checkinteger(L, 4);

	const uint32_t triangle_num = w * h * 2;
	rd->indices = new glm::uvec3[triangle_num];
	uint32_t itriangle = 0;
	for (uint32_t iz = 0; iz < h; ++iz){
		for (uint32_t ix = 0; ix < w; ++ix){
			// quad indices
			const uint32_t idx0 = (iz * pitchw) + ix;
			const uint32_t idx1 = (iz+1) * pitchw + ix;
			const uint32_t idx2 = (iz * pitchw) + (ix + 1);

			const uint32_t idx3 = (iz+1) * pitchw + (ix + 1);
			rd->indices[itriangle++] = glm::uvec3(idx0, idx1, idx2);
			rd->indices[itriangle++] = glm::uvec3(idx3, idx2, idx1);
		}
	}
	lua_pushlightuserdata(L, rd->indices);
	return 1;
}

static int
lrenderdata_init_vertex_buffer(lua_State *L){
	auto rd = get_rd(L, 1);
	const uint32_t grid_width = (uint32_t)luaL_checkinteger(L, 2);
	const uint32_t grid_height = (uint32_t)luaL_checkinteger(L, 3);

	heightfield_data hfdata = {0};
	if (!lua_isnoneornil(L, 4)){
		lua_geti(L, 4, 1);
		hfdata.w = (uint32_t)lua_tointeger(L, -1);
		lua_geti(L, 4, 2);
		hfdata.h = (uint32_t)lua_tointeger(L, -1);
		lua_geti(L, 4, 3);
		hfdata.data = (const float*)lua_touserdata(L, -1);
		lua_geti(L, 4, 4);
		hfdata.scale = (float)lua_tonumber(L, -1);
		lua_pop(L, 4);
	}

	const float grid_unit = (float)luaL_optnumber(L, 5, 1.f);

	const uint32_t vertex_width  = grid_width + 1;
	const uint32_t vertex_height = grid_height + 1;

	const float offsetX = (float)luaL_optnumber(L, 6, grid_width * -0.5f);
	const float offsetZ = (float)luaL_optnumber(L, 7, grid_height * -0.5f);

	const uint32_t vertex_num = vertex_width * vertex_height;
	rd->positions = new glm::vec3[vertex_num];
	rd->normals = new glm::vec3[vertex_num];

	const float hf_percentW = hfdata.data ? hfdata.w / float(vertex_width) : 1.f, 
				hf_percentH = hfdata.data ? hfdata.h / float(vertex_height) : 1.f;

	for (uint32_t iz = 0; iz < vertex_height; ++iz){
		for (uint32_t ix = 0; ix < vertex_width; ++ix){
			auto ip = iz * vertex_width + ix;
			const float x = (float(ix) + offsetX) * grid_unit;
			const float y = hfdata.data ? get_heightfield_data(hfdata, hf_percentW, hf_percentH, ix, iz) * grid_unit : 0.f;
			const float z = (float(iz) + offsetZ) * grid_unit;

			auto p = glm::vec3(x, y, z);
			rd->positions[ip] = p;
		}
	}
	
	auto calc_normal = [rd](uint32_t idx0, uint32_t idx1, uint32_t idx2){
			const auto& p0 = rd->positions[idx0], 
						p1 = rd->positions[idx1], 
						p2 = rd->positions[idx2];

			const auto e0 = p1 - p0,
						e1 = p2 - p0;
			return glm::normalize(glm::cross(e0, e1));
	};

	for (uint32_t iz = 0; iz < grid_height; ++iz){
		for (uint32_t ix = 0; ix < grid_width; ++ix){
			// quad indices
			const uint32_t idx0 = (iz * vertex_width) + ix;
			const uint32_t idx1 = (iz+1) * vertex_width + ix;
			const uint32_t idx2 = (iz * vertex_width) + (ix + 1);
			
			rd->normals[idx0] = calc_normal(idx0, idx1, idx2);
		}
	}

	for (uint32_t ii = 0; ii < grid_height; ++ii){
		const uint32_t idx0 = (vertex_width * ii + grid_width),
						idx1 = (vertex_width * ii + grid_width - 1),
						idx2 = (vertex_width * ii + 1 + grid_width);

		rd->normals[idx0] = calc_normal(idx0, idx1, idx2);
	}

	for (uint32_t ii = 0; ii < grid_width; ++ii){
		const uint32_t idx0 = (grid_height * vertex_width + ii),
						idx1 = (grid_height * vertex_width + ii + 1),
						idx2 = ((grid_height - 1) * vertex_width + ii);

		rd->normals[idx0] = calc_normal(idx0, idx1, idx2);
	}

	{
		const uint32_t idx0 = grid_height * vertex_width + grid_width,
						idx1 = (grid_height - 1) * vertex_width + grid_width,
						idx2 = grid_height * vertex_width + grid_width - 1;
		rd->normals[idx0] = calc_normal(idx0, idx1, idx2);
	}

	lua_pushlightuserdata(L, rd->positions);
	lua_pushlightuserdata(L, rd->normals);
	return 2;
}

static int
lrenderdata_index_buffer(lua_State *L){
	auto rd = get_rd(L);
	lua_pushlightuserdata(L, rd->indices);
	return 1;
}

static int
lrenderdata_vertex_buffer(lua_State *L){
	auto rd = get_rd(L, 1);
	if (lua_isnoneornil(L, 2)){
		lua_pushlightuserdata(L, rd->positions);
		lua_pushlightuserdata(L, rd->normals);
		return 2;
	}

	const char* what = luaL_checkstring(L, 2);
	if (strcmp(what, "position") == 0){
		lua_pushlightuserdata(L, rd->positions);
	}else if (strcmp(what, "normal") == 0){
		lua_pushlightuserdata(L, rd->normals);
	}else {
		return luaL_error(L, "unknow vertex type:%s", what);
	}

	return 1;
}

static int
lterrain_create_renderdara(lua_State *L){
	auto rd = (render_data*)lua_newuserdatauv(L, sizeof(render_data), 0);
	memset(rd, 0, sizeof(render_data));
	if (luaL_newmetatable(L, RD_MT)){
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		luaL_Reg l[] = {
			{"init_index_buffer",	lrenderdata_init_index_buffer},
			{"init_vertex_buffer",	lrenderdata_init_vertex_buffer},
			{"init_buffer", 		lrenderdata_index_buffer},
			{"vertex_buffer",		lrenderdata_vertex_buffer},
			{"__gc",				lrenderdata_delete},
			{nullptr, nullptr},
		};
		luaL_setfuncs(L, l, 0);
	}

	lua_setmetatable(L, -2);
	return 1;
}

extern "C" {
LUAMOD_API int
	luaopen_terrain(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_render_data",		lterrain_create_renderdara},
		{ "calc_min_max_height",	lterrain_min_max_height},
		{ "update_vertex_buffers",	lterrain_update_vertex_buffers},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
}




