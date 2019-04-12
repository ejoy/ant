#define LUA_LIB


#include "bgfx/bgfx.h"
#include "glm/glm.hpp"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

// stl
#include <limits>
#include <vector>
#include <fstream>

// c std
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdlib>

//@1:只负责地形几何相关的Pos,Normal,Uv,Tangent 的计算,创建，和编辑、更新
//@2:只接受高度图，画刷，等更改几何形体，顶点索引内容等lua数据,不持有任何图形相关的handle
//@3:只接受编辑动作及其参数
//@4:提供给外部对地形数据的访问接口，获取位置高度，光线投射集中选取位置
//@5:当 grid size > 256 时，需要使用的index32 的索引

// 如果是合并到bgfx 工程，静态引用有效，则交互会更方便些，只生成一个文件
// 目前,为了工程简单化，独立成lterrain.dll,方便使用，并且不影响已有工程，可自由实验修改测试
// 测试完成后的工程文件，又可很方便的融入的lua bgfx 工程
// API 可以进一步根据需求修改，让交互更简单些并符合应用需求

//Big/Small Endian
#ifdef __MAC_
#elif  __IOS__
#elif  __WIN64
#endif

#define MY_DEBUG

int is_little_endian(void) {
	union check_endian {
		short ivalue;
		char  cvalue;
	} word;
	word.ivalue = 1;

#ifdef MY_DEBUG
	//int  value = 0x00000001;
	//char *ptr = (char*)&value;
	//printf("p=%p,%x,%x,%x,%x\n",ptr,ptr[0],ptr[1],ptr[2],ptr[3]);
	//return ptr[0];
#endif 	
	return word.cvalue;
}
// big to small
int16_t word_btol(uint16_t sw) {
	uint8_t *p = (uint8_t*)&sw;
	int16_t dw = ((int16_t)p[0] << 8) + (int16_t)p[1];

#ifdef MY_DEBUG
	printf("c terrain: sw = %x", sw);
	printf("c terrain: sw[0] =%x,sw[1] = %x\n", p[0], p[1]);
	printf("c terrain: dw = %x", dw);
	printf("c terrain: dw[0] =%x,dw[1] = %x\n", dw & 0x00ff, (dw & 0xff00) >> 8);
#endif
	return dw;
}

enum SMOOTH_MODE {
	NONE = 0,
	SPEC,
	QUAD,
	GAUSSIAN,
	DEFAULT = GAUSSIAN,
};

struct terrain_data {
	// setting
	uint32_t width;				// 地形宽度 x, 图形逻辑单位
	uint32_t length;			// 地形长度 z
	uint32_t height;			// 地形高度 y

	uint32_t grid_width;		// 宽度格子数, 地形网格分辨率
	uint32_t grid_length;		// 长度格子数

	float	uv0Scale;			// 0 layer texcoord
	float   uv1Scale;			// 1 layer texcoord

	float   min_height;
	float   max_height;

	struct heightmapdata {
		uint8_t *	data;
		uint32_t 	sizebytes;
		uint8_t     elembits;
	};

	heightmapdata heightmap;

	struct streambuffer {
		bgfx::VertexDecl * 	vdecl;
		uint8_t *			vertices;
		uint32_t			vertex_count;
		uint32_t *			indices;
		uint32_t 			index_count;
	};

	streambuffer buffer;

	// two mode
	// ib,vb											// lua maintains
	//bgfx_dynamic_vertex_buffer_handle_t	vbh;	  	// VertexBuffer
	//bgfx_dynamic_index_buffer_handle_t  	ibh;
	// dynamic ib,vb
	//bgfx_dynamic_vertex_buffer_handle_t 	dvbh;	  	// Dynamic VertexBuffer
	//bgfx_dynamic_index_buffer_handle_t  	dibh;

	// program
	//bgfx_program_handle_t		prog;     			  	// 地形 program
	//bgfx_uniform_handle_t		u_baseTexture;		  	// paint texure  Uniform
	//bgfx_uniform_handle_t		u_maskTexture;		  	// mask Uniform
};

//--------------------------------
// tested
/*
static int
lterrain_attrib(lua_State *L)
{
	struct TerrainData_t *terrain = (struct TerrainData_t*) lua_touserdata(L, 1);
	const char *name = luaL_checkstring(L, 2);          // terrain's  attrib  field
	#ifdef MY_DEBUG
	printf("access attrib = %s\n", name);
	#endif
	lua_pushnumber(L,terrain->gridWidth);
	return 1;
}
*/

//static int
//lterrain_vb_close(lua_State *L) {
//	uint8_t *vertices = (uint8_t *)lua_touserdata(L, 1);
//	// do nothing
//#ifdef MY_DEBUG		
//	printf("gc: vb %p destroy.\n", vertices);
//#endif
//	return 0;
//}
//
//static int
//lterrain_ib_close(lua_State *L) {
//	uint32_t *indices = (uint32_t *)lua_touserdata(L, 1);
//	// do nothing
//#ifdef MY_DEBUG		
//	printf("gc: ib %p destroy.\n", indices);
//#endif 	
//	return 0;
//}


//// alloc vertex buffer and return to lua
//static int
//lterrain_getVB(lua_State *L) {
//	struct TerrainData_t *terrain = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_DATA");
//	if (terrain->vertices)
//		return luaL_error(L, "vertices already exist.");
//
//	bgfx::VertexDecl *vd = terrain->vdecl;
//	uint32_t num = terrain->gridWidth * terrain->gridLength;
//
//#ifdef MY_DEBUG	
//	printf("c terrain: new alloc vertex = %d, strid =%d\n", num, vd->getStride());
//#endif 	
//
//	terrain->vertices = (uint8_t*)lua_newuserdata(L, num * vd->getStride());
//
//	if (luaL_newmetatable(L, "TERRAIN_VB")) {
//		lua_pushcfunction(L, lterrain_vb_close);        // register gc function
//		lua_setfield(L, -2, "__gc");
//	}
//	lua_setmetatable(L, -2);
//
//	return 1;
//}

//static int
//lterrain_getNumVerts(lua_State *L) {
//	struct TerrainData_t *terrain = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_DATA");
//	lua_pushnumber(L, terrain->vertexCount);
//	return 1;
//}

//static int
//lterrain_getNumIndices(lua_State *L) {
//	struct TerrainData_t *terrain = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_DATA");
//	lua_pushnumber(L, terrain->indexCount);
//	return 1;
//}
// alloc inddex and return to lua
//static int
//lterrain_getIB(lua_State *L) {
//	struct TerrainData_t *terrain = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_DATA");
//	if (terrain->indices)
//		return luaL_error(L, "indices already exist.");
//
//	uint32_t num = terrain->gridWidth * terrain->gridLength;
//	terrain->indices = (uint32_t*)lua_newuserdata(L, num * sizeof(uint32_t) * 6);
//#ifdef MY_DEBUG	
//	printf("c terrain: new alloc vertex = %d, index =%d(%d)\n", num, (uint32_t)(num * 6), (uint32_t)(num * sizeof(uint32_t) * 6));
//#endif 	
//
//	if (luaL_newmetatable(L, "TERRAIN_IB")) {
//		lua_pushcfunction(L, lterrain_ib_close);        // register gc function
//		lua_setfield(L, -2, "__gc");
//	}
//	lua_setmetatable(L, -2);
//	return 1;
//}

static inline int get_smooth_mode_range(SMOOTH_MODE mode) {
	return (int)mode;
}

static int 
lterraindata_gridwidth(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	lua_pushnumber(L, terrain->width);
	return 1;
}

static
int lterraindata_gridheight(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	lua_pushnumber(L, terrain->height);
	return 1;
}

static int
lterraindata_gridlength(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	lua_pushnumber(L, terrain->length);
	return 1;
}

static int
lterraindata_buffer(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");

	const auto &buffer = terrain->buffer;

	lua_pushlightuserdata(L, buffer.vertices);
	lua_pushinteger(L, buffer.vertex_count);

	lua_pushlightuserdata(L, buffer.indices);
	lua_pushinteger(L, buffer.index_count);

	return 4;
}

static int
lterraindata_bounding(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	assert("not implement");
	return 1;
}

static int
lterraindata_buffersize(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	lua_pushinteger(L, terrain->buffer.vertex_count);
	lua_pushinteger(L, terrain->buffer.index_count);
	return 2;
}

static inline uint32_t
getfield_touint(lua_State *L, int table, const char *key) {
	if (lua_getfield(L, table, key) != LUA_TNUMBER) {
		luaL_error(L, "Need %s as number", key);
	}
	uint32_t ivalue = (int)luaL_checkinteger(L, -1);
	lua_pop(L, 1);
	return ivalue;
}
static inline float
getfield_tofloat(lua_State *L, int table, const char *key) {
	if (lua_getfield(L, table, key) != LUA_TNUMBER) {
		luaL_error(L, "Need %s as number", key);
	}
	float value = (float)luaL_checknumber(L, -1);
	lua_pop(L, 1);
	return value;
}

static inline float
get_scale(terrain_data *terrain, const char* which) {
	if (strcmp(which, "width") == 0) {
		return (float)terrain->width / terrain->grid_width;
	} 
	if (strcmp(which, "height") == 0) {
		return (float)terrain->height / (terrain->heightmap.elembits == 8 ? 256.f : 65536.f);
	} 
	
	if (strcmp(which, "length") == 0) {
		return (float)terrain->length / terrain->grid_length;
	}

	assert(false && "not support!");
	return std::numeric_limits<float>::lowest();
}



static inline void
load_heightmap_data(lua_State *L, int index, terrain_data *terrain) {
	const char* path = lua_tostring(L, index);
	std::ifstream iff(path, std::ios::in | std::ios::binary);
	iff.seekg(std::ios::beg);
	terrain->heightmap.sizebytes = (uint32_t)iff.tellg();
	iff.seekg(std::ios::end);
	terrain->heightmap.data = new uint8_t[terrain->heightmap.sizebytes];
	iff.read((char*)(terrain->heightmap.data), terrain->heightmap.sizebytes);
	iff.close();
}

static inline bool 
fetch_terrain_data(lua_State *L, int index, terrain_data* terrain) {
	luaL_checktype(L, index, LUA_TTABLE);

	terrain->grid_width	= getfield_touint(L, index, "grid_width");
	terrain->grid_length = getfield_touint(L, index, "grid_length");	
	terrain->width		= getfield_touint(L, index, "width");   // maybe float is better
	terrain->length		= getfield_touint(L, index, "length");
	terrain->height		= getfield_touint(L, index, "height");

	terrain->uv0Scale	= getfield_tofloat(L, index, "uv0_scale");
	terrain->uv1Scale	= getfield_tofloat(L, index, "uv1_scale");

	terrain->min_height	= terrain->max_height = 0;

	lua_getfield(L, index, "heightmap");
	load_heightmap_data(L, -1, terrain);
	lua_pop(L, 1);

	if (terrain->width == 0 || 
		terrain->height == 0 || 
		terrain->length == 0 || 
		terrain->grid_width == 0 || 
		terrain->grid_length == 0) {
		luaL_error(L, "width = %d, height = %d, length = %d, grid_width = %d, grid_height = %d, one of them is zero",
			terrain->width, terrain->height, terrain->length,
			terrain->grid_width, terrain->grid_length);
		return false;
	}

	return true;
}

static inline void 
terrain_default_init(terrain_data *terrain) {
	terrain->grid_width = 513;
	terrain->grid_length = 513;
	
	terrain->width = 513;
	terrain->length = 513;
	terrain->height = 385;

	terrain->uv0Scale = 80 * 0.625f;
	terrain->uv1Scale = 1.0f;
}

static int
lterrain_del(lua_State *L) {
	terrain_data* terrain = (terrain_data*) lua_newuserdata(L, sizeof(terrain_data));
	if (terrain->heightmap.data) {
		delete[]terrain->heightmap.data;
	}
	return 0;
}

static inline glm::vec2
calc_uv(const glm::vec2 &gridIdx, const glm::vec2 &size, float scale, float offset) {
	auto r = (gridIdx + offset) * size * scale;
	r.y = -r.y;
	return r;
}

static void
init_terrain_mesh(terrain_data* terrain) {
	const glm::vec3 vertexscale(get_scale(terrain, "width"), get_scale(terrain, "height"), get_scale(terrain, "length"));

	terrain->min_height = std::numeric_limits<float>::max();
	terrain->max_height = std::numeric_limits<float>::lowest();

	auto get_height_from_uint8 = [](uint8_t *v) {return float(*v); };
	auto get_height_from_uint16 = [](uint8_t *v) {return float(*(uint16_t*)v); };
	auto get_height = terrain->heightmap.elembits == 8 ? get_height_from_uint8 : get_height_from_uint16;

	const glm::vec2 invsize(1.f / terrain->grid_width, 1.f / terrain->grid_length);
	auto &buffer = terrain->buffer;

	for (uint32_t y = 0; y < terrain->grid_length; ++y) {
		for (uint32_t x = 0; x < terrain->grid_width; ++x) {
			auto decl = terrain->buffer.vdecl;
			const uint16_t stride = decl->getStride();

			const uint32_t vertexidx = terrain->grid_width * y + x;

			if (decl->has(bgfx::Attrib::Position)) {
				const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);

				glm::vec3* vert = (glm::vec3*) &buffer.vertices[vertexidx * stride + offset];
				auto hm = &terrain->heightmap.data[y* terrain->grid_width + x];
				*vert = vertexscale * glm::vec3(float(x), get_height(hm), float(y));

				terrain->max_height = glm::max(vert->y, terrain->max_height);
				terrain->min_height = glm::min(vert->y, terrain->min_height);
			}
			//uv0
			if (decl->has(bgfx::Attrib::TexCoord0)) {
				const uint16_t offset = decl->getOffset(bgfx::Attrib::TexCoord0);
				glm::vec2* uv = (glm::vec2*) &buffer.vertices[vertexidx*stride + offset];

				*uv = calc_uv(glm::vec2(x, y), invsize, terrain->uv0Scale, 0.5f);
			}
			//uv1 - for mask,color maps
			if (decl->has(bgfx::Attrib::TexCoord1)) {
				const uint16_t offset = decl->getOffset(bgfx::Attrib::TexCoord1);
				glm::vec2* uv = (glm::vec2*) &buffer.vertices[vertexidx*stride + offset];
				*uv = calc_uv(glm::vec2(x, y), invsize, terrain->uv1Scale, 0.01f);
			}
			//normal
			if (decl->has(bgfx::Attrib::Normal)) {
				const uint16_t offset = decl->getOffset(bgfx::Attrib::Normal);
				glm::vec3* normal = (glm::vec3*) &buffer.vertices[vertexidx*stride + offset];
				*normal = glm::vec3(0.f, 1.f, 0.f);
			}
			//tangent
			if (decl->has(bgfx::Attrib::Tangent)) {
				const uint16_t offset = decl->getOffset(bgfx::Attrib::Tangent);
				glm::vec3* tangent = (glm::vec3*) &buffer.vertices[vertexidx*stride + offset];
				*tangent = glm::vec3(1.f, 0.f, 0.f);
			}
		}
	}

	for (uint32_t y = 0; y < (terrain->grid_length - 1); ++y) {
		const uint32_t y_offset = y * terrain->grid_width;

		for (uint32_t x = 0; x < (terrain->grid_width - 1); ++x) {
			const auto ibidx = (y_offset + x) * 6;
			buffer.indices[ibidx + 0] = y_offset + x + 1;
			buffer.indices[ibidx + 1] = y_offset + x + terrain->grid_width;
			buffer.indices[ibidx + 2] = y_offset + x;
			buffer.indices[ibidx + 3] = y_offset + x + terrain->grid_width + 1;
			buffer.indices[ibidx + 4] = y_offset + x + terrain->grid_width;
			buffer.indices[ibidx + 5] = y_offset + x + 1;
		}
	}
}

static inline bool
init_stream_buffer(terrain_data::streambuffer &buffer, uint32_t width, uint32_t length) {
	assert(buffer.vdecl);

	if (width < 2 || length < 2) {
		return false;
	}

	const auto stride = buffer.vdecl->getStride();
	buffer.vertex_count = width * length;
	buffer.vertices = new uint8_t[buffer.vertex_count * stride];

	buffer.index_count = 6 * (width - 1) * (length - 1);		// primitive type is triangle list, is triangle strip more appropriate
	buffer.indices = new uint32_t[buffer.index_count];
	return true;
}

static inline bool 
in_terrain_bounds(terrain_data* terrain, int h, int w) {
	return 0<= h && h < (int)terrain->grid_length && 
			0 <= w && w < (int)terrain->grid_width;
}

// fake gassiah smooth
//  terrain context,pos x,y,smooth radius
static inline float 
average(terrain_data *terrain, int i, int  j, uint8_t range) {
	float avg = 0.0f;
	float num = 0.0f;

	const auto decl = terrain->buffer.vdecl;
	const uint16_t stride = decl->getStride();
	const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);

	uint8_t *vertices = terrain->buffer.vertices;
	for (int m = i - range; m <= i + range; ++m) {
		for (int n = j - range; n <= j + range; ++n) {
			if (in_terrain_bounds(terrain, m, n)) {
				int vertCount = (m * terrain->grid_width) + n;
				const glm::vec3* vert = (const glm::vec3*) &vertices[vertCount*stride + offset];
				avg += vert->y;
				++num;
			}
		}
	}
	return avg / num;
}


static void 
smooth_terrain_gaussian(terrain_data *terrain, uint8_t range) {
	const auto decl = terrain->buffer.vdecl;
	const uint16_t stride = decl->getStride();
	const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);
	
	for (uint32_t j = 0; j < terrain->grid_length; j++) {
		for (uint32_t i = 0; i < terrain->grid_width; i++) {
			//Gassiah like smooth without point weights			
			const uint32_t index = (j * terrain->grid_width) + i;
			glm::vec3 *vert = (glm::vec3*) &(terrain->buffer.vertices[index*stride + offset]);
			vert->y = average(terrain, j, i, range);
		}
	}
}

static void 
smooth_terrain_mesh(terrain_data *terrain, SMOOTH_MODE mode) {
	if (terrain->heightmap.elembits != 8)
		return;

	if (mode == SMOOTH_MODE::DEFAULT) {		
		smooth_terrain_gaussian(terrain, get_smooth_mode_range(mode));
	}
	return;
	/*
	void smoothTerrain(enum SMOOTH_MODE mode = SMOOTH_MODE::DEFAULT )
	{
		int width   = m_terrain.m_gridWidth;
		int height  = m_terrain.m_gridLength;
		int i, j,index;
		glm::vec3 { float x, y, z; };
		glm::vec3 sum;
		PosTexCoord0Vertex *vertices = m_terrain.m_vertices;
		if (mode == SMOOTH_MODE::NONE)
			return;
		for (j = 0; j< height; j++)
		{
			for (i = 0; i< width; i++)
			{
				if (mode == SMOOTH_MODE::DEFAULT) {
					//Gassiah Smooth
					sum.y = Average(j, i, 2);
					index = (j * width) + i;
					vertices[index].m_y = (sum.y);
					continue;
				}

				int count = 0;
				// Initialize the sum.
				sum.x = 0.0f;
				sum.y = 0.0f;
				sum.z = 0.0f;

				// Initialize the count.
				count = 0;

				// Bottom left face.
				if ( mode == SMOOTH_MODE::QUAD ) {  // quad
					if (((i - 1) >= 0) && ((j - 1) >= 0))
					{
						index = ((j - 1) * (width)) + (i - 1);
						sum.x += vertices[index].m_x;
						sum.y += vertices[index].m_y;
						sum.z += vertices[index].m_z;
						count++;

					}

					// Bottom right face.
					if ((i < (width - 1)) && ((j - 1) >= 0))
					{
						index = ((j - 1) * (width)) + (i + 1);

						sum.x += vertices[index].m_x;
						sum.y += vertices[index].m_y;
						sum.z += vertices[index].m_z;
						count++;
					}

					// Upper left face.
					if (((i - 1) >= 0) && (j < (height - 1)))
					{
						index = ((j + 1) * (width)) + (i - 1);
						sum.x += vertices[index].m_x;
						sum.y += vertices[index].m_y;
						sum.z += vertices[index].m_z;
						count++;
					}

					// Upper right face.
					if ((i < (width - 1)) && (j < (height - 1)))
					{
						index = ((j + 1) * (width)) + (i + 1);
						sum.x += vertices[index].m_x;
						sum.y += vertices[index].m_y;
						sum.z += vertices[index].m_z;
						count++;
					}
				}

				if ( mode == SMOOTH_MODE::SPEC )  {
					if( i<width-1 && j<height-1 )
					{
						index = (j * width) + (i + 1);
						sum.y += vertices[index].m_y;
						count++;

						index = (j+1) * width + i ;
						sum.y += vertices[index].m_y;
						count++;

						index = (j+1) * width + (i+1) ;
						sum.y += vertices[index].m_y;
						count++;
					}
				}

				index = (j * width) + i;
				sum.y += vertices[index].m_y;
				count++;

				// Take the average of the faces touching this vertex.
				sum.y = (sum.y / (float)count);

				// Get an index to the vertex location in the height map array.
				index = (j * width) + i;

				// Normalize the final shared normal for this vertex and store it in the height map array.
				vertices[index].m_y = (sum.y );

			}
		}
	}
	*/
}

static void
update_terrain_normal_fast(terrain_data *terrain) {
	// normal attrib does not exist
	const auto decl = terrain->buffer.vdecl;
	if (!decl->has(bgfx::Attrib::Normal))
		return;

	const int stride = decl->getStride();
	const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);
	const int normal_offset = decl->getOffset(bgfx::Attrib::Normal);

	std::vector<glm::vec3> normals((terrain->grid_width - 1) * (terrain->grid_length - 1));

	uint8_t *verts = terrain->buffer.vertices;

	// Go through all the faces in the terrain mesh and calculate their normals.
	//  (v1) i +---+ (v2) i+1
	//         |  /
	//         | /
	//         |/
	//  (v3) i,j+1

	for (uint32_t j = 0; j < (terrain->grid_length - 1); j++) {
		for (uint32_t i = 0; i < (terrain->grid_width - 1); i++) {
			const int index1 = (j * terrain->grid_width) + i;
			const int index2 = (j * terrain->grid_width) + (i + 1);
			const int index3 = ((j + 1) * terrain->grid_width) + i;

			const auto v1 = *(glm::vec3*)(&verts[index1*stride + offset]);
			const auto v2 = *(glm::vec3*)(&verts[index2*stride + offset]);
			const auto v3 = *(glm::vec3*)(&verts[index3*stride + offset]);

			const auto e1 = v1 - v3;
			const auto e2 = v3 - v2;

			const uint32_t index = (j * (terrain->grid_width - 1)) + i;
			normals[index] = glm::cross(e1, e2);
		}
	}

	// go through all the vertices and take an average of each face normal
	for (int j = 0; j < (int)terrain->grid_length; ++j) {
		for (int i = 0; i < (int)terrain->grid_width; ++i) {
			int indices[4] = { -1 };
			// Bottom left face.
			if (((i - 1) >= 0) && ((j - 1) >= 0)) {
				indices[0] = ((j - 1) * (terrain->grid_width - 1)) + (i - 1);  //height
			}

			// Bottom right face.
			if ((i < int(terrain->grid_width - 1)) && ((j - 1) >= 0)) {
				indices[1] = ((j - 1) * (terrain->grid_width - 1)) + i;				
			}

			// Upper left face.
			if ((0 <= (i - 1)) && (j < int(terrain->grid_length - 1))) {
				indices[2] = (j * (terrain->grid_width - 1)) + (i - 1);
				
			}

			// Upper right face.
			if ((i < int(terrain->grid_width - 1)) && (j < int(terrain->grid_length - 1))) {
				indices[3] = (j * (terrain->grid_width - 1)) + i;
			}

			glm::vec3 sum(0.f);
			int count = 0;
			for (int ii = 0; ii < 4; ++ii) {
				const int idx = indices[ii];
				if (idx >= 0) {
					sum += normals[idx];
					++count;
				}
			}
			sum /= count;

			// Get an index to the vertex location in the height map array.
			const uint32_t index = (j * terrain->grid_width) + i;

			glm::vec3* dst_normals = (glm::vec3*) &verts[index*stride + normal_offset];
			*dst_normals = glm::normalize(sum);
		}
	}
}

/*
 we have triangle:
		v1
	   /  \
	  / pt \
	 v0----v2
 then:
	e0 = v2 - v0
  e1 = v1 - v0
  e2 = pt - v0

if pt is inside triangle, then:
		pt = v0 + u * e0 + v * e1
	==>
		pt - v0 = u * e0 + v * e1
  ==>
		e2 = u * e0 + v * e1
	==>(here, we can dot any vector we want, replace e0 as vec3(1, 0, 0) or e1 as vec3(0, 1, 0) also get the same result)
		e2 dot e0 = (u * e0) dot e0 + (v * e1) dot e0
		e2 dot e1 = (u * e0) dot e1 + (v * e1) dot e1
 solve these formula can get the u and v value
u and v is scalar
for this formula is correct
u ==> [0, 1] && v ==> [0, 1] && u + v <= 1

	1. move v0 to origin
	2. pt - v0 is equal v * e1 + u * e0, because v * e1 is a vector lied on e1 and u * e0 also lied on e0(vector add)
	then the u/v value can determine what pt is
*/

static inline bool
point_in_triangle(const glm::vec3 &pt, const glm::vec3 &v0, const glm::vec3 &v1, const glm::vec3 &v2) {
	const auto e0 = v2 - v0;
	const auto e1 = v1 - v0;
	const auto e2 = pt - v0;

	const float dot00 = glm::dot(e0, e0);
	const float dot01 = glm::dot(e0, e1);
	const float dot02 = glm::dot(e0, e2);
	const float dot11 = glm::dot(e1, e1);
	const float dot12 = glm::dot(e1, e2);

	const float inverDeno = 1 / (dot00 * dot11 - dot01 * dot01);

	const float u = (dot11 * dot02 - dot01 * dot12) * inverDeno;
	if (u < 0 || u > 1) // if u out of range, return directly
	{
		return false;
	}

	const float v = (dot00 * dot12 - dot01 * dot02) * inverDeno;
	if (v < 0 || v > 1) // if v out of range, return directly
	{
		return false;
	}

	return u + v <= 1;
}

struct ray {
	glm::vec3 start;
	glm::vec3 dir;
};


// make ray as line function:
//		p(t) = start + t * dir	
// make plane function as:
//		n dot p + d = 0
// here:
//		start : 3d point
//		dir : a 3d vector	(no need to be a unit vector)
//		t : scalar
//		n : 3d vector,		(no need to be a unit vector)
//		p : a point lied on plane, 
//		d : the distance to origin(when n is unit vector)
// we need to calculate intersetion point between ray and plane, so p is also lied on ray
// we can replace p as:
//	n dot (start + t * dir) + d = 0
// solve t as :
//	n dot start + t * (dir dot n) + d = 0
//	t = -(d + n dot start) / (dir dot n)
//  then we can get what p is
static inline bool
ray_interset_plane(const ray& r, const glm::vec3 &v0, const glm::vec3 &v1, const glm::vec3 &v2, glm::vec3 &intersetion) {
	const glm::vec3 e0 = v1 - v0, e1 = v2 - v0;

	const auto normal = glm::cross(e0, e1);		// no need to be a unit vector
	const float dist = -glm::dot(normal, v0);	

	const float dn = glm::dot(normal, r.dir);	
	if (fabs(dn) < 0.0001f) {
		return false;
	}
	
	const float sd = -1.0f * (glm::dot(normal, r.start) + dist);
	const float t = sd / dn;
	
	intersetion = r.start + (r.dir * t);
	return true;
}

static inline bool 
ray_triangle_intersection_point(const ray &r,
	const glm::vec3 &v0, 
	const glm::vec3 &v1, 
	const glm::vec3 &v2,
	glm::vec3 &intersection_point) {

	glm::vec3 intersetion;
	if (ray_interset_plane(r, v0, v1, v2, intersetion)) {
		if (point_in_triangle(intersetion, v0, v1, v2)) {
			intersection_point = intersetion;
			return true;
		}
	}
	return false;

	//const glm::vec3 edges[3] = {
	//	v1 - v0,
	//	v2 - v1,
	//	v0 - v2,
	//};

	//const glm::vec3 vertices[3] = {
	//	v0, v1, v2 };

	//for (int ii = 0; ii < 3; ++ii) {
	//	const auto edgeNormal = glm::cross(edges[ii], normal);
	//	const auto temp = intersetion - vertices[ii];

	//	// project temp vector
	//	const float dtm = glm::dot(edgeNormal, temp);
	//	if (dtm > 0.001f) {
	//		return false;
	//	}
	//}
}

// project x,z on triangle, return the height of this position
// further should be add ray cast parameters
bool check_height_of_triangle(float x, float z, float *height, 
	const glm::vec3& v0, const glm::vec3& v1, const glm::vec3& v2) {

	const ray r = {
		glm::vec3(x, 1000.f, z),
		glm::vec3(0.f, -1000.f, 0.0)
	};
	glm::vec3 ip;
	if (ray_triangle_intersection_point(r, v0, v1, v2, ip)) {
		*height = ip[1];
		return true;
	}
	return false;
}

// get terrain height at x,z position
static bool 
terrain_get_height(terrain_data* terrain, float x, float z, float *height) {
	const auto decl = terrain->buffer.vdecl;
	const uint16_t stride = decl->getStride();
	const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);
	uint8_t* verts = terrain->buffer.vertices;

	const int    xindex = (int)(x / get_scale(terrain, "width"));
	const int    zindex = (int)(z / get_scale(terrain, "length"));

	const int    left = xindex - 1;
	const int    right = xindex + 1;
	const int    top = zindex - 1;
	const int    bottom = zindex + 1;

	for (int j = top; j < bottom; j++) {
		for (int i = left; i < right; i++) {
			if (!in_terrain_bounds(terrain, j, i) || !in_terrain_bounds(terrain, j + 1, i + 1))
				continue;
			// 1 ----- 2
			//  |   / |
			//  |  /  |
			//  | /   |
			// 3 ----- 4
			const uint32_t index1 = (j * terrain->grid_width) + i;
			const uint32_t index2 = (j * terrain->grid_width) + (i + 1);
			const uint32_t index3 = ((j + 1) * terrain->grid_width) + i;
			const uint32_t index4 = ((j + 1) * terrain->grid_width) + (i + 1);

			const glm::vec3& v0 = *(const glm::vec3*)&verts[index1*stride + offset];
			const glm::vec3& v1 = *(const glm::vec3*)&verts[index2*stride + offset];
			const glm::vec3& v2 = *(const glm::vec3*)&verts[index3*stride + offset];
			const glm::vec3& v3 = *(const glm::vec3*)&verts[index4*stride + offset];

			if (check_height_of_triangle(x, z, height, v0, v1, v2))
				return true;

			if (check_height_of_triangle(x, z, height, v1, v3, v2))
				return true;
		}
	}

	if (height)
		*height = 0.0f;
	return false;
}

float terrain_get_raw_height(terrain_data* terrain, int x, int z) {
	const auto decl = terrain->buffer.vdecl;
	const uint16_t stride = decl->getStride();
	const uint16_t offset = decl->getOffset(bgfx::Attrib::Position);
	
	if (!in_terrain_bounds(terrain, z, x))
		return std::numeric_limits<float>::lowest();


	// 1 ----- 2
	//  |   / |
	//  |  /  |
	//  | /   |
	// 3 ----- 4
	int   index = (z * terrain->grid_width) + x;
	glm::vec3 *vert = (glm::vec3*) &terrain->buffer.vertices[index*stride + offset];
	return vert->y;
}

static int
lterraindata_height(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	float x = (float)luaL_checknumber(L, 2);
	float y = (float)luaL_checknumber(L, 3);

	float height = 0.0f;
	bool  hit = terrain_get_height(terrain, x, y, &height);

	lua_pushboolean(L, hit);
	lua_pushnumber(L, height);

	return 2;
}

static int
lterraindata_raw_height(lua_State *L) {
	terrain_data *terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");
	int x = (int)luaL_checkinteger(L, 2);
	int y = (int)luaL_checkinteger(L, 3);

	float height = 0.f;
	height = terrain_get_raw_height(terrain, x, y);
	lua_pushnumber(L, height);

#ifdef MY_DEBUG_OUT
	float min_height = 99999.f;
	float max_height = -99999.f;
	FILE *out = fopen("ter_raw_height.txt", "w+");
	if (out) {
		for (int y = 0; y < terrain->grid_length; y++) {
			for (int x = 0; x < terrain->grid_width; x++) {
				float hi = terrain_get_raw_height(terrain, x, y);
				fprintf(out, "%06.2f ", hi);
				if (hi < min_height) min_height = hi;
				if (hi > max_height) max_height = hi;
			}
			fprintf(out, "\r");
		}
		fprintf(out, "max = %06.2f ", max_height);
		fprintf(out, "min = %06.2f ", min_height);
		fclose(out);
	}
#endif 	

	return 1;
}


static int
lterraindata_update_normals(lua_State *L) {
	terrain_data* terrain = (terrain_data*) luaL_checkudata(L, 1, "TERRAIN_DATA");	
	if (terrain->buffer.vertices == NULL)
		return luaL_error(L, "must alloc vertices first.\n");

	update_terrain_normal_fast(terrain);

	return 0;
}

static int
lterrain_create(lua_State *L) {
	terrain_data* terrain = (terrain_data*)lua_newuserdata(L, sizeof(terrain_data));
	luaL_getmetatable(L, "TERRAIN_DATA");
	lua_setmetatable(L, -2);

	memset(terrain, 0, sizeof(terrain_data));
	if (fetch_terrain_data(L, 1, terrain)) {
		terrain->buffer.vdecl = (bgfx::VertexDecl *)lua_touserdata(L, 2);

		init_stream_buffer(terrain->buffer, terrain->grid_width, terrain->grid_length);
		init_terrain_mesh(terrain);
		smooth_terrain_mesh(terrain, SMOOTH_MODE::DEFAULT);
		update_terrain_normal_fast(terrain);
	}
	return 1;
}

// 其他构思草稿，数据存放在那一段，简单性足够与否，以后如何扩充？

// 或者地形关卡 level 文件内容由lua 加载
// 解析出 heightmap data 在传入 lterrain.dll
// lterrain.dll 创建 mesh，vb，ib memory
// lua api 层可以加载文件分析数据，调用 c terrain 分配vb，ib memory 生成 vbh，ibh，handle
// 但如果需要编辑修改，需要cpu持有顶点数据，vertex 方便修改，编辑，碰撞检测
// lua api 持有 vertex data 更新效率慢，计算不够友好，还是需要 c 持有 vertex，两者通过 userdata 交互
// c 提供对应的api 供给 lua 访问必须要的参数，比如 terrain_getWidth,terrain_getHeight
// terrain_getHeight(x,y) ,terrain_getHeight(vec3 view,vec3 ray)，update_vb,update_ib 修改 terrainData
//

// lua  层的 math3d 库 ？ 如何使用？
// 如果 Vertex Decalre 由lua创建,内容访问 c lua bgfx 是否存在方法解析vertex attrib offset ？
//      已学习查阅,皆可实现

// Vertex Declare 由外部 lua 层提供，产生 vdecl 的userdata
//   c terrain 提供最大的需要的属性支持，根据 lua 指定的 attrib 进行必要的计算
//   根据 lua attrib 的属性定义的不同，实现不同的渲染特点，允许用户重写自己的 shader


// all in one context
// or multi parameters


// lua set
//bgfx.set_transform(mtx)
//bgfx.set_state(state.state)
/*
ctx.m_state = {}
ctx.m_state[1] = {
	state = bgfx.make_state{
	WRITE_MASK = "RGBAZ",
	DEPTH_TEST = "LESS",
	CULL = "CCW",
	MSAA = true,
},
program = ctx.m_progShadow,
viewId = RENDER_SHADOW_PASS_ID,
textures = {}
}
// shadowmap
// mesh load
*/

static void
register_terrain_data_mt(lua_State *L) {
	if (luaL_newmetatable(L, "TERRAIN_DATA")) {
		luaL_Reg l[] = {
			{"grid_width",	lterraindata_gridwidth},
			{"grid_length",	lterraindata_gridlength},
			{"grid_height",	lterraindata_gridheight},
			{"height",		lterraindata_height},
			{"raw_height",	lterraindata_raw_height},
			{"buffer",		lterraindata_buffer},
			{"buffersize",	lterraindata_buffersize},
			{"bounding",	lterraindata_bounding},			
			//{"update_normals",	lterraindata_update_normals},			
			{NULL,NULL},
		};
		luaL_setfuncs(L, l, 0);
		lua_setfield(L, -2, "__index");
		lua_pushcfunction(L, lterrain_del);        // register gc function
		lua_setfield(L, -2, "__gc");
	}
}


LUAMOD_API int
luaopen_lterrain(lua_State *L) {
	luaL_checkversion(L);
	register_terrain_data_mt(L);
	luaL_Reg l[] = {		
		{ "create",			lterrain_create},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}



