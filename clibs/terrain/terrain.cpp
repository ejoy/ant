#define LUA_LIB
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <bgfx/bgfx.h>

extern "C" {
#include <bgfx/c99/bgfx.h>
#include <bgfx/c99/platform.h>
}

// #include <bgfx/bgfx.h>
// #include <bx/allocator.h>

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

#ifdef __cplusplus
extern "C" {
#endif

#define MY_DEBUG

#define TERRAIN_CONFIG_IMPLEMENT_DEFAULT_ALLOCATOR  1

// #if TERRAIN_CONFIG_IMPLEMENT_DEFAULT_ALLOCATOR
// 	bx::AllocatorI* getDefaultAllocator()
// 	{
// 		BX_PRAGMA_DIAGNOSTIC_PUSH();
// 		BX_PRAGMA_DIAGNOSTIC_IGNORED_MSVC(4459);							// warning C4459: declaration of 's_allocator' hides global declaration
// 		BX_PRAGMA_DIAGNOSTIC_IGNORED_CLANG_GCC("-Wshadow");
// 		static bx::DefaultAllocator s_allocator;
// 		return &s_allocator;
// 		BX_PRAGMA_DIAGNOSTIC_POP();
// 	}
// #endif

int is_little_endian(void)
{
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
int16_t word_btol(uint16_t sw)
{
	uint8_t *p = (uint8_t*)&sw;
	int16_t dw = ((int16_t)p[0]<<8) + (int16_t)p[1];

#ifdef MY_DEBUG
	printf("c terrain: sw = %x",sw);
	printf("c terrain: sw[0] =%x,sw[1] = %x\n",p[0],p[1]);
	printf("c terrain: dw = %x",dw);
	printf("c terrain: dw[0] =%x,dw[1] = %x\n",dw&0x00ff,(dw&0xff00)>>8);
#endif
	return dw;
}

// TerrainLevel: terrain level config file, use lua table
// c 端不持有，level config 这些管卡配置数据由lua 管理，并传入
// c 端只关心，数据流和参数，为vertex，uv, normal，tangent,smooth 等提供计算支持
// view,state,shader,
// texture，program，unifroms，vbh，ibh 等渲染对象，皆由lua 创建并管理

// 地形关卡配置文件
// 地形几何和材质，由设计配置

// 几何配置
// raw =  pvp.raw
// grid_width  = 513
// grid_length = 513
// width  = 400
// length = 400
// height = 300
// bit = 8

// 材质配置
// num_layers = 4
// textures = {
//    rock.dds
//    rock.dds
//    rock.dds
//    rock.dds
// }
// masks = {
//    mask.png
//    mask.png
//    mask.png
//    mask.png
// }

// TerrainData userdata return to lua as terrain Context data
// 地形运行时数据
struct TerrainData_t
{
	// setting
	int		width;									// 地形宽度 x, 图形逻辑单位
	int		length;									// 地形长度 z
	int		height;									// 地形高度 y

	int		gridWidth;								// 宽度格子数, 地形网格分辨率
	int		gridLength;								// 长度格子数

	float	uv0Scale;								// 0 layer texcoord
	float   uv1Scale;								// 1 layer texcoord

	float   grid_x_scale;
	float   grid_z_scale;
	float   height_scale;
	float   min_height;
	float   max_height;

	// raw heightmap data
	uint8_t *					heightmap;              // lua 持有
	int     					rawBits;
	int 						rawSize;

	// vertex stream
	bgfx_vertex_decl_t * 		vdecl;				  	// terrain vertex declare
	uint8_t *			    	vertices;			  	// maybe from lua
	uint32_t					vertexCount;		  	//
	uint32_t *					indices;			  	// short if terrain size clamp 256
	uint32_t 					indexCount;			  	//

	// texture layers
	int     				    numLayers;			    // 混合纹理层数
	bgfx_texture_handle_t		t_baseTextures[4];		// mask textures, clamp to 4 layers
	bgfx_texture_handle_t		t_maskTextures[4];		// mask textures
	bgfx_texture_handle_t		t_baseTexture;			// paint texture   current process
	bgfx_texture_handle_t		t_maskTexture;			// mask texture

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


void update_terrain_mesh( struct TerrainData_t* terData );
void smooth_terrain_mesh( struct TerrainData_t* terData,int mode );
void update_terrain_normal_fast( struct TerrainData_t *terData );
void update_terrain_tangent( struct TerrainData_t* terData);
void terrain_update_vb( struct TerrainData_t *terData );
void terrain_updata_ib( struct TerrainData_t *terData );

//--------------------------------
// tested
/*
static int
lterrain_attrib(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) lua_touserdata(L, 1);
	const char *name = luaL_checkstring(L, 2);          // terData's  attrib  field
	#ifdef MY_DEBUG
	printf("access attrib = %s\n", name);
	#endif
	lua_pushnumber(L,terData->gridWidth);
	return 1;
}
*/

static int
lterrain_vb_close(lua_State *L)
{
	uint8_t *vertices = (uint8_t *) lua_touserdata(L, 1);
	// do nothing
#ifdef MY_DEBUG		
	printf("gc: vb %p destroy.\n",vertices);
#endif
	return 0;
}

static int
lterrain_ib_close(lua_State *L)
{
	uint32_t *indices = (uint32_t *) lua_touserdata(L, 1);
	// do nothing
#ifdef MY_DEBUG		
	printf("gc: ib %p destroy.\n",indices);
#endif 	
	return 0;
}


// alloc vertex buffer and return to lua
static int
lterrain_getVB(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	if(terData->vertices)
	   return luaL_error(L,"vertices already exist.");

	bgfx_vertex_decl_t *vd = terData->vdecl;
	uint32_t num 	= terData->gridWidth * terData->gridLength;

#ifdef MY_DEBUG	
	printf("c terrain: new alloc vertex = %d, strid =%d\n",num ,vd->stride);
#endif 	

	terData->vertices = (uint8_t*) lua_newuserdata(L, num * vd->stride );

	if (luaL_newmetatable(L, "TERRAIN_VB")) {
		lua_pushcfunction(L, lterrain_vb_close);        // register gc function
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);

	return 1;
}

static int
lterrain_getNumVerts(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	lua_pushnumber(L,terData->vertexCount);
	return 1;
}

static int
lterrain_getNumIndices(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	lua_pushnumber(L,terData->indexCount);
	return 1;
}
// alloc inddex and return to lua
static int
lterrain_getIB(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	if(terData->indices)
	   return luaL_error(L,"indices already exist.");

	uint32_t num 	= terData->gridWidth * terData->gridLength;
	terData->indices = (uint32_t*) lua_newuserdata(L, num * sizeof(uint32_t) * 6 );
#ifdef MY_DEBUG	
	printf("c terrain: new alloc vertex = %d, index =%d(%d)\n",num ,(uint32_t)(num*6),(uint32_t) (num * sizeof(uint32_t) * 6)  );
#endif 	

	if (luaL_newmetatable(L, "TERRAIN_IB")) {
		lua_pushcfunction(L, lterrain_ib_close);        // register gc function
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	return 1;
}


// action，brush filter，brush data and size
static
int lterrain_updateVB(lua_State *L)
{
	return 0;
}

static
int lterrain_updateIB(lua_State *L)
{
	return 0;
}



static
int lterrain_width(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	lua_pushnumber(L,terData->width);
	return 1;
}

static
int lterrain_height(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	lua_pushnumber(L,terData->height);
	return 1;
}

static
int lterrain_length(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	lua_pushnumber(L,terData->length);
	return 1;
}


// 释放 terrainData 地形数据,gc 自动回收，lua 层直接使用无效
static int
lterrain_close(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) lua_touserdata(L, 1);

#ifdef MY_DEBUG
		printf("\ngc: close terrain start.\n");
		if(terData->vertices)
			printf("gc: got vertices.\n");
		if(terData->indices )
			printf("gc: got indices.\n");
#endif

    // 都改成 userdata ，由 gc 自动回收

#ifdef MY_DEBUG
	printf("gc: close terrain end. \ngc: terrain alloc memory release.\n");
#endif

	return 0;
}


static inline int
getfield_toint(lua_State *L,int table,const char *key) {
	if( lua_getfield(L,table,key) != LUA_TNUMBER) {
		luaL_error(L,"Need %s as number",key );
	}
	int ivalue = luaL_checkinteger(L,-1);
	lua_pop(L,1);
	return ivalue;
}
static inline float
getfield_tofloat(lua_State *L,int table,const char *key) {
	if( lua_getfield(L,table,key)!=LUA_TNUMBER) {
		luaL_error(L,"Need %s as number",key);
	}
	float value = luaL_checknumber(L,-1);
	lua_pop(L,1);
	return value;
}


int terrain_check_level(lua_State *L,int index,struct TerrainData_t* terData)
{
	luaL_checktype(L,index,LUA_TTABLE);

	terData->gridWidth  = getfield_toint(L,index,"grid_width");
	terData->gridLength = getfield_toint(L,index,"grid_length");
	terData->rawBits = getfield_toint(L,index,"bits");
	terData->width  = getfield_toint(L,index,"width");   // maybe float is better
	terData->length = getfield_toint(L,index,"length");
	terData->height = getfield_toint(L,index,"height");

	terData->uv0Scale = getfield_tofloat(L,index,"uv0_scale");
	terData->uv1Scale = getfield_tofloat(L,index,"uv1_scale");

	terData->grid_x_scale  = terData->width *1.0f/ terData->gridWidth;
	terData->grid_z_scale  = terData->length*1.0f/ terData->gridLength;
	terData->height_scale  = terData->height*1.0f;
	if( terData->rawBits == 8)
		terData->height_scale = terData->height/ 256.0f;   	   
	else
		terData->height_scale = terData->height / 65536.0f;    

	terData->min_height = terData->max_height = 0;

	return 0;
}

//memset( terData, 0x0, sizeof(*terData) );
// todo: get parameters from lua
//    build terraindata from terrain level config
//       alloc vertex memorty
//           calc normal,uvs,smooth terrain height
//    build vb，ib
//  return  terraintata
//          terraindata support access function
// memset(terData,0x0,sizeof(*terData));

void terrain_default_init( struct TerrainData_t *terData)
{
	terData->gridWidth  = 513;
	terData->gridLength = 513;
	terData->rawBits = 8;
	terData->width  = 513;
	terData->length = 513;
	terData->height = 385;

	terData->uv0Scale = 80*0.625f;
	terData->uv1Scale = 1.0f;
}

// 根据传入的关卡配置数据，创建地形
// parameters：raw heightmap data, terrainLevel decalre, vertex decalre
// returan:    terrainData
static int
lterrain_create(lua_State *L)
{
	struct TerrainData_t* terData = (struct TerrainData_t*) lua_newuserdata(L, sizeof(TerrainData_t));
	if (luaL_newmetatable(L, "TERRAIN_BASE")) {
		// __index
		// __len
		// or other function
		// allocVB
		// allocIB
		// updateVB
		// updateIB
		// etc ...
		luaL_Reg l[] = {
			{"allocVB",lterrain_getVB},
			{"allocIB",lterrain_getIB},
			{"getVB",lterrain_getVB},
			{"getIB",lterrain_getIB},
			{"getNumVerts",lterrain_getNumVerts},
			{"getNumIndices",lterrain_getNumIndices},
			{"updateVB",lterrain_updateVB},
			{"updateIB",lterrain_updateIB},
			{"width",lterrain_width},
			{"length",lterrain_length},
			{"height",lterrain_height},
			{NULL,NULL},
		};
		luaL_newlib(L,l);
		lua_setfield(L, -2, "__index");
		lua_pushcfunction(L, lterrain_close);        // register gc function
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);                        // terrain Data inherit TERRAIN_BASE
												    // terrain data already on stack
	terData->vertices = NULL;
	terData->indices = NULL;
	terData->heightmap = NULL;
	terData->vdecl = NULL;

	// param1： heightmap
	size_t  size = 0;
	uint8_t *heightmap =  (uint8_t *)luaL_checklstring(L,1,&size);
	// todo： if size == 0 ....
    // save heightmap
	terData->heightmap = heightmap;
	terData->rawSize = size;

	// param3：vertex decl
    bgfx_vertex_decl_t *vd = (bgfx_vertex_decl_t *) lua_touserdata(L,3);
	if(vd == NULL)
	   return luaL_error(L,"Invalid vertex decl");

	// save vertex declare
    terData->vdecl = vd;

	// param3： terrainLevel
	terrain_check_level(L,2,terData);

	// todo:  get terrain data from terrainLevel

	// default init

	return 1;
}

// update terrain mesh from heightmap
// **顶点数据类型需要优化压缩
void update_terrain_mesh( struct TerrainData_t* terData )
{
	// float xspace  = terData->width *1.0f/ terData->gridWidth;
	// float zspace  = terData->length*1.0f/ terData->gridLength;
	// float yscale  = terData->height*1.0f;
	float xspace = terData->grid_x_scale;
	float zspace = terData->grid_z_scale;
	float yscale = terData->height_scale;

	float uv0scale = terData->uv0Scale;
	float uv1scale = terData->uv1Scale;

	float min_height = 99999.99f;
	float max_height = -99999.99f;

	struct vec3 { float x,y,z; };
	struct vec2 { float u,v; };

	if( is_little_endian() ) {  //tested 
#ifdef MY_DEBUG	
		printf("c terrain: little_endian supported.\n");
		word_btol( 0x1234 );
#endif 		
	}


	int nBytes = terData->rawBits / 8;
	uint32_t width = terData->gridWidth;
	uint32_t height = terData->gridLength;
	terData->vertexCount = 0;
#ifdef MY_DEBUG		
	printf("c terrain: %d,%d, begin create mesh\n",width,height);
#endif 	
	// printf("c terrain: width = %d,height=%d\n",width,height);
    // terrain 本身具备多个的 ATTRIB，用户可以选则全部或部分，实现一定的可定制

	for (uint32_t y = 0; y < height; y++)
	{
		for (uint32_t x = 0; x < width; x++)
		{   //pos
			if( terData->vdecl->attributes[ BGFX_ATTRIB_POSITION ] != UINT16_MAX ) {
				int stride = terData->vdecl->stride;
				int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];
				struct vec3* vert = (struct vec3*) &terData->vertices[ terData->vertexCount*stride + offset ];
				vert->x = (float) x*xspace;
				if( nBytes==1 )
					vert->y = (float) *(uint8_t*)&terData->heightmap[ ( ( ( /*height-1-*/ y) * width) + ( /*(width-1)-*/ x))*nBytes];  
				else if( nBytes==2 ) {
					vert->y = (float) *(uint16_t*)&terData->heightmap[ ( ( ( /*height-1-*/ y) * width) + (/* (width-1)-*/x) )*nBytes];  
					//vert->y = word_btol(vert->y);
				}
				vert->y *= yscale;
				vert->z  = (float) y*zspace;
				if( vert->y > max_height ) max_height = vert->y;
				if( vert->y < min_height ) min_height = vert->y;
			}
			//uv0
			if( terData->vdecl->attributes[ BGFX_ATTRIB_TEXCOORD0 ] != UINT16_MAX ) {
				int stride = terData->vdecl->stride;
				int offset = terData->vdecl->offset[ BGFX_ATTRIB_TEXCOORD0 ];
				struct vec2* vert = (struct vec2*) &terData->vertices[ terData->vertexCount*stride + offset ];

				vert->u = (x + 0.5f) / width * uv0scale;
				vert->v = (y + 0.5f) / height * -uv0scale;
			}
			//uv1 - for mask,color maps
		    if( terData->vdecl->attributes[ BGFX_ATTRIB_TEXCOORD1 ] != UINT16_MAX ) {
				int stride = terData->vdecl->stride;
				int offset = terData->vdecl->offset[ BGFX_ATTRIB_TEXCOORD1 ];
				struct vec2* vert = (struct vec2*) &terData->vertices[ terData->vertexCount*stride + offset ];

				vert->u = ( /*width-1-*/ x + 0.01f) / width * uv1scale;
				vert->v = (y + 0.01f) / height * -uv1scale;
		    }
			//normal
		  	if( terData->vdecl->attributes[BGFX_ATTRIB_NORMAL] != UINT16_MAX ) {
				int stride = terData->vdecl->stride;
				int offset = terData->vdecl->offset[ BGFX_ATTRIB_NORMAL ];
				struct vec3* vert = (struct vec3*) &terData->vertices[ terData->vertexCount*stride + offset ];

				vert->x = vert->y = vert->z = 0;
				vert->y = 1;
		    }
			//tangent
		  	if( terData->vdecl->attributes[BGFX_ATTRIB_TANGENT] != UINT16_MAX ) {
				int stride = terData->vdecl->stride;
				int offset = terData->vdecl->offset[ BGFX_ATTRIB_TANGENT ];
				struct vec3* vert = (struct vec3*) &terData->vertices[ terData->vertexCount*stride + offset ];

				vert->x = vert->y = vert->z = 0;
		    }
			terData->vertexCount++;
		}
	}
	terData->min_height = min_height;
	terData->max_height = max_height;
#ifdef MY_DEBUG	
	printf("c terrain: min_height(%.2f),max_height(%.2f)\n",min_height,max_height);
    printf("c terrain: %d,%d, begin create index\n",width,height);
#endif 	
	terData->indexCount = 0;
	for (uint16_t y = 0; y < (height-1 ); y++)
	{
		uint32_t y_offset = (y * width);
		for (uint16_t x = 0; x < (width-1 ); x++)
		{   // 可以继续优化
			terData->indices[terData->indexCount + 0] = (uint32_t) y_offset + x + 1;
			terData->indices[terData->indexCount + 1] = y_offset + x + width;
			terData->indices[terData->indexCount + 2] = y_offset + x;
			terData->indices[terData->indexCount + 3] = y_offset + x + width + 1;
			terData->indices[terData->indexCount + 4] = y_offset + x + width;
			terData->indices[terData->indexCount + 5] = y_offset + x + 1;
			terData->indexCount += 6;
		}
	}
#ifdef MY_DEBUG		
	printf("c terrain: generate vertex count =%d\n",terData->vertexCount);
	printf("c terrain: generate index count =%d\n",terData->indexCount);
#endif 	
}

bool in_terrain_bounds(struct TerrainData_t* terData,int h,int w)
{
	if (h<0 || h> terData->gridLength - 1 )
		return false;
	if (w<0 || w> terData->gridWidth - 1 )
		return false;
	return true;
}

// fake gassiah smooth
//  terrain context,pos x,y,smooth radius
float average( struct TerrainData_t *terData, const int i, const int  j,int r = 1 )
{
	float avg = 0.0f;
	float num = 0.0f;

	struct vec3 { float x,y,z; };

	int stride = terData->vdecl->stride;
	int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];

	uint8_t *vertices = terData->vertices;
	for (int m = i - r; m <= i + r; ++m)
	{
		for (int n = j - r; n <= j + r; ++n)
		{
			if( in_terrain_bounds( terData,m, n ) )
			{
				int vertCount = (m * terData->gridWidth) + n;
				struct vec3* vert = (struct vec3*) &vertices[ vertCount*stride + offset ];
				avg += vert->y;
				++num;
			}
		}
	}
	return avg / num;
}


enum SMOOTH_MODE {
	NONE,
	SPEC,
	QUAD,
	GASSIAN,
};

#define SMOOTH_DEFAULT SMOOTH_MODE::GASSIAN

// not weight
// default : r = 2
void smooth_terrain_gasslike( struct TerrainData_t *terData,int r)
{
	struct vec3 { float x, y, z; };
	struct vec3 sum;
	int i, j,index;

	int width   = terData->gridWidth;
	int height  = terData->gridLength;
	uint8_t *vertices = terData->vertices;

	int stride = terData->vdecl->stride;
	int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];
	sum.x = sum.y = sum.z = 0;
	for (j = 0; j< height; j++)
	{
		for (i = 0; i< width; i++)
		{
			//Gassiah like smooth without point weights
			sum.y = average(terData,j, i, r);
			index = (j * width) + i;
			struct vec3 *vert = (struct vec3*) &vertices[ index*stride + offset ];
			vert->y = (sum.y);
		}
	}
}
void smooth_terrain_quad( struct TerrainData_t *terData) {

}

void smooth_terrain_mesh( struct TerrainData_t *terData,int mode )
{
	if ( terData->rawBits != 8)
	  return ;
#ifdef MY_DEBUG		
	printf("c terrain: smooth terrain gradient.\n");
#endif 	
	if( mode == SMOOTH_DEFAULT ) {
		smooth_terrain_gasslike( terData,mode );
	}
	return;
/*
void smoothTerrain(enum SMOOTH_MODE mode = SMOOTH_MODE::DEFAULT )
{
	int width   = m_terrain.m_gridWidth;
	int height  = m_terrain.m_gridLength;
	int i, j,index;
	struct vec3 { float x, y, z; };
	struct vec3 sum;
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

// 如果是合并在bgfx 工程，静态引用有效，则交互会更方便些
static int
lterrain_update_mesh(lua_State *L)
{
	struct TerrainData_t* terData = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_BASE");
	uint8_t *vertices = (uint8_t *) luaL_checkudata(L, 2, "TERRAIN_VB");
	uint32_t *indices  = (uint32_t *) luaL_checkudata(L, 3, "TERRAIN_IB");

	if( terData->vertices == NULL || vertices == NULL)
	   return luaL_error(L,"must alloc vertices first.\n");
	if( terData->indices == NULL || indices == NULL)
	   return luaL_error(L,"must alloc indices first.\n");

	update_terrain_mesh(terData);
	smooth_terrain_mesh(terData,SMOOTH_DEFAULT);
	update_terrain_normal_fast( terData );
	return 0;
}

void update_terrain_normal_fast( struct TerrainData_t *terData)
{
#ifdef MY_DEBUG		
	printf("c terrain: fast calculate terrain normals.\n");
#endif 	
	// normal attrib does not exist
	if( terData->vdecl->attributes[ BGFX_ATTRIB_NORMAL ] == UINT16_MAX )
	 	return;

	struct vec3 { float x, y, z; };
	struct vec3 vert1, vert2, vert3;
	struct vec3 vec1, vec2,sum;
	int i, j,index,index1,index2,index3;

	int stride = terData->vdecl->stride;
	int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];
	int normal_offset = terData->vdecl->offset[ BGFX_ATTRIB_NORMAL ];

	int width  = terData->gridWidth;
	int height = terData->gridLength;
	struct vec3 *normals = new struct vec3[(height - 1)*(width - 1)];

	uint8_t *verts = terData->vertices;

	// Go through all the faces in the terrain mesh and calculate their normals.
	//  (v1) i +---+ (v2) i+1
	//         |  /
	//         | /
	//         |/
	//  (v3) i,j+1
	for (j = 0; j<( height - 1); j++)    // the last border not calc
	{
		for (i = 0; i<( width - 1); i++)
		{
			index1 = (j * width) + i;
			index2 = (j * width) + (i + 1);
			index3 = ((j + 1) * width) + i;

			vert1 = *(struct vec3*) &verts[ index1*stride + offset ];
			vert2 = *(struct vec3*) &verts[ index2*stride + offset ];
			vert3 = *(struct vec3*) &verts[ index3*stride + offset ];


			vec1.x = vert1.x - vert3.x;
			vec1.y = vert1.y - vert3.y;
			vec1.z = vert1.z - vert3.z;
			vec2.x = vert3.x - vert2.x;
			vec2.y = vert3.y - vert2.y;
			vec2.z = vert3.z - vert2.z;

			index = (j * (width - 1)) + i;

			// cross product ,get the un-normalized value
			normals[index].x = (vec1.y*vec2.z) - (vec1.z*vec2.y);
			normals[index].y = (vec1.z*vec2.x) - (vec1.x*vec2.z);
			normals[index].z = (vec1.x*vec2.y) - (vec1.y*vec2.x);
		}
	}

	// go through all the vertices and take an average of each face normal
	int   count = 0;
	float length = 0;
	for (j = 0; j< height; j++)
	{
		for (i = 0; i< width ; i++)
		{
			sum.x = 0.0f;
			sum.y = 0.0f;
			sum.z = 0.0f;

			count = 0;

			// Bottom left face.
			if (((i - 1) >= 0) && ((j - 1) >= 0))
			{
				index = ((j - 1) * ( width - 1)) + (i - 1);  //height

				sum.x += normals[index].x;
				sum.y += normals[index].y;
				sum.z += normals[index].z;
				count++;
			}

			// Bottom right face.
			if ((i < (width - 1)) && ((j - 1) >= 0))
			{
				index = ((j - 1) * ( width - 1)) + i;

				sum.x += normals[index].x;
				sum.y += normals[index].y;
				sum.z += normals[index].z;
				count++;
			}

			// Upper left face.
			if (((i - 1) >= 0) && (j < (height - 1)))
			{
				index = (j * ( width - 1)) + (i - 1);

				sum.x += normals[index].x;
				sum.y += normals[index].y;
				sum.z += normals[index].z;
				count++;
			}

			// Upper right face.
			if ((i < (width - 1)) && (j < (height - 1)))
			{
				index = (j * (width - 1)) + i;

				sum.x += normals[index].x;
				sum.y += normals[index].y;
				sum.z += normals[index].z;
				count++;
			}

			// average
			float invCount = 1.0f/count;
			sum.x = (sum.x *invCount );
			sum.y = (sum.y *invCount );
			sum.z = (sum.z *invCount );

			length = sqrtf((sum.x * sum.x) + (sum.y * sum.y) + (sum.z * sum.z) );

			// Get an index to the vertex location in the height map array.
			index = (j * width) + i;

			// 如果不独立保存，则会产生很大差异，所以需要一个临时 normals 数组保存中间值
			struct vec3* dst_normals = (struct vec3*) &verts[ index*stride + normal_offset ];
			length = 1.0f/length;
			dst_normals->x = (sum.x*length );
			dst_normals->y = (sum.y*length);
			dst_normals->z = (sum.z*length);
		}
	}

	delete[] normals;
}

bool ray_triangle(float start[3],float dir[3],float *ip,float v0[3],float v1[3],float v2[3])
{
	float edge1[3], edge2[3], normal[3];
	float e1[3], e2[3], e3[3], edgeNormal[3];
	float mag, dist, dn, sd, t, dtm, imp[3];
	float temp[3];

	edge1[0] = v1[0] - v0[0];
	edge1[1] = v1[1] - v0[1];
	edge1[2] = v1[2] - v0[2];

	edge2[0] = v2[0] - v0[0];
	edge2[1] = v2[1] - v0[1];
	edge2[2] = v2[2] - v0[2];

	normal[0] = (edge1[1] * edge2[2]) - (edge1[2] * edge2[1]);
	normal[1] = (edge1[2] * edge2[0]) - (edge1[0] * edge2[2]);
	normal[2] = (edge1[0] * edge2[1]) - (edge1[1] * edge2[0]);
	// normalize
	mag = (float)sqrt((normal[0] * normal[0]) + (normal[1] * normal[1]) + (normal[2] * normal[2]));
	normal[0] = normal[0] / mag;
	normal[1] = normal[1] / mag;
	normal[2] = normal[2] / mag;

	dist = ((-normal[0] * v0[0]) + (-normal[1] * v0[1]) + (-normal[2] * v0[2]));

	// project the ray's direction
	dn   = ((normal[0] * dir[0]) + (normal[1] * dir[1]) + (normal[2] * dir[2]));
	if(fabs(dn) < 0.0001f) 	{
		return false;
	}
	// start point distance to the plane
	sd  = -1.0f * (((normal[0] * start[0]) + (normal[1] * start[1]) + (normal[2] * start[2])) + dist);
	t = sd / dn;
	// get impact point
	imp[0] = start[0] + (dir[0] * t);
	imp[1] = start[1] + (dir[1] * t);
	imp[2] = start[2] + (dir[2] * t);

	e1[0] = v1[0] - v0[0];
	e1[1] = v1[1] - v0[1];
	e1[2] = v1[2] - v0[2];

	e2[0] = v2[0] - v1[0];
	e2[1] = v2[1] - v1[1];
	e2[2] = v2[2] - v1[2];

	e3[0] = v0[0] - v2[0];
	e3[1] = v0[1] - v2[1];
	e3[2] = v0[2] - v2[2];


	edgeNormal[0] = (e1[1] * normal[2]) - (e1[2] * normal[1]);
	edgeNormal[1] = (e1[2] * normal[0]) - (e1[0] * normal[2]);
	edgeNormal[2] = (e1[0] * normal[1]) - (e1[1] * normal[0]);

	temp[0] = imp[0] - v0[0];
	temp[1] = imp[1] - v0[1];
	temp[2] = imp[2] - v0[2];
	// project temp vector
	dtm = ((edgeNormal[0] * temp[0]) + (edgeNormal[1] * temp[1]) + (edgeNormal[2] * temp[2]));
	if(dtm > 0.001f) 	{
		return false;
	}


	edgeNormal[0] = (e2[1] * normal[2]) - (e2[2] * normal[1]);
	edgeNormal[1] = (e2[2] * normal[0]) - (e2[0] * normal[2]);
	edgeNormal[2] = (e2[0] * normal[1]) - (e2[1] * normal[0]);

	temp[0] = imp[0] - v1[0];
	temp[1] = imp[1] - v1[1];
	temp[2] = imp[2] - v1[2];
	dtm = ((edgeNormal[0] * temp[0]) + (edgeNormal[1] * temp[1]) + (edgeNormal[2] * temp[2]));
	if (dtm > 0.001f) {
		return false;
	}


	edgeNormal[0] = (e3[1] * normal[2]) - (e3[2] * normal[1]);
	edgeNormal[1] = (e3[2] * normal[0]) - (e3[0] * normal[2]);
	edgeNormal[2] = (e3[0] * normal[1]) - (e3[1] * normal[0]);

	temp[0] = imp[0] - v2[0];
	temp[1] = imp[1] - v2[1];
	temp[2] = imp[2] - v2[2];
	dtm = ((edgeNormal[0] * temp[0]) + (edgeNormal[1] * temp[1]) + (edgeNormal[2] * temp[2]));
	if(dtm > 0.001f) 	{
		return false;
	}

	ip[0] = imp[0];
	ip[1] = imp[1];
	ip[2] = imp[2];
	return true;
}

// project x,z on triange, return the height of this position
// further should be add ray cast parameters
bool check_height_of_triangle(float x,float z,float *height,float v0[3],float v1[3],float v2[3])
{
	float start[3],dir[3],ip[3];
		// ray start point
	start[0] = x;
	start[1] = 1000.0f;
	start[2] = z;

	// ray direction
	dir[0] = 0.0f;
	dir[1] = -1000.0f;
	dir[2] = 0.0f;

	if(ray_triangle(start,dir,ip,v0,v1,v2)) {
		*height = ip[1];
		return true;
	}
	return false;
}

// get terrain height at x,z position
bool terrain_get_height(struct TerrainData_t* terData,float x,float z,float *height)
{
	int stride = terData->vdecl->stride;
	int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];
	uint8_t* verts = terData->vertices;

	int	   width = terData->gridWidth;
	float  x_unit_grid_space = (1.0f*terData->width/terData->gridWidth);
	float  z_unit_grid_space = (1.0f*terData->length/terData->gridLength);

	int    xindex = x/x_unit_grid_space;
	int    zindex = z/z_unit_grid_space;

	int    left   = xindex - 1;
	int    right  = xindex + 1;
	int    top    = zindex - 1;
	int    bottom = zindex + 1;

	int    index1, index2, index3,index4;
	float  *vert1, *vert2, *vert3,*vert4;

	for(int j = top; j<bottom; j++) {
		for(int i = left; i<right; i++) {
			if( !in_terrain_bounds(terData, j,i) || !in_terrain_bounds(terData,j+1,i+1) )
			   continue;
			// 1 ----- 2
			//  |   / |
            //  |  /  |
 			//  | /   |
			// 3 ----- 4
			index1 = (j * width) + i;
			index2 = (j * width) + (i + 1);
			index3 = ((j + 1) * width) + i;
			index4 = ((j + 1) * width) + (i+1);

			vert1 = (float*) &verts[ index1*stride + offset ];
			vert2 = (float*) &verts[ index2*stride + offset ];
			vert3 = (float*) &verts[ index3*stride + offset ];
			vert4 = (float*) &verts[ index4*stride + offset ];

			if( check_height_of_triangle(x,z,height,vert1,vert2,vert3) )
				return true;

			if( check_height_of_triangle(x,z,height,vert2,vert4,vert3) )
				return true;
		}
	}
	if(*height)
		*height = 0.0f;
	return false;
}

float terrain_get_raw_height(struct TerrainData_t* terData,int x,int z)
{
	int stride = terData->vdecl->stride;
	int offset = terData->vdecl->offset[ BGFX_ATTRIB_POSITION ];
	uint8_t* verts = terData->vertices;

	int	   width = terData->gridWidth;

	if( !in_terrain_bounds(terData, z,x) )
	   return -99999.99f;


	// 1 ----- 2
	//  |   / |
	//  |  /  |
	//  | /   |
	// 3 ----- 4
	struct vec3 { float x, y, z; };
	int   index = (z * width) + x;
	struct vec3 *vert = (struct vec3*) &verts[ index*stride + offset ];
	return vert->y;
}


static int 
lterrain_get_height_scale( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");	
	lua_pushnumber(L,terData->height_scale );
	return 1;
}
static int 
lterrain_get_width_scale( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");	
	lua_pushnumber(L,terData->grid_x_scale );
	return 1;
}
static int 
lterrain_get_length_scale( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");	
	lua_pushnumber(L,terData->grid_z_scale );
	return 1;
}
static int 
lterrain_get_min_height( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");	
	lua_pushnumber(L,terData->min_height );
	return 1;
}
static int 
lterrain_get_max_height( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");	
	lua_pushnumber(L,terData->max_height );
	return 1;
}

static int
lterrain_get_height( lua_State *L) {
    // terrain context data, x, z
	// push bool result
	// push height value
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	float x = luaL_checknumber(L,2);
	float y = luaL_checknumber(L,3);

	float height = 0.0f;
	bool  hit = terrain_get_height(terData,x,y,&height);

	lua_pushboolean(L,hit);
	lua_pushnumber(L,height);

	return 2;
}

static int 
lterrain_get_raw_height( lua_State *L) {
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	int x = luaL_checkinteger(L,2);
	int y = luaL_checkinteger(L,3);

	float height = 0.f;
	height = terrain_get_raw_height(terData,x,y);
	lua_pushnumber(L,height);

#ifdef MY_DEBUG_OUT
	float min_height = 99999.f;
	float max_height = -99999.f;
	FILE *out = fopen("ter_raw_height.txt","w+");
	if(out) {
		for(int y =0 ;y< terData->gridLength; y++) {
			for(int x =0 ; x< terData->gridWidth; x++) {
				float hi = terrain_get_raw_height(terData,x,y);
				fprintf(out,"%06.2f ",hi);
				if( hi <min_height) min_height = hi;
				if( hi >max_height) max_height = hi;
			}
			fprintf(out,"\r");
		}
		fprintf(out,"max = %06.2f ",max_height);
		fprintf(out,"min = %06.2f ",min_height);
		fclose(out);
	}
#endif 	

	return 1;
}


static int
lterrain_update_normals( lua_State *L )
{
	struct TerrainData_t* terData = (struct TerrainData_t*) luaL_checkudata(L, 1, "TERRAIN_BASE");
	uint8_t *vertices = (uint8_t *) luaL_checkudata(L, 2, "TERRAIN_VB");
	if( terData->vertices == NULL || vertices ==NULL)
	   return luaL_error(L,"must alloc vertices first.\n");

	update_terrain_normal_fast( terData );

	return 0;
}

void update_terrain_tangent( struct TerrainData_t* terData)
{
	// todo:
}

void terrain_update_vb( struct TerrainData_t *terData)
{
	//const bgfx_memory_t* mem = NULL;
	// todo:
}

// 几何形体改变，单独修改 IB 的需求
void terrain_updata_ib( struct TerrainData_t *terData)
{
	//const bgfx_memory_t* mem = NULL;
	// todo:
}


// update terrain by view point
// params: TerrainData_t * data
//         vertex buffer
//         index buffer
//         eyeView,eyeDir
static int
lterrain_update_view(lua_State *L)
{
	// todo: maybe ...
	return 1;
}

// 不在 c 做渲染，只是存根测试函数
static int
lterrain_render(lua_State *L)
{
	struct TerrainData_t *terData = (struct TerrainData_t*) luaL_checkudata(L,1,"TERRAIN_BASE");
	int memory_size = terData->vertexCount * terData->vdecl->stride;
#ifdef MY_DEBUG		
	printf("grid width = %d,grid length = %d, vertex strid = %d.\n",terData->gridWidth,
																	terData->gridLength,
																	terData->vdecl->stride);
	printf("width = %d,lenght=%d,height=%d\n",terData->width,terData->length,terData->height);
	printf("memory size = %d m\n",int(memory_size/1024/1024.0f));
#endif 	
	return 0;
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


// export ...

// create terrain ctx
// alloc vb memory
// alloc ib memory
// update_mesh (calc mesh ,normal; smooth gradient; further tangent etc)
LUAMOD_API int
luaopen_lterrain(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", lterrain_create},
		{ "create", lterrain_create},
		{ "update_mesh",lterrain_update_mesh},
		{ "update_normals",lterrain_update_normals},
		{ "calculate_normals",lterrain_update_normals},
		{ "get_raw_height",lterrain_get_raw_height},
		{ "get_height",lterrain_get_height},
		{ "get_min_height",lterrain_get_min_height},
		{ "get_max_height",lterrain_get_max_height},
		{ "get_height_scale",lterrain_get_height_scale},
		{ "get_width_scale",lterrain_get_width_scale},
		{ "get_length_scale",lterrain_get_length_scale},
		{ "update_view",lterrain_update_view},
		{ "update",lterrain_update_view},
		{ "render",lterrain_render},
		{ "close", lterrain_close},

		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	//luaL_newlibtable(L, l);
	//luaL_setfuncs(L, l, 1);
	return 1;
}

#ifdef __cplusplus
}
#endif



