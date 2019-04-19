#define LUA_LIB
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <cassert>

#include "btBulletDynamicsCommon.h"
#include "Collision/CollisionSdkC_Api.h"
#include "Collision/Internal/BulletDebugDraw.h"
struct bullet_node {
	plCollisionSdkHandle sdk;
};

struct world_node {
	plCollisionWorldHandle world;
	plCollisionSdkHandle sdk;
};

#ifdef _DEBUG
#define check_world(_WORLD) assert((_WORLD)->sdk != nullptr); assert((_WORLD)->world != nullptr)
#else
#define check_world(_WORLD)	 
#endif // _DEBUG




static inline world_node*
to_world(lua_State *L, int idx = 1) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	auto world = (world_node*)lua_touserdata(L, idx);
	check_world(world);

	return world;
}

template<typename T>
static inline void
get_arg_vec(lua_State *L, int index, int num, T &obj) {	
	for (auto ii = 0; ii < num; ++ii) {
		const auto idx = ii + index;
		luaL_checktype(L, idx, LUA_TNUMBER);
		obj[ii] = (plReal)lua_tonumber(L, idx);
	}	
}

struct heightmapdata {
	const uint8_t *data;
	uint32_t sizebytes;
	uint8_t elembits;
};


static inline void
fetch_heightmap_data(lua_State *L, int index, heightmapdata &hm) {
	lua_getfield(L, index, "heightmapdata");
	{
		lua_getfield(L, -1, "data");
		hm.data = (const uint8_t*)lua_touserdata(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, -1, "sizebytes");
		hm.sizebytes = (uint32_t)lua_tointeger(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, -1, "bits");
		hm.elembits = (uint8_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
}

static inline PHY_ScalarType
get_phys_datatype(uint8_t elembits) {
	const PHY_ScalarType phytypes[] = {
		PHY_ScalarType(-1), PHY_ScalarType::PHY_UCHAR, PHY_ScalarType::PHY_SHORT,
		PHY_ScalarType(-1), PHY_ScalarType::PHY_FLOAT,
	};

	const auto bytenum = elembits / 8;
	assert(bytenum < sizeof(phytypes) / sizeof(phytypes[0]));

	return phytypes[bytenum];
}


plCollisionShapeHandle 
create_terrain_shape(lua_State *L, world_node* world, int index) {
	lua_getfield(L, index, "width");
	const uint32_t  width = (uint32_t)lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "height");	
	const uint32_t  height = (uint32_t)lua_tointeger(L, -1);
	lua_pop(L, 1);

	heightmapdata hm = { 0 };
	fetch_heightmap_data(L, index, hm);
	if (width * height < hm.sizebytes / (hm.elembits / 8)) {
		luaL_error(L, "terrain width=%d, height=%d, exceed heightmap elem numbers: %d", width, height, hm.sizebytes / (hm.elembits / 8));
	}

	lua_getfield(L, index, "heightmap_scale");
	const plReal heightmap_scale = (plReal) lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "min_height");
	const plReal minHeight = (plReal)lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "max_height");
	const plReal maxHeight = (plReal)lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "up_axis");
	const int upAxis = (int)lua_tointeger(L, 10);
	if (upAxis < 0 || upAxis > 2) {
		luaL_error(L, "invalid axis type : %d", upAxis);
	}
	lua_pop(L, 1);

	lua_getfield(L, index, "flip_quad_edges");
	const bool flip_quad_edges = lua_toboolean(L, -1);
	lua_pop(L, 1);

	//printf("\nbullet: w = %d,h = %d,terData=%p, gridScale = %.2f, heightScale=%.2f, min=%.2f,max=%.2f, axis=%d, type ='%s',quad = %d\n",
	//	width,height,terData,gridScale,heightScale,minHeight,maxHeight,upAxis,phyType,flip_quad_edges);
	//printf("bullet: image data = %p, size = %d\n",terData,(int) dataLen);
	
	return plCreateTerrainShape(world->sdk,world->world,
						width, height, 
						hm.data, get_phys_datatype(hm.elembits),
						heightmap_scale, minHeight, maxHeight, 
						upAxis,						
						flip_quad_edges);
}

static inline void
get_vec(lua_State *L, int index, int count, plReal *v) {
	for (int ii = 0; ii < count; ++ii) {
		lua_geti(L, index, ii + 1);
		v[ii] = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}

static int
lnew_shape(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);

	plCollisionShapeHandle shape = nullptr;
	if (strcmp(type, "sphere") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		lua_getfield(L, 3, "radius");
		const plReal radius = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);
		shape = plCreateSphereShape(world->sdk, world->world, radius);

	} else if (strcmp(type, "box") == 0) {		
		luaL_checktype(L, 3, LUA_TTABLE);
		plVector3 size;
		lua_getfield(L, 3, "size");
		get_vec(L, -1, 3, size);
		lua_pop(L, 1);
		shape = plCreateBoxShape(world->sdk, world->world, size);
	} else if (strcmp(type, "plane") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		plReal plane[4];
		lua_getfield(L, 3, "normal");
		get_vec(L, -1, 4, plane);
		lua_pop(L, 1);
		lua_getfield(L, 3, "distance");
		plane[3] = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);
		shape = plCreatePlaneShape(world->sdk, world->world, plane[0], plane[1], plane[2], plane[3]);
	} else if (strcmp(type, "cylinder") == 0 || strcmp(type, "capsule") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		lua_getfield(L, 3, "radius");		
		const plReal radius = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, 3, "height");
		const plReal height = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, 3, "axis");
		const int axis = (int)luaL_optinteger(L, -1, 1);
		lua_pop(L, 1);

		if(axis<0 || axis>2) {
			luaL_error(L, "invalid axis type : %d", axis);
		}

		auto op = strcmp(type, "capsule") == 0 ? plCreateCapsuleShape : plCreateCylinderShape;
		shape = op(world->sdk,world->world,radius,height,axis);

	} else if (strcmp(type, "compound") == 0) {
		shape = plCreateCompoundShape(world->sdk, world->world);
	} else if (strcmp(type,"terrain") == 0 ) {
		luaL_checktype(L, 3, LUA_TTABLE);
		shape = create_terrain_shape(L, world, 3);
	}

	assert(shape);
	lua_pushlightuserdata(L, shape);

	return 1;
}

template<typename T>
void extract_vec(lua_State *L, int index, int num, T& obj) {
	for (auto ii = 0; ii < num; ++ii) {    //error: 3-num
		lua_geti(L, index, ii + 1);
		obj[ii] = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
};

template<typename T>
void push_vec(lua_State *L, const char* name, int num, const T &obj) {
	lua_createtable(L, num, 0);
	for (auto ii = 0; ii < num; ++ii) {
		lua_pushnumber(L, obj[ii]);
		lua_seti(L, -2, ii + 1);
	}
	lua_setfield(L, -2, name);
};

static int 
lcreate_debugDrawer(lua_State *L) {
	auto world = to_world(L);
	plCreateDebugDrawer(world->sdk, world->world);
	return 0;
}

static int 
ldelete_debugDrawer(lua_State *L) {
	auto world = to_world(L);
	plDeleteDebugDrawer(world->sdk, world->world);
	return 0;
}


static int
lnew_collision_obj(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	plCollisionShapeHandle shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TNUMBER);
	const int useridx = (int)lua_tointeger(L, 3);

	luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
	plReal* pos = (plReal*)lua_touserdata(L, 4);
	
	luaL_checktype(L, 5, LUA_TLIGHTUSERDATA);
	plReal *quat = (plReal*)lua_touserdata(L, 5);

	void *userdata = lua_isnoneornil(L, 6) ? nullptr : lua_touserdata(L, 6);

	auto collision_obj = plCreateCollisionObject(world->sdk, world->world, userdata, useridx, shape, pos, quat);
	lua_pushlightuserdata(L, collision_obj);
	return 1;
}

static int
ldel_collision_obj(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	plCollisionObjectHandle obj = (plCollisionObjectHandle)lua_touserdata(L, 2);
	plDeleteCollisionObject(world->sdk, world->world, obj);

	return 0;
}

static int
ladd_collision_obj(lua_State *L) {
	auto world = to_world(L);

	plCollisionObjectHandle obj = (plCollisionObjectHandle)lua_touserdata(L, 2);
	plAddCollisionObject(world->sdk, world->world, obj);
	return 0;
}

static int
lremove_collision_obj(lua_State *L) {
	auto world = to_world(L);

	plCollisionObjectHandle obj = (plCollisionObjectHandle) lua_touserdata(L,2);
	plRemoveCollisionObject(world->sdk,world->world,obj);
	return 0;
}

static int 
lget_debug_info(lua_State *L) {
	auto world = to_world(L);
	btCollisionWorld* btWorld =(btCollisionWorld*) world->world;
	MyDebugDrawer *debugDrawer = (MyDebugDrawer*) btWorld->getDebugDrawer(); 
	if(debugDrawer == nullptr ) {
	   return 0;
	}

	int idx_size =0, vert_size =0;
	float *verts = debugDrawer->getVertices(vert_size);
	unsigned int *indices = debugDrawer->getIndices(idx_size);
	if( idx_size<=0 || vert_size<=0 ) {
		return 0;
	}
	lua_pushlstring(L,(const char *) verts, vert_size*sizeof(struct MyDebugVec) );
	lua_pushlstring(L,(const char *) indices, idx_size*sizeof(unsigned int) );
	lua_pushinteger(L,vert_size);
	lua_pushinteger(L,idx_size);
	return 4;
}

static int 
ldebug_draw_world(lua_State *L) {
	auto world = to_world(L);
	btCollisionWorld* collisionWorld =(btCollisionWorld*) world->world;
	//MyDebugDrawer* debugDrawer = (MyDebugDrawer*)collisionWorld->getDebugDrawer();
	collisionWorld->debugDrawWorld();
	return 0;
}

// clear debugDrawer data
static int 
ldebug_clear_world(lua_State*L) {
	auto world = to_world(L);
	btCollisionWorld* btWorld =(btCollisionWorld*) world->world;
	MyDebugDrawer* debugDrawer = (MyDebugDrawer*)btWorld->getDebugDrawer();
	if( debugDrawer) 
		debugDrawer->reset();
	return 0;
}

static int
ladd_to_compound(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto compound = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	auto child = (plCollisionShapeHandle)lua_touserdata(L, 3);


	luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
	plReal *pos = (plReal *)lua_touserdata(L, 4);	

	luaL_checktype(L, 5, LUA_TLIGHTUSERDATA);
	plReal *quat = (plReal *)lua_touserdata(L, 5);	

	plAddChildShape(world->sdk, world->world, compound, child, pos, quat);
	return 0;
}

static int 
lupdate_object_shape(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L,2,LUA_TLIGHTUSERDATA);
	auto object = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal *scale = (plReal *)lua_touserdata(L, 3);

	auto shape = plGetCollisionObjectShape(world->sdk, world->world, object);
	if (shape == nullptr) {
		luaL_error(L, "collision object do not have shape");
	}
	plSetShapeScale(world->sdk,world->world, object, shape, scale);
	return 0;
}

static int
lset_shape_scale(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal *scale = (plReal*)lua_touserdata(L, 3);

	plSetShapeScaleEx(world->sdk, world->world, shape, scale);
	return 0;
}

static int
ldel_shape(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);

	world_node *world = (world_node*)lua_touserdata(L, 1);
	check_world(world);
	plCollisionShapeHandle shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	plDeleteShape(world->sdk, world->world, shape);

	return 0;
}

static int
ldel_bullet_world(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	world_node* world = (world_node*)lua_touserdata(L, 1);
	//assert(world->sdk != nullptr);
	if (world->sdk && world->world) {
		plDeleteCollisionWorld(world->sdk, world->world);
	}

	//printf("gc delete bullet_world sdk(%p),world(%p)\n",world->sdk,world->world);

	world->sdk = nullptr;
	world->world = nullptr;

	return 0;
}

// clear all objects in bullet world 
static int 
lreset_bullet_world(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	world_node* world = (world_node*)lua_touserdata(L, 1);
	//assert(world->sdk != nullptr);
	if (world->sdk && world->world) {
		plResetCollisionWorld(world->sdk, world->world);
	}
	return 0;
}

// object parameters need open for lua
static int
lnew_bullet_world(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bullet_node* bullet = (bullet_node*)lua_touserdata(L, 1);

	world_node *world = (world_node*)lua_newuserdata(L, sizeof(world_node));	
	luaL_setmetatable(L, "BULLET_WORLD_NODE");

	world->sdk = bullet->sdk;

	const int maxShape = 10000;
	const int maxObj = 10000;
	world->world = plCreateCollisionWorld(bullet->sdk, maxShape, maxObj, maxShape * maxObj);

	printf("create bullet_world sdk(%p),world(%p)\n",world->sdk,world->world);

	return 1;
}

static int
ldel_bullet(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bullet_node *bullet = (bullet_node*)lua_touserdata(L, 1);

	if (bullet->sdk) {
		plDeleteCollisionSdk(bullet->sdk);
	}
	return 0;
}

static int
lnew_bullet(lua_State *L) {	
	const int sdkVersion = (int)luaL_optinteger(L, 1, 2);
	assert(2 <= sdkVersion && sdkVersion <= 3);

	bullet_node *bullet = (bullet_node*)lua_newuserdata(L, sizeof(bullet_node));
	luaL_setmetatable(L, "BULLET_NODE");

	bullet->sdk = sdkVersion == 2 ? plCreateBullet2CollisionSdk() : plCreateRealTimeBullet3CollisionSdk();

	return 1;	// return bullet_node userdata
}

static void
register_bullet_node(lua_State *L) {
	luaL_newmetatable(L, "BULLET_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	// BULLET_NODE.__index = BULLET_NODE

	luaL_Reg l[] = {
		"new_world", lnew_bullet_world,
		"__gc", ldel_bullet,
		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}


//the follow functions lworld_collide_usb and lworld_collide,must be use in single thread,
//cause the bullet interface use global as temporal status
#include <functional>
static int
lworld_collide_ucb(lua_State *L) {
	auto world = to_world(L);
	luaL_checktype(L, 2, LUA_TFUNCTION);

	struct CallBackData {
		lua_State *L;
	};

    // no end constraint ,no safe 
	auto near_callback = [] (plCollisionSdkHandle sdkHandle, plCollisionWorldHandle worldHandle, void* userData,
			plCollisionObjectHandle objA, plCollisionObjectHandle objB) -> void
	{
		CallBackData *cb_data = reinterpret_cast<CallBackData*>(userData);
		lua_State *L = cb_data->L;

		assert(lua_type(L, -1) == LUA_TFUNCTION);	
		lua_pushvalue(L, -1);	// keep this lua function

		lua_pushlightuserdata(L, objA);
		lua_pushlightuserdata(L, objB);
		lua_pushlightuserdata(L, userData);
		const int numarg = 3;
		lua_call(L, numarg, 0);

		assert(lua_type(L, -1) == LUA_TFUNCTION);
	};

	CallBackData cb_data = { L, };
	if (lua_type(L, 3) != LUA_TTABLE) {
		assert("need to implement");
	}
	
	plWorldCollide(world->sdk, world->world, near_callback, &cb_data);
	return 0;
}

#define  POINT_CAPACITY  100

static int
lworld_collide(lua_State *L) {
	auto world = to_world(L);

	struct CallBackData {
		lua_State *L;
		int totalPoints;
		int numCallbacks;
		int maxPoints;
		lwContactPoint ctPoints[ POINT_CAPACITY ];
	};


	// 1. with end constraint  2. reduced the difficulty for lua user 
	auto near_callback = [] (plCollisionSdkHandle sdkHandle, plCollisionWorldHandle worldHandle, void* userData,
			plCollisionObjectHandle objA, plCollisionObjectHandle objB) -> void
	{
		CallBackData *cb_data = reinterpret_cast<CallBackData*>(userData);

		cb_data->numCallbacks ++;
		int remainingCapacity = cb_data->maxPoints - cb_data->totalPoints;
		if(remainingCapacity> 0) {		
		  	lwContactPoint *pointPtr = &cb_data->ctPoints[ cb_data->totalPoints ];
		  	int numPoints = plCollide(sdkHandle,worldHandle,objA,objB,pointPtr,remainingCapacity);
		  	cb_data->totalPoints += numPoints;
		  	//printf("find collide point =  %d ,cb = %d\n",numPoints,cb_data->numCallbacks );
		}		
	};

	CallBackData cb_data = { L, 0, 0, POINT_CAPACITY };  // init call status 
	
	plWorldCollide(world->sdk, world->world, near_callback, &cb_data); //do collide

	if( cb_data.totalPoints <= 0) {
		return 0;
	}

	int numContact = cb_data.totalPoints;
	lwContactPoint *points = &cb_data.ctPoints[0];
	lua_createtable(L, numContact, 0);
	for (auto ii = 0; ii < numContact; ++ii) {
		lua_createtable(L, 0, 4);

		const auto &point = points[ii];

		push_vec(L, "ptA_in_WS", 3, point.m_ptOnAWorld);
		push_vec(L, "ptB_in_WS", 3, point.m_ptOnBWorld);
		push_vec(L, "normalB_in_WS", 3, point.m_normalOnB);

		lua_pushnumber(L, point.m_distance);
		lua_setfield(L, -2, "distance");

		lua_seti(L, -2, ii + 1);
	}

	return 1;
}

static int
lcollide_objects(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	//luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);

	auto objA = (plCollisionObjectHandle)lua_touserdata(L, 2);
	auto objB = (plCollisionObjectHandle)lua_touserdata(L, 3);

	//auto userdata = lua_touserdata(L, 4);

	lwContactPoint points[16];
	auto numContract = plCollide(world->sdk, world->world, objA, objB, points, sizeof(points) / sizeof(points[0]));

	if (numContract == 0) {
		return 0;
	}

	lua_createtable(L, numContract, 0);
	for (auto ii = 0; ii < numContract; ++ii) {
		lua_createtable(L, 0, 4);

		const auto &point = points[ii];

		push_vec(L, "ptA_in_WS", 3, point.m_ptOnAWorld);
		push_vec(L, "ptB_in_WS", 3, point.m_ptOnBWorld);
		push_vec(L, "normalB_in_WS", 3, point.m_normalOnB);

		lua_pushnumber(L, point.m_distance);
		lua_setfield(L, -2, "distance");

		lua_seti(L, -2, ii + 1);
	}

	return 1;
}

// lua interaction cost, maybe optimize future
// when lua rays >2500 , c rays could reach 12000
static int
lraycast(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	plReal* from = (plReal*)lua_touserdata(L, 2);
	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal* to = (plReal*)lua_touserdata(L, 3);

	ClosestRayResult result;
	const bool hitted = plRaycast(world->sdk, world->world, from, to, result);

	lua_pushboolean(L, hitted);
	if (!hitted) {
		return 1;
	}
    // if get table from lua,maybe speedup ,avoid gc flick 
	lua_createtable(L, 0, 7);

	lua_pushinteger(L, result.m_hitObjId);
	lua_setfield(L, -2, "useridx");

	lua_pushnumber(L, result.m_hitFraction);
	lua_setfield(L, -2, "hit_fraction");

	push_vec(L, "hit_pt_in_WS", 3, result.m_hitPointWorld);
	push_vec(L, "hit_normal_in_WS", 3, result.m_hitNormalWorld);

	lua_pushinteger(L, result.m_filterGroup);
	lua_setfield(L, -2, "filter_group");

	lua_pushinteger(L, result.m_filterMask);
	lua_setfield(L, -2, "filter_mask");

	lua_pushinteger(L, result.m_flags);
	lua_setfield(L, -2, "flags");
	
	return 2;
}

static int
ldrawline(lua_State *L) {
	auto world = to_world(L);

	plVector3 from, to;
	extract_vec(L, 2, 3, from);
	extract_vec(L, 3, 3, to);

	uint32_t color = (int)luaL_optinteger(L,4,0xffffffff);

	plDrawline(world->sdk, world->world, from, to, color );

	return 0;
}

static int
lset_obj_trans(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal *pos = (plReal *)lua_touserdata(L, 3);

	luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
	plReal* quat = (plReal *)lua_touserdata(L, 4);	

	plSetCollisionObjectTransform(world->sdk, world->world, obj, pos, quat);
	return 0;
}


static int
lset_obj_pos(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal *pos = (plReal *)lua_touserdata(L, 3);
	
	plSetCollisionObjectPosition(world->sdk, world->world, obj, pos);

	return 0;
}

static int
lset_obj_rot(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	plReal *quat = (plReal *)lua_touserdata(L, 3);	

	plSetCollisionObjectRotation(world->sdk, world->world, obj, quat);

	return 0;
}


//-----------------------------------------------------------------------------------------
//      debugDrawer
static void
register_bullet_world_node(lua_State *L) {
	luaL_newmetatable(L, "BULLET_WORLD_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	 // BULLET_NODE.__index = BULLET_NODE

	luaL_Reg l[] = {
		"new_shape",			lnew_shape,
		"del_shape",			ldel_shape,
		"update_object_shape",	lupdate_object_shape,
		"set_shape_scale",		lset_shape_scale,
		"new_obj",				lnew_collision_obj,
		"del_obj",				ldel_collision_obj,
		"add_obj",				ladd_collision_obj,
		"remove_obj",			lremove_collision_obj,
		"set_obj_transform",	lset_obj_trans,
		"set_obj_position",		lset_obj_pos,
		"set_obj_rotation",		lset_obj_rot,		
		"add_to_compound",		ladd_to_compound,
	
		"world_collide",		lworld_collide,
		"world_collide_ucb",	lworld_collide_ucb,
		"collide_objects",		lcollide_objects,
		"raycast",				lraycast,
		
		"drawline",				ldrawline,
		"get_debug_info",		lget_debug_info,
		"create_debug_drawer",	lcreate_debugDrawer,
		"delete_debug_drawer",	ldelete_debugDrawer,
		"debug_begin_draw",		ldebug_draw_world,
		"debug_end_draw",		ldebug_clear_world,

		"reset_world",			lreset_bullet_world,
		"del_bullet_world",		ldel_bullet_world,    		

		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
	LUAMOD_API int
	luaopen_bullet(lua_State *L) {
		register_bullet_node(L);
		register_bullet_world_node(L);

		luaL_Reg l[] = {
			{ "new", lnew_bullet},
			nullptr, nullptr,
		};

		luaL_newlib(L, l);

		return 1;

	}
}