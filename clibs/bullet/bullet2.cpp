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
	luaL_checktype(L, LUA_TUSERDATA, idx);
	auto world = (world_node*)lua_touserdata(L, idx);
	check_world(world);

	return world;
}

static int
lnew_shpae(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, LUA_TSTRING, 2);
	const char* type = lua_tostring(L, 2);

	plCollisionShapeHandle shape = nullptr;
	if (strcmp(type, "sphere") == 0) {
		luaL_checktype(L, LUA_TNUMBER, 3);
		btScalar radius = (btScalar)lua_tonumber(L, 2);
		shape = plCreateSphereShape(world->sdk, world->world, radius);
	} else if (strcmp(type, "cube") == 0) {

	} else if (strcmp(type, "plane") == 0) {
		plReal plane[4];
		for (auto ii = 0; ii < 4; ++ii) {
			const auto idx = ii + 3;
			luaL_checktype(L, LUA_TNUMBER, idx);
			plane[ii] = (btScalar)lua_tonumber(L, idx);
		}

		shape = plCreatePlaneShape(world->sdk, world->world, plane[0], plane[1], plane[2], plane[3]);
		
	} else if (strcmp(type, "cylinder") == 0) {

	} else if (strcmp(type, "capsule") == 0) {
		const btScalar radius = (btScalar)lua_tonumber(L, 3);
		const btScalar height = (btScalar)lua_tonumber(L, 4);

		const int axis = (int)luaL_optnumber(L, 5, 1);
		if (axis < 0 || axis > 2) {
			luaL_error(L, "invalid axis type : %d", axis);
		}
		shape = plCreateCapsuleShape(world->sdk, world->world, radius, height, axis);

	} else if (strcmp(type, "compound") == 0) {

	}

	assert(shape);
	lua_pushlightuserdata(L, shape);

	return 1;
}

template<typename T>
void extract_vec(lua_State *L, int num, T& obj) {
	for (auto ii = 0; ii < 3; ++ii) {
		lua_geti(L, 4, ii + 1);
		obj[ii] = (plReal)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
};

static int
lnew_collision_obj(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, LUA_TUSERDATA, 2);
	plCollisionShapeHandle shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, LUA_TNUMBER, 3);
	const int useridx = (int)lua_tointeger(L, 3);

	luaL_checktype(L, LUA_TTABLE, 4);
	btVector3 pos;
	extract_vec(L, 3, pos);

	luaL_checktype(L, LUA_TTABLE, 5);
	btQuaternion quat;
	extract_vec(L, 4, quat);

	auto userdata = lua_touserdata(L, 6);

	auto collision_obj = plCreateCollisionObject(world->sdk, world->world, userdata, useridx, shape, pos, quat);
	lua_pushlightuserdata(L, collision_obj);
	return 1;
}

static int
ldel_collision_obj(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, LUA_TLIGHTUSERDATA, 2);
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
ladd_to_compound(lua_State *L) {
	auto world = to_world(L);

	luaL_checktype(L, LUA_TLIGHTUSERDATA, 2);
	auto compound = (plCollisionShapeHandle)lua_touserdata(L, 2);

	luaL_checktype(L, LUA_TLIGHTUSERDATA, 3);
	auto child = (plCollisionShapeHandle)lua_touserdata(L, 3);


	luaL_checktype(L, LUA_TTABLE, 4);
	btVector3 pos;
	extract_vec(L, 3, pos);

	luaL_checktype(L, LUA_TTABLE, 5);
	btQuaternion quat;
	extract_vec(L, 4, quat);

	plAddChildShape(world->sdk, world->world, compound, child, pos, quat);
	return 0;
}

static int
ldel_shape(lua_State *L) {
	luaL_checktype(L, LUA_TUSERDATA, 1);
	luaL_checktype(L, LUA_TLIGHTUSERDATA, 2);

	world_node *world = (world_node*)lua_touserdata(L, 1);
	check_world(world);
	plCollisionShapeHandle shape = (plCollisionShapeHandle)lua_touserdata(L, 2);

	plDeleteShape(world->sdk, world->world, shape);

	return 0;
}

static int
ldel_bullet_world(lua_State *L) {
	luaL_checktype(L, LUA_TUSERDATA, 1);

	world_node* world = (world_node*)lua_touserdata(L, 1);
	assert(world->sdk != nullptr);
	if (world->sdk && world->world) {
		plDeleteCollisionWorld(world->sdk, world->world);
	}
	world->sdk = nullptr;
	world->world = nullptr;
	return 0;
}

static int
lnew_bullet_world(lua_State *L) {
	luaL_checktype(L, LUA_TUSERDATA, 1);
	bullet_node* bullet = (bullet_node*)lua_touserdata(L, 1);

	world_node *world = (world_node*)lua_newuserdata(L, sizeof(world_node));
	luaL_setmetatable(L, "BULLET_WORLD_NODE");

	return 1;
}

static int
ldel_bullet(lua_State *L) {
	luaL_checktype(L, LUA_TUSERDATA, 1);
	bullet_node *bullet = (bullet_node*)lua_touserdata(L, 1);

	if (bullet->sdk) {
		plDeleteCollisionSdk(bullet->sdk);
	}
	return 0;
}

static int
lnew_bullet(lua_State *L) {
	luaL_checktype(L, LUA_TNUMBER, 1);
	const int sdkVersion = (int)lua_tointeger(L, 1);
	assert(2 <= sdkVersion && sdkVersion <= 3);

	bullet_node *bullet = (bullet_node*)lua_newuserdata(L, sizeof(bullet_node));
	luaL_setmetatable(L, "BULLET_NODE");

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

static int
lcollide(lua_State *L) {
	auto world = to_world(L);

	//lua_call
	//plWorldCollide(world->sdk, world->world, );
	return 1;
}

static void
register_bullet_world_node(lua_State *L) {
	luaL_newmetatable(L, "BULLET_WORLD_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	// BULLET_NODE.__index = BULLET_NODE

	luaL_Reg l[] = {
		"new_shape", lnew_shpae,
		"del_shape", ldel_shape,
		"new_collision_obj", lnew_collision_obj,
		"del_collision_obj", ldel_collision_obj,
		"add_collision_obj", ladd_collision_obj,
		"add_to_compound", ladd_to_compound,
		"collide", lcollide,
		"__gc", ldel_bullet_world,
		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
	LUAMOD_API int
	luaopen_bullet2(lua_State *L) {
		register_bullet_node(L);
		register_bullet_world_node(L);

		luaL_Reg l[] = {
			{ "new", lnew_bullet},
		};

		luaL_newlib(L, l);

		return 1;

	}
}