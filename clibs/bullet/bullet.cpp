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

//static plCollisionShapeHandle
//plCreateCylinderShape() {
//
//}

static int
lnew_shape(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);

	plCollisionShapeHandle shape = nullptr;
	if (strcmp(type, "sphere") == 0) {
		luaL_checktype(L, 3, LUA_TNUMBER);
		btScalar radius = (btScalar)lua_tonumber(L, 3);   //error: 2-3 
		shape = plCreateSphereShape(world->sdk, world->world, radius);

	} else if (strcmp(type, "cube") == 0) {		
		plVector3 size;		
		get_arg_vec(L, 3, 3, size);
		shape = plCreateCubeShape(world->sdk, world->world, size);

	} else if (strcmp(type, "plane") == 0) {
		plReal plane[4];
		get_arg_vec(L, 3, 4, plane);
		shape = plCreatePlaneShape(world->sdk, world->world, plane[0], plane[1], plane[2], plane[3]);
		
	} else if (strcmp(type, "cylinder") == 0) {
		const plReal radius = (plReal)lua_tonumber(L,3);
		const plReal height = (plReal)lua_tonumber(L,4);

		const int axis = (int) luaL_optinteger(L,5,1);
		if(axis<0 || axis>2) {
			luaL_error(L, "invalid axis type : %d", axis);
		}
		shape = plCreateCylinderShape(world->sdk,world->world,radius,height,axis);

	} else if (strcmp(type, "capsule") == 0) {
		const plReal radius = (plReal)lua_tonumber(L, 3);
		const plReal height = (plReal)lua_tonumber(L, 4);

		const int axis = (int)luaL_optnumber(L, 5, 1);
		if (axis < 0 || axis > 2) {
			luaL_error(L, "invalid axis type : %d", axis);
		}
		shape = plCreateCapsuleShape(world->sdk, world->world, radius, height, axis);

	} else if (strcmp(type, "compound") == 0) {
		shape = plCreateCompoundShape(world->sdk, world->world);
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
lnew_collision_obj(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	plCollisionShapeHandle shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TNUMBER);
	const int useridx = (int)lua_tointeger(L, 3);

	luaL_checktype(L, 4, LUA_TTABLE);
	plVector3 pos;
	extract_vec(L, 4, 3, pos);

	luaL_checktype(L, 5, LUA_TTABLE);
	plQuaternion quat;
	extract_vec(L, 5, 4, quat);

	auto userdata = lua_touserdata(L, 6);

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
ladd_to_compound(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto compound = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	auto child = (plCollisionShapeHandle)lua_touserdata(L, 3);


	luaL_checktype(L, 4, LUA_TTABLE);
	plVector3 pos;
	extract_vec(L, 4, 3, pos);

	luaL_checktype(L, 5, LUA_TTABLE);
	plQuaternion quat;
	extract_vec(L, 5, 4, quat);

	plAddChildShape(world->sdk, world->world, compound, child, pos, quat);
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
	assert(world->sdk != nullptr);
	if (world->sdk && world->world) {
		plDeleteCollisionWorld(world->sdk, world->world);
	}
	world->sdk = nullptr;
	world->world = nullptr;
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
//-- 这样使用回调的方式
//-- 1. 复杂度较高，对lua使用者稍不友好，也容易出错
//-- 2. 速度慢，多次的lua 回调，多次的创建回收points 表，再合并，维护开销大
//-- 3. 没有终止约束条件
//-- 4. 如果是回调方式，建议从名称上就体现
// 保留的一种方式
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

static int
lraycast(lua_State *L) {
	auto world = to_world(L);

	plVector3 from, to;
	extract_vec(L, 2, 3, from);
	extract_vec(L, 3, 3, to);

	ClosestRayResult result;
	const bool hitted = plRaycast(world->sdk, world->world, from, to, result);

	lua_pushboolean(L, hitted);
	if (!hitted) {
		return 1;
	}

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
lset_obj_trans(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TTABLE);
	luaL_checktype(L, 4, LUA_TTABLE);

	plVector3 pos;
	extract_vec(L, 3, 3, pos);
	plQuaternion quat;
	extract_vec(L, 4, 4, quat);

	plSetCollisionObjectTransform(world->sdk, world->world, obj, pos, quat);
	return 0;
}


static int
lset_obj_pos(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TTABLE);
	plVector3 pos;
	extract_vec(L, 3, 3, pos);

	plSetCollisionObjectPosition(world->sdk, world->world, obj, pos);

	return 0;
}

static int
lset_obj_rot(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TTABLE);
	plQuaternion quat;
	extract_vec(L, 3, 4, quat);   // error: args 3->4 

	plSetCollisionObjectRotation(world->sdk, world->world, obj, quat);

	return 0;
}

// yaw,pitch,roll, not use table, avoid  different meanings
static int 
lset_obj_rot_euler(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L,2,LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L,2);

	plReal yaw = (plReal)lua_tonumber(L, 3); 
	plReal pitch = (plReal)lua_tonumber(L, 4); 
	plReal roll = (plReal)lua_tonumber(L, 5); 

	plSetCollisionObjectRotationEuler( world->sdk,world->world,obj, yaw,pitch,roll);
	return 0;
}
static int 
lset_obj_rot_axis_angle(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (plCollisionObjectHandle)lua_touserdata(L,2);

	luaL_checktype(L, 3, LUA_TTABLE);
	plVector3 axis;
	extract_vec(L,3,3,axis);
	btScalar angle = (btScalar)lua_tonumber(L, 4); 

	plSetCollisionObjectRotationAxisAngle( world->sdk,world->world,obj,axis,angle);
	return 0;
}


static void
register_bullet_world_node(lua_State *L) {
	luaL_newmetatable(L, "BULLET_WORLD_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	 // BULLET_NODE.__index = BULLET_NODE

	luaL_Reg l[] = {
		"new_shape", lnew_shape,
		"del_shape", ldel_shape,
		"new_obj", lnew_collision_obj,
		"del_obj", ldel_collision_obj,
		"add_obj", ladd_collision_obj,
		"remove_obj",lremove_collision_obj,
		"set_obj_transform", lset_obj_trans,
		"set_obj_position", lset_obj_pos,
		"set_obj_rotation", lset_obj_rot,
		"set_obj_pos", lset_obj_pos,
		"set_obj_rot_euler",lset_obj_rot_euler,
		"set_obj_rot_axis_angle",lset_obj_rot_axis_angle,
		"add_to_compound", ladd_to_compound,
	
		"world_collide",lworld_collide,
		"world_collide_ucb", lworld_collide_ucb,
		"collide_objects", lcollide_objects,
		"raycast", lraycast,
		
		"__gc", ldel_bullet_world,
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