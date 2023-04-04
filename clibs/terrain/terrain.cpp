#define LUA_LIB

//#include "meshbase/meshbase.h"
#include <glm/glm.hpp>

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
lterrain_create_section_aabb(lua_State *L){
	const glm::vec3 *position = (const glm::vec3*)lua_touserdata(L, 1);
	const uint32_t vertex_offset = (uint32_t)luaL_checkinteger(L, 2);
	const uint32_t elemsize = (uint32_t)luaL_checkinteger(L, 3);
	const uint32_t vertexsize = elemsize+1;
	const uint32_t pitchw = (uint32_t)luaL_checkinteger(L, 4);

	glm::vec3 minv(
		std::numeric_limits<float>::max(),
		std::numeric_limits<float>::max(),
		std::numeric_limits<float>::max()
	);
	glm::vec3 maxv(
		std::numeric_limits<float>::lowest(),
		std::numeric_limits<float>::lowest(),
		std::numeric_limits<float>::lowest()
	);
	for (uint32_t ih=0; ih<vertexsize; ++ih){
		const uint32_t offset = ih * pitchw + vertex_offset;
		for (uint32_t iw=0; iw<vertexsize; ++iw){
			const glm::vec3 &v = position[offset + iw];
			minv = glm::min(minv, v);
			maxv = glm::max(maxv, v);
		}
	}

	auto push_v3 = [L](const auto& v){
		lua_createtable(L, 3, 0);
		for(uint32_t ii=0; ii<3;++ii){
			lua_pushnumber(L, v[ii]);
			lua_seti(L, -2, ii+1);
		}
	};
	
	push_v3(minv);
	push_v3(maxv);
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
	glm::vec2 *texcoord0;
	glm::vec2 *texcoord1;

#ifdef _DEBUG
	uint32_t grid_width, grid_height;
	uint32_t indices_grid_width, indices_grid_height;
#endif//_DEBUG
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
	del_array_func(rd->texcoord0);
	del_array_func(rd->texcoord1);

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
#ifdef _DEBUG
	rd->indices_grid_width = w;
	rd->indices_grid_height = h;
#endif //_DEBUG
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
	rd->texcoord0 = new glm::vec2[vertex_num];
	rd->texcoord1 = nullptr;	//TODO
#ifdef _DEBUG
	rd->grid_width = grid_width;
	rd->grid_width = grid_height;
#endif //_DEBUG

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
			rd->texcoord0[ip] = glm::vec2(float(ix), float(iz));
		}
	}
	memset(rd->normals, 0, vertex_num * sizeof(glm::vec3));
	
	auto calc_normal = [rd](glm::vec3 *normals, uint32_t idx0, uint32_t idx1, uint32_t idx2){
			const auto& p0 = rd->positions[idx0], 
						p1 = rd->positions[idx1], 
						p2 = rd->positions[idx2];

			const auto e0 = p1 - p0,
						e1 = p2 - p0;
			const auto n = glm::normalize(glm::cross(e0, e1));
			normals[idx0] += n;
			normals[idx1] += n;
			normals[idx2] += n;
	};

	for (uint32_t iz = 0; iz < grid_height; ++iz){
		for (uint32_t ix = 0; ix < grid_width; ++ix){
			// quad indices
			const uint32_t idx0 = (iz * vertex_width) + ix;
			const uint32_t idx1 = (iz+1) * vertex_width + ix;
			const uint32_t idx2 = (iz * vertex_width) + (ix + 1);
			
			calc_normal(rd->normals, idx0, idx1, idx2);
		}
	}

	for (uint32_t ii = 0; ii < grid_height; ++ii){
		const uint32_t idx0 = (vertex_width * ii + grid_width),
						idx1 = (vertex_width * ii + grid_width - 1),
						idx2 = (vertex_width * ii + 1 + grid_width);

		calc_normal(rd->normals, idx0, idx1, idx2);
	}

	for (uint32_t ii = 0; ii < grid_width; ++ii){
		const uint32_t idx0 = (grid_height * vertex_width + ii),
						idx1 = (grid_height * vertex_width + ii + 1),
						idx2 = ((grid_height - 1) * vertex_width + ii);

		calc_normal(rd->normals, idx0, idx1, idx2);
	}

	{
		const uint32_t idx0 = grid_height * vertex_width + grid_width,
						idx1 = (grid_height - 1) * vertex_width + grid_width,
						idx2 = grid_height * vertex_width + grid_width - 1;
		calc_normal(rd->normals, idx0, idx1, idx2);
	}

	for (uint32_t jj=0; jj<vertex_height; ++jj){
		const uint32_t offset = jj * vertex_width;
		for(uint32_t ii=0; ii<vertex_width; ++ii){
			const uint32_t idx = offset + ii;
			glm::normalize(rd->normals[idx]);
		}
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

#ifdef _DEBUG
static int
lrenderdata_totable(lua_State *L){
	auto rd = get_rd(L, 1);
	auto t = luaL_checkstring(L, 2);
	if (strcmp(t, "position") == 0){
		const uint32_t  w = (rd->grid_width+1),
						h = (rd->grid_height+1);
		lua_createtable(L, w * h, 0);
		for(uint32_t jj=0; jj<h; ++jj){
			const uint32_t offset = jj*w;
			for(uint32_t ii=0; ii<w; ++ii){
				const uint32_t idx = ii+offset;
				const auto & v = rd->positions[idx];
				for (uint32_t ip=0; ip<3; ++ip){
					lua_pushnumber(L, v[ip]);
					lua_seti(L, -2, idx+ip+1);
				}
			}
		}
		return 1;
	}
	if (strcmp(t, "indices") == 0){
		const uint32_t triangle_num = rd->indices_grid_width * rd->indices_grid_height * 2;
		lua_createtable(L, triangle_num * 3, 0);
		for (uint32_t it=0; it<triangle_num; ++it){
			const auto &v = rd->indices[it];
			for (uint32_t ii=0; ii<3; ++ii){
				lua_pushinteger(L, v[ii]);
				lua_seti(L, -2, it+ii+1);
			}
		}
		return 1;
	}
	if (strcmp(t, "section") == 0){
		const uint32_t sectionidx = (uint32_t)luaL_checkinteger(L, 3)-1;
		const uint32_t sectionwidth = rd->grid_width / rd->indices_grid_width;
		const uint32_t pitchw = rd->grid_width+1;
		const uint32_t vertexsize = rd->indices_grid_width+1;
		const uint32_t vertex_offset = (sectionidx / sectionwidth) * pitchw * vertexsize + 
			(sectionidx % sectionwidth) * vertexsize;

		lua_createtable(L, vertexsize*vertexsize * 3, 0);
		for (uint32_t jj=0; jj<vertexsize; ++jj){
			const uint32_t offset = jj*pitchw + vertex_offset;
			const uint32_t voffset = jj*vertexsize;

			for (uint32_t ii=0; ii<vertexsize; ++ii){
				const uint32_t idx = offset + ii;
				const auto &v = rd->positions[idx];
				lua_createtable(L, 3, 0);
				for (uint32_t ip=0; ip<3; ++ip){
					lua_pushnumber(L, v[ip]);
					lua_seti(L, -2, ip+1);
				}
				lua_seti(L, -2, voffset+ii+1);
			}
		}
		return 1;
	}
	
	return luaL_error(L, "unknow type:%s", t);
}
#endif //_DEBUG
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
			#ifdef _DEBUG
			{"totable",				lrenderdata_totable},
			#endif //_DEBUG
			{"__gc",				lrenderdata_delete},
			{nullptr, nullptr},
		};
		luaL_setfuncs(L, l, 0);
	}

	lua_setmetatable(L, -2);
	return 1;
}

/* static const unsigned char hash[] = {
	208,34,231,213,32,248,233,56,161,78,24,140,71,48,140,254,245,255,
	247,247,40, 185,248,251,245,28,124,204,204,76,36,1,107,28,234,163,
	202,224,245,128,167,204,9,92,217,54,239,174,173,102,193,189,190,121,
	100,108,167,44,43,77,180,204,8,81,70,223,11,38,24,254,210,210,177,
	32,81,195,243,125,8,169,112,32,97,53,195,13,203,9,47,104,125,117,
	114,124,165,203,181,235,193,206,70,180,174,0,167,181,41,164,30,116,
	127,198,245,146,87,224,149,206,57,4,192,210,65,210,129,240,178,105,
	228,108,245,148,140,40,35,195,38,58,65,207,215,253,65,85,208,76,62,
	3,237,55,89,232,50,217,64,244,157,199,121,252,90,17,212,203,149,152,
	140,187,234,177,73,174,193,100,192,143,97,53,145,135,19,103,13,90,
	135,151,199,91,239,247,33,39,145,101,120,99,3,186,86,99,41,237,203,
	111,79,220,135,158,42,30,154,120,67,87,167,135,176,183,191,253,115,
	184,21,233,58,129,233,142,39,128,211,118,137,139,255,114,20,218,113,
	154,27,127,246,250,1,8,198,250,209,92,222,173,21,88,102,219
}; */

static const unsigned char hash[] = {
	151,160,137,91,90,15,
  131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
  190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
  88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,139,48,27,166,
  77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
  102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,
  135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,
  5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
  223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
  129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,
  251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,
  49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
  138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
};

static int noise2(int x, int y, int seed) {
	int yindex = (y + seed) % 256;
	if (yindex < 0) {
		yindex += 256;
	}
	int  xindex = (hash[yindex] + x) % 256;
	if (xindex < 0) {
		xindex += 256;
	}
	return (int) hash[xindex];
}

static double lin_inter(double x, double y, double s) {
	return x + s * (y-x);
}

static double smooth_inter(double x, double y, double s) {
	return lin_inter(x, y, s * s * (3-2*s));
}

static double noise2d(double x, double y, double seed) {
	int x_int = floor(x);
	int y_int = floor(y);
	double x_frac = x - x_int;
	double y_frac = y - y_int;
	int s = noise2(x_int, y_int, seed);
	int t = noise2(x_int+1, y_int, seed);
	int u = noise2(x_int, y_int+1, seed);
	int v = noise2(x_int+1, y_int+1, seed);
	double low = smooth_inter(s, t, x_frac);
	double high = smooth_inter(u, v, x_frac);
	return smooth_inter(low, high, y_frac);
}

static double perlin2d(double x, double y, double freq, int depth, int seed, float ox, float oy) {
	double xa = x*freq + ox;
	double ya = y*freq + oy;
	double amp = 1.0;
	double fin = 0;
	double div = 0.0;

	int i;
	for(i=0; i<depth; i++) {
		div += 256 * amp;
		fin += noise2d(xa, ya, seed) * amp;
		amp /= 2;
		xa *= 2;
		ya *= 2;
	}

	return fin/div;
}

static int lnoise(lua_State *L) {
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
	float freq = luaL_checknumber(L, 3);
	int depth = luaL_checkinteger(L, 4);
	int seed = luaL_checkinteger(L, 5);
	float offsetx = luaL_checknumber(L, 6);
	float offsety = luaL_checknumber(L, 7);
	lua_pushnumber(L, perlin2d(x, y, freq, depth, seed, offsetx, offsety));

	return 1;
}

extern "C" {
LUAMOD_API int
	luaopen_terrain(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "noise", lnoise },
		{ "create_render_data",		lterrain_create_renderdara},
		{ "calc_min_max_height",	lterrain_min_max_height},
		{ "create_section_aabb",	lterrain_create_section_aabb},
		{ "update_vertex_buffers",	lterrain_update_vertex_buffers},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
}




