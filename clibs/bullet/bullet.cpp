#define LUA_LIB

#include "btBulletDynamicsCommon.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

//stl
#include <vector>

#include <cassert>

#include <cstdio>
#include <cstring>
#include <cstdlib>

//#include "Collision/CollisionSdkC_Api.h"
//#include "Collision/Internal/BulletDebugDraw.h"

struct collworld_node {
	btDefaultCollisionConfiguration *cfg;
	btCollisionDispatcher	*dispatcher;
	btDbvtBroadphase		*broadphase;
	//MyDebugDrawer			*debug_drawer;
	btCollisionWorld		*world;
};

template<typename T>
static inline void
check_delete(T* &p) {
	if (p) {
		delete p;
		p = nullptr;
	}
}

static inline collworld_node*
get_worldnode(lua_State *L, int idx = 1) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	return (collworld_node*)lua_touserdata(L, idx);
}

template<typename T>
static inline void
get_arg_vec(lua_State *L, int index, int num, T &obj) {	
	for (auto ii = 0; ii < num; ++ii) {
		const auto idx = ii + index;
		luaL_checktype(L, idx, LUA_TNUMBER);
		obj[ii] = (btScalar)lua_tonumber(L, idx);
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
	assert(bytenum < (int)(sizeof(phytypes) / sizeof(phytypes[0])));

	return phytypes[bytenum];
}

static inline void
remove_collision_obj(btCollisionWorld *world, btCollisionObject *collobj) {
	if (collobj->getWorldArrayIndex() != -1) {
		world->removeCollisionObject(collobj);
	}

	auto shape = collobj->getCollisionShape();
	if (shape) {
		delete shape;
		collobj->setCollisionShape(nullptr);
	}
}

static inline void
remove_collision_objects(btCollisionWorld *world) {
	auto &collobjs = world->getCollisionObjectArray();
	for (int ii = 0; world->getNumCollisionObjects(); ++ii) {
		remove_collision_obj(world, collobjs[ii]);
	}
}


static inline btHeightfieldTerrainShape *
create_terrain_shape(lua_State *L, collworld_node* world, int index) {
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
	const btScalar heightmap_scale = (btScalar) lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "min_height");
	const btScalar minHeight = (btScalar)lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "max_height");
	const btScalar maxHeight = (btScalar)lua_tonumber(L, -1);
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

	return new btHeightfieldTerrainShape(width, height,
		hm.data, heightmap_scale,
		minHeight, maxHeight, upAxis,
		get_phys_datatype(hm.elembits), flip_quad_edges);
}

static inline void
get_vec(lua_State *L, int index, int count, btScalar *v) {
	for (int ii = 0; ii < count; ++ii) {
		lua_geti(L, index, ii + 1);
		v[ii] = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
}

static int
lnew_shape(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);

	btCollisionShape *shape = nullptr;

	if (strcmp(type, "sphere") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		lua_getfield(L, 3, "radius");
		const btScalar radius = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);

		shape = new btSphereShape(radius);
	} else if (strcmp(type, "box") == 0) {		
		luaL_checktype(L, 3, LUA_TTABLE);
		btVector3 size;
		lua_getfield(L, 3, "size");
		get_vec(L, -1, 3, size);
		lua_pop(L, 1);

		shape = new btBoxShape(size);		
		
	} else if (strcmp(type, "plane") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		btVector3 normal;
		lua_getfield(L, 3, "normal");
		get_vec(L, -1, 4, normal);
		lua_pop(L, 1);
		lua_getfield(L, 3, "distance");
		const btScalar distance = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);
		shape = new btStaticPlaneShape(normal, distance);		
	} else if (strcmp(type, "capsule") == 0) {
		luaL_checktype(L, 3, LUA_TTABLE);
		lua_getfield(L, 3, "radius");
		const btScalar radius = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, 3, "height");
		const btScalar height = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, 3, "axis");
		const char* axis = luaL_optstring(L, -1, "X");
		assert(strlen(axis) > 0);
		lua_pop(L, 1);
		switch (axis[0]) {
		case 'X':
			shape = new btCapsuleShapeX(radius, height);
			break;
		case 'Y':
			shape = new btCapsuleShape(radius, height);
			break;
		case 'Z':
			shape = new btCapsuleShapeZ(radius, height);
			break;
		default:
			luaL_error(L, "invalid axis data:%d", axis);
			break;
		}
	} else if (strcmp(type, "compound") == 0) {
		shape = new btCompoundShape();
	} else if (strcmp(type,"terrain") == 0 ) {
		shape = create_terrain_shape(L, worldnode, 3);
	} else {
		return luaL_error(L, "unknown type:%s", type);
	}

	lua_pushlightuserdata(L, shape);
	return 1;
}

template<typename T>
void extract_vec(lua_State *L, int index, int num, T& obj) {
	for (auto ii = 0; ii < num; ++ii) {
		lua_geti(L, index, ii + 1);
		obj[ii] = (btScalar)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
};

template<typename T>
void push_vec(lua_State *L, int num, const T &obj){
	lua_createtable(L, num, 0);
	for (auto ii = 0; ii < num; ++ii) {
		lua_pushnumber(L, obj[ii]);
		lua_seti(L, -2, ii + 1);
	}
}

template<typename T>
void push_vec(lua_State *L, const char* name, int num, const T &obj) {
	push_vec(L, num, obj);
	lua_setfield(L, -2, name);
};

//static int 
//lcreate_debugDrawer(lua_State *L) {
//	auto worldnode = get_worldnode(L);
//	check_delete(worldnode->debug_drawer);
//
//	worldnode->debug_drawer = new MyDebugDrawer();
//	worldnode->world->setDebugDrawer(worldnode->debug_drawer);
//	worldnode->debug_drawer->setDebugMode(
//		btIDebugDraw::DBG_DrawWireframe
//	);
//	return 0;
//}

//static int 
//ldelete_debugDrawer(lua_State *L) {
//	auto worldnode = get_worldnode(L);
//	check_delete(worldnode->debug_drawer);
//	return 0;
//}

static int
lnew_collision_obj(lua_State *L) {
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto shape = (btCollisionShape*)lua_touserdata(L, 2);
	if (shape == nullptr) {
		luaL_error(L, "invalid shape object");
		return 0;
	}

	btCollisionObject* coll_obj = new btCollisionObject;

	btVector3* pos = nullptr;
	if (!lua_isnoneornil(L, 3)) {
		luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
		pos = (btVector3*)lua_touserdata(L, 3);
	}

	btQuaternion* quat = nullptr;
	if (!lua_isnoneornil(L, 4)) {
		luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
		quat = (btQuaternion*)lua_touserdata(L, 4);
	}

	if (!lua_isnil(L, 5)){
		const int useridx = (int)lua_tointeger(L, 5);
		coll_obj->setUserIndex(useridx);
	}

	void *userdata = lua_isnoneornil(L, 6) ? nullptr : lua_touserdata(L, 6);
	
	coll_obj->setUserPointer(userdata);
	coll_obj->setCollisionShape(shape);

	if (pos || quat) {
		btTransform tr;
		if (pos)
			tr.setOrigin(*pos);
		if (quat)
			tr.setRotation(*quat);
		coll_obj->setWorldTransform(tr);
	}

	if (shape->getShapeType() == TERRAIN_SHAPE_PROXYTYPE) {
		int flags = coll_obj->getCollisionFlags();
		flags |= btCollisionObject::CF_DISABLE_VISUALIZE_OBJECT;
		coll_obj->setCollisionFlags(flags);
	}
	lua_pushlightuserdata(L, coll_obj);
	return 1;
}

static int
ldel_collision_obj(lua_State *L) {
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (btCollisionObject*)lua_touserdata(L, 2);

	if (obj->getWorldArrayIndex() != -1) {
		worldnode->world->removeCollisionObject(obj);
	}

	check_delete(obj);
	return 0;
}

static int
ladd_collision_obj(lua_State *L) {
	auto worldnode = get_worldnode(L);

	auto obj = (btCollisionObject*)lua_touserdata(L, 2);
	worldnode->world->addCollisionObject(obj);
	return 0;
}

static int
lremove_collision_obj(lua_State *L) {
	auto worldnode = get_worldnode(L);

	auto obj = (btCollisionObject*) lua_touserdata(L,2);
	if (obj->getWorldArrayIndex() != -1) {
		worldnode->world->removeCollisionObject(obj);
	}
	return 0;
}

//static int 
//lget_debug_info(lua_State *L) {
//	auto worldnode = get_worldnode(L);
//	btCollisionWorld* btWorld = worldnode->world;
//	MyDebugDrawer *debugDrawer = (MyDebugDrawer*) btWorld->getDebugDrawer(); 
//	if(debugDrawer == nullptr ) {
//	   return 0;
//	}
//
//	int idx_size =0, vert_size =0;
//	float *verts = debugDrawer->getVertices(vert_size);
//	unsigned int *indices = debugDrawer->getIndices(idx_size);
//	if( idx_size<=0 || vert_size<=0 ) {
//		return 0;
//	}
//	lua_pushlstring(L,(const char *) verts, vert_size*sizeof(struct MyDebugVec) );
//	lua_pushlstring(L,(const char *) indices, idx_size*sizeof(unsigned int) );
//	lua_pushinteger(L,vert_size);
//	lua_pushinteger(L,idx_size);
//	return 4;
//}
//
//static int 
//ldebug_draw_world(lua_State *L) {
//	auto worldnode = get_worldnode(L);
//	btCollisionWorld* collisionWorld = worldnode->world;
//	//MyDebugDrawer* debugDrawer = (MyDebugDrawer*)collisionWorld->getDebugDrawer();
//	collisionWorld->debugDrawWorld();
//	return 0;
//}

//// clear debugDrawer data
//static int 
//ldebug_clear_world(lua_State*L) {
//	auto world = get_worldnode(L);
//	btCollisionWorld* btWorld =(btCollisionWorld*) world->world;
//	MyDebugDrawer* debugDrawer = (MyDebugDrawer*)btWorld->getDebugDrawer();
//	if( debugDrawer) 
//		debugDrawer->reset();
//	return 0;
//}

static int
ladd_to_compound(lua_State *L) {
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto compound = (btCompoundShape*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	auto child = (btCollisionShape*)lua_touserdata(L, 3);

	btVector3* pos = nullptr;
	if (!lua_isnoneornil(L, 4)) {
		luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
		pos = (btVector3*)lua_touserdata(L, 4);
	}

	btQuaternion* quat = nullptr;
	if (!lua_isnoneornil(L, 5)) {
		luaL_checktype(L, 5, LUA_TLIGHTUSERDATA);
		quat = (btQuaternion*)lua_touserdata(L, 5);
	}

	btTransform localTrans;

	if (pos || quat) {
		if (pos)
			localTrans.setOrigin(*pos);
		if (quat)
			localTrans.setRotation(*quat);
	} else {
		localTrans.setOrigin(btVector3(0.0f, 0.0f, 0.0f));
	}

	compound->addChildShape(localTrans, child);

	return 0;
}

static int 
lupdate_object_shape(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L,2,LUA_TLIGHTUSERDATA);
	auto object = (btCollisionObject*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	btVector3 *scale = (btVector3 *)lua_touserdata(L, 3);

	auto shape = object->getCollisionShape();	
	if (shape == nullptr) {
		luaL_error(L, "collision object do not have shape");
	}

	shape->setLocalScaling(*scale);	
	worldnode->world->updateSingleAabb(object);
	return 0;
}

static int
lset_shape_scale(lua_State *L) {
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto shape = (btCollisionShape*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	btVector3 *scale = (btVector3*)lua_touserdata(L, 3);

	shape->setLocalScaling(*scale);
	return 0;
}

static int
lget_obj_aabb(lua_State *L){
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	auto obj = (btCollisionObject*)lua_touserdata(L, 2);

	auto shape = obj->getCollisionShape();

	btVector3 min, max;
	shape->getAabb(obj->getWorldTransform(), min, max);

	push_vec(L, 3, min);
	push_vec(L, 3, max);
	return 2;
}

static int
ldel_shape(lua_State *L) {
	auto worldnode = get_worldnode(L);	
	assert(worldnode && worldnode->world);

	auto shape = (btCollisionShape*)lua_touserdata(L, 2);
	check_delete(shape);
	return 0;
}

static int
ldel_bullet_world(lua_State *L) {
	auto worldnode = get_worldnode(L);

	if (worldnode->world) {
		remove_collision_objects(worldnode->world);
	}

	check_delete(worldnode->world);

	check_delete(worldnode->cfg);
	check_delete(worldnode->dispatcher);
	check_delete(worldnode->broadphase);
	return 0;
}

// clear all objects in bullet world 
static int 
lreset_bullet_world(lua_State *L) {
	auto worldnode = get_worldnode(L);
	assert(worldnode->world);
	
	remove_collision_objects(worldnode->world);	
	return 0;
}

// object parameters need open for lua
static int
lnew_bullet_world(lua_State *L) {
	collworld_node *worldnode = (collworld_node*)lua_newuserdatauv(L, sizeof(collworld_node), 0);
	luaL_setmetatable(L, "BULLET_WORLD_NODE");
	worldnode->cfg		= new btDefaultCollisionConfiguration;
	worldnode->dispatcher = new btCollisionDispatcher(worldnode->cfg);
	worldnode->broadphase= new btDbvtBroadphase();
	worldnode->world	= new btCollisionWorld(worldnode->dispatcher, worldnode->broadphase, worldnode->cfg);
	return 1;
}

struct CallBackData {
	lua_State *L;
};

CallBackData gcbdata;

struct contact_point {
	btVector3 ptAInWS;
	btVector3 ptBInWS;
	btVector3 normalOnB;
	btScalar distance;
};
struct CollideCallBackData {
	std::vector<contact_point>	points;
	btCollisionWorld *world;
};

CollideCallBackData gCollideCallBackData;

static size_t
collide_object(btCollisionWorld *world, btCollisionObject *obj0, btCollisionObject *obj1, std::vector<contact_point> &points) {
	assert(obj0); 
	assert(obj1);

	struct crcb : public btCollisionWorld::ContactResultCallback {
		crcb(std::vector<contact_point> &p) : points(p){}
		std::vector<contact_point>	&points;
		virtual btScalar addSingleResult(btManifoldPoint& cp,
			const btCollisionObjectWrapper* colObj0Wrap,
			int partId0, int index0,
			const btCollisionObjectWrapper* colObj1Wrap,
			int partId1, int index1) {
			points.push_back(contact_point{ cp.m_positionWorldOnA, cp.m_positionWorldOnB, cp.m_normalWorldOnB, cp.m_distance1 });
			return 1.f;
		}
	};

	crcb cb(points);
	world->contactPairTest(obj0, obj1, cb);
	return cb.points.size();
}

//static int
//lworld_collide_ucb(lua_State *L) {
//	auto worldnode = get_worldnode(L);
//	luaL_checktype(L, 2, LUA_TFUNCTION);
//
//	gcbdata.L = L;
//
//	auto near_callback = [] (btBroadphasePair& collisionPair, btCollisionDispatcher& dispatcher, const btDispatcherInfo& dispatchInfo){
//
//		btCollisionObject* colObj0 = (btCollisionObject*)collisionPair.m_pProxy0->m_clientObject;
//		btCollisionObject* colObj1 = (btCollisionObject*)collisionPair.m_pProxy1->m_clientObject;		
//
//		lua_State *L = gcbdata.L;
//
//		assert(lua_type(L, -1) == LUA_TFUNCTION);	
//		lua_pushvalue(L, -1);	// keep this lua function
//
//		lua_pushlightuserdata(L, colObj0);
//		lua_pushlightuserdata(L, colObj1);		
//		const int numarg = 2;
//		lua_call(L, numarg, 0);
//
//		assert(lua_type(L, -1) == LUA_TFUNCTION);
//	};
//
//	CallBackData cb_data = { L, };
//	if (lua_type(L, 3) != LUA_TTABLE) {
//		assert("need to implement");
//	}
//
//	worldnode->dispatcher->setNearCallback(near_callback);
//	worldnode->world->performDiscreteCollisionDetection();
//	gcbdata.L = nullptr;
//	
//	return 0;
//}

static int
push_contract_points(lua_State *L, const std::vector<contact_point> &points) {
	if (points.empty())
		return 0;

	lua_createtable(L, (int)points.size(), 0);
	for (int ii = 0; ii < (int)points.size(); ++ii) {
		lua_createtable(L, 0, 4);

		const auto &point = points[ii];
		push_vec(L, "ptA_in_WS", 3, point.ptAInWS);
		push_vec(L, "ptB_in_WS", 3, point.ptBInWS);
		push_vec(L, "normalB_in_WS", 3, point.normalOnB);

		lua_pushnumber(L, point.distance);
		lua_setfield(L, -2, "distance");

		lua_seti(L, -2, ii + 1);
	}
	return 1;
}

static int
lworld_collide(lua_State *L) {
	auto worldnode = get_worldnode(L);

	auto &points = gCollideCallBackData.points;
	gCollideCallBackData.world = worldnode->world;	
	points.clear();

	worldnode->dispatcher->setNearCallback(
		[](btBroadphasePair& collisionPair, btCollisionDispatcher& dispatcher, const btDispatcherInfo& dispatchInfo) {
			auto obj0 = (btCollisionObject*)collisionPair.m_pProxy0->m_clientObject;
			auto obj1 = (btCollisionObject*)collisionPair.m_pProxy1->m_clientObject;

			collide_object(gCollideCallBackData.world, obj0, obj1, gCollideCallBackData.points);
		});

	worldnode->world->performDiscreteCollisionDetection();

	return push_contract_points(L, points);
}

static int
lcollide_objects(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);

	auto objA = (btCollisionObject *)lua_touserdata(L, 2);
	auto objB = (btCollisionObject *)lua_touserdata(L, 3);

	std::vector<contact_point>	points;
	collide_object(worldnode->world, objA, objB, points);
	return push_contract_points(L, points);
}

struct ClosestRayResult {	
	int       m_hitObjId;
	btScalar  m_hitFraction;
	btVector3 m_hitPointWorld;
	btVector3 m_hitNormalWorld;
	int 	  m_filterGroup;
	int 	  m_filterMask;
	int 	  m_flags;
};

static int
lraycast(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	btVector3* from = (btVector3*)lua_touserdata(L, 2);
	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	btVector3* to = (btVector3*)lua_touserdata(L, 3);

	ClosestRayResult result;

	struct ClosestRayResultCallback : btCollisionWorld::ClosestRayResultCallback {
		ClosestRayResultCallback(const btVector3& rayFromWorld, const btVector3& rayToWorld)
			: btCollisionWorld::ClosestRayResultCallback(rayFromWorld, rayToWorld) {
			m_closestHitFraction = 10.0f;
		}

		virtual btScalar addSingleResult(btCollisionWorld::LocalRayResult& rayResult, bool normalInWorldSpace) {
			//caller already does the filter on the m_closestHitFraction		
			if (rayResult.m_hitFraction >= m_closestHitFraction)
				printf("****** error fraction ******");
			m_closestHitFraction = rayResult.m_hitFraction;
			m_collisionObject = rayResult.m_collisionObject;
			if (normalInWorldSpace) {
				m_hitNormalWorld = rayResult.m_hitNormalLocal;
			} else {
				///need to transform normal into worldspace
				m_hitNormalWorld = m_collisionObject->getWorldTransform().getBasis() * rayResult.m_hitNormalLocal;
			}
			m_hitPointWorld.setInterpolate3(m_rayFromWorld, m_rayToWorld, rayResult.m_hitFraction);
			return rayResult.m_hitFraction;
		}
	};

	ClosestRayResultCallback cb(*from, *to);
	worldnode->world->rayTest(*from, *to, cb);

	const bool hitted = cb.hasHit();
	if (cb.hasHit()) {
		result.m_hitPointWorld = cb.m_hitPointWorld;
		result.m_hitNormalWorld = cb.m_hitNormalWorld;

		result.m_hitFraction = cb.m_closestHitFraction;
		result.m_hitObjId = cb.m_collisionObject->getUserIndex();
		result.m_filterGroup = cb.m_collisionFilterGroup;
		result.m_filterMask = cb.m_collisionFilterMask;
		result.m_flags = cb.m_flags;

		//if (world->getDebugDrawer()) {
		//	btVector3 pt(result.m_hitPointWorld[0], result.m_hitPointWorld[1], result.m_hitPointWorld[2]);
		//	btVector3 nt(result.m_hitNormalWorld[0], result.m_hitNormalWorld[1], result.m_hitNormalWorld[2]);
		//	nt += pt;
		//	world->getDebugDrawer()->drawLine(pt, nt, btVector3(0.85f, 0.6f, 0.6f));
		//	world->getDebugDrawer()->drawLine(pt, nt + btVector3(0, 0, -1), btVector3(0.6f, 0.85f, 0.6f));
		//	world->getDebugDrawer()->drawLine(pt, nt + btVector3(1, 0, 0), btVector3(0.6f, 0.6f, 0.85f));
		//}
	}
	
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

// static int
// ldrawline(lua_State *L) {
// 	auto worldnode = get_worldnode(L);
// 	assert(worldnode && worldnode->world);

// 	btVector3* from = (btVector3*)lua_touserdata(L, 2);
// 	btVector3* to = (btVector3*)lua_touserdata(L, 3);

// 	uint32_t color = (int)luaL_optinteger(L,4,0xffffffff);

// 	//plDrawline(world->sdk, world->world, from, to, color );

// 	return 0;
// }

static int
lset_obj_user_idx(lua_State *L){
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	auto obj = (btCollisionObject*)lua_touserdata(L, 2);
	auto useridx = lua_tointeger(L, 3);

	obj->setUserIndex((int)useridx);
	return 0;
}

static int
lset_obj_trans(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (btCollisionObject*)lua_touserdata(L, 2);

	btTransform trans;
	bool needtrans = false;
	if (!lua_isnoneornil(L, 3)){
		luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
		auto pos = (const btVector3 *)lua_touserdata(L, 3);
		needtrans = true;
		trans.setOrigin(*pos);
	}

	const btQuaternion* quat = nullptr;
	if (!lua_isnoneornil(L, 4)){
		luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
		auto quat = (const btQuaternion *)lua_touserdata(L, 4);
		needtrans = true;
		trans.setRotation(*quat);
	}

	if (needtrans)
		obj->setWorldTransform(trans);

	worldnode->world->updateSingleAabb(obj);
	return 0;
}

static int
lget_obj_trans(lua_State *L){
	auto worldnode = get_worldnode(L);
	assert(worldnode && worldnode->world);

	auto obj = (btCollisionObject*)lua_touserdata(L, 2);
	auto trans = obj->getWorldTransform();
	lua_createtable(L, 16, 0);
	for (int ii = 0; ii < 3; ++ii){
		auto m = trans.getBasis();
		for (int jj = 0; jj < 3; ++ii){
			lua_pushnumber(L, m[ii][jj]);
			lua_seti(L, -2, ii*3+jj+1);
		}
		lua_pushnumber(L, 0.0);
		lua_seti(L, -2, ii*3+3+1);
	}
	lua_pushnumber(L, 1.0);
	lua_seti(L, -2, 16);
	return 1;
}

static int
lset_obj_pos(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (btCollisionObject*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	btVector3 *pos = (btVector3 *)lua_touserdata(L, 3);

	obj->setWorldTransform(btTransform(btQuaternion(0, 0, 0, 1), *pos));
	worldnode->world->updateSingleAabb(obj);
	return 0;
}

static int
lset_obj_rot(lua_State *L) {
	auto worldnode = get_worldnode(L);

	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	auto obj = (btCollisionObject*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	btQuaternion *quat = (btQuaternion *)lua_touserdata(L, 3);

	obj->setWorldTransform(btTransform(*quat));
	worldnode->world->updateSingleAabb(obj);

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
		{"new_shape",			lnew_shape},
		{"del_shape",			ldel_shape},
		{"update_object_shape",	lupdate_object_shape},
		{"set_shape_scale",		lset_shape_scale},
		{"get_shape_aabb",		lget_obj_aabb},

		{"new_obj",				lnew_collision_obj},
		{"del_obj",				ldel_collision_obj},
		{"add_obj",				ladd_collision_obj},
		{"remove_obj",			lremove_collision_obj},
		{"set_obj_user_idx",	lset_obj_user_idx},
		{"set_obj_transform",	lset_obj_trans},
		{"get_obj_transform",	lget_obj_trans},
		{"set_obj_position",	lset_obj_pos},
		{"set_obj_rotation",	lset_obj_rot},
		{"add_to_compound",		ladd_to_compound},
		{"world_collide",		lworld_collide,	},
		{"collide_objects",		lcollide_objects},
		{"raycast",				lraycast},
		//{"drawline",			ldrawline},
		//{"get_debug_info",		lget_debug_info},
		//{"create_debug_drawer",	lcreate_debugDrawer},
		//{"delete_debug_drawer",	ldelete_debugDrawer},
		//{"debug_begin_draw",		ldebug_draw_world},
		//{"debug_end_draw",		ldebug_clear_world},
		{"reset_world",			lreset_bullet_world},
		{"del_bullet_world",		ldel_bullet_world},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
	LUAMOD_API int
	luaopen_bullet(lua_State *L) {		
		register_bullet_world_node(L);

		luaL_Reg l[] = {
			{ "new", lnew_bullet_world},
			{nullptr, nullptr},
		};

		luaL_newlib(L, l);

		return 1;

	}
}