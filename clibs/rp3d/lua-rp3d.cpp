#define LUA_LIB

#include "reactphysics3d/reactphysics3d.h"

using namespace reactphysics3d;

extern "C" {

#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"

#ifdef lua_newuserdata
#undef lua_newuserdata
#define lua_newuserdata(L, sz) lua_newuserdatauv(L, sz, 0)
#endif

}

class AllocatorProfiler;

struct physics_common {
	class PhysicsCommon *pc;
	class DefaultLogger *logger;
	class AllocatorProfiler *alloc;
};

struct physics_world {
	PhysicsWorld *w;
};

static inline struct physics_common *
getP(lua_State *L) {
	return (struct physics_common *)lua_touserdata(L, lua_upvalueindex(1));
}

static inline class PhysicsWorld *
getW(lua_State *L) {
	struct physics_world *w = (struct physics_world *)lua_touserdata(L, 1);
	return w->w;
}

static const char *
getstring(lua_State *L, int index, const char *key) {
	if (lua_getfield(L, index, key) == LUA_TSTRING) {
		const char * ret = lua_tostring(L, -1);
		lua_pop(L, 1);
		return ret;
	}
	lua_pop(L, 1);
	return NULL;
}

static void
getdecimal(lua_State *L, int index, const char *key, decimal *ret) {
	if (lua_getfield(L, index, key) == LUA_TNUMBER) {
		*ret = (decimal)lua_tonumber(L, -1);
	}
	lua_pop(L, 1);
}

static void
getfloat(lua_State *L, int index, const char *key, float *ret) {
	if (lua_getfield(L, index, key) == LUA_TNUMBER) {
		*ret = (float)lua_tonumber(L, -1);
	}
	lua_pop(L, 1);
}

static void
getuint(lua_State *L, int index, const char *key, uint *ret) {
	lua_getfield(L, index, key);
	if (lua_isinteger(L, -1)) {
		*ret = (uint)lua_tointeger(L, -1);
	}
	lua_pop(L, 1);
}

static void
getbool(lua_State *L, int index, const char *key, bool *ret) {
	if (lua_getfield(L, index, key) == LUA_TBOOLEAN) {
		*ret = (bool)lua_toboolean(L, -1);
	}
	lua_pop(L, 1);
}

static int
lcreate_world(lua_State *L) {
	struct physics_common *P = getP(L);

	PhysicsWorld::WorldSettings settings;

	if (lua_istable(L,1)) {
		const char *worldName = getstring(L, 1, "worldName");
		if (worldName) {
			settings.worldName = worldName;
		}
		
		switch (lua_getfield(L, 1, "gravity")) {
		case LUA_TNUMBER:
			settings.gravity = Vector3(0, lua_tonumber(L, -1), 0);
			break;
		case LUA_TNIL:
			settings.gravity = Vector3(0, decimal(-9.81), 0);
			break;
		case LUA_TTABLE: {
			float t[3];
			int i;
			for (i=0;i<3;i++) {
				if (lua_geti(L, -1, i+1) != LUA_TNUMBER) {
					return luaL_error(L, "Invalid gravity[%d]", i+1);
				}
				t[i] = lua_tonumber(L, -1);
				lua_pop(L, 1);
			}
			settings.gravity = Vector3(t[0], t[1], t[2]);
			break; }
		default:
			return luaL_error(L, "Invalid gravity");
		}
		lua_pop(L, 1);
		getdecimal(L, 1, "persistentContactDistanceThreshold", &settings.persistentContactDistanceThreshold);
		getdecimal(L, 1, "defaultFrictionCoefficient", &settings.defaultFrictionCoefficient);
		getdecimal(L, 1, "defaultBounciness", &settings.defaultBounciness);
		getdecimal(L, 1, "restitutionVelocityThreshold", &settings.restitutionVelocityThreshold);
		getdecimal(L, 1, "defaultRollingRestistance", &settings.defaultRollingRestistance);
		getbool(L, 1, "isSleepingEnabled", &settings.isSleepingEnabled);
		getuint(L, 1, "defaultVelocitySolverNbIterations", &settings.defaultVelocitySolverNbIterations);
		getuint(L, 1, "defaultPositionSolverNbIterations", &settings.defaultPositionSolverNbIterations);
		getfloat(L, 1, "defaultTimeBeforeSleep", &settings.defaultTimeBeforeSleep);
		getdecimal(L, 1, "defaultSleepLinearVelocity", &settings.defaultSleepLinearVelocity);
		getdecimal(L, 1, "defaultSleepAngularVelocity", &settings.defaultSleepAngularVelocity);
		getuint(L, 1, "nbMaxContactManifolds", &settings.nbMaxContactManifolds);
		getdecimal(L, 1, "cosAngleSimilarContactManifold", &settings.cosAngleSimilarContactManifold);
	}

	struct physics_world *W = (struct physics_world *)lua_newuserdata(L, sizeof(*W));
	W->w = NULL;
	lua_pushvalue(L, lua_upvalueindex(2));
	lua_setmetatable(L, -2);
	W->w = P->pc->createPhysicsWorld(settings);

	return 1;
}

static int
ldestroy_world(lua_State *L) {
	struct physics_common *P = getP(L);
	class PhysicsWorld *world = getW(L);
	P->pc->destroyPhysicsWorld(world);
	return 0;
}

static Transform
get_transform(lua_State *L, int index) {
	const float * pos = (const float *)lua_touserdata(L, index);
	const float * ori = (const float *)lua_touserdata(L, index+1);

	if (pos == NULL && ori == NULL) {
		return Transform(Vector3(0,0,0), Quaternion(0,0,0,1));
	}
	if (ori == NULL) {
		const Vector3 *vec3 = (const Vector3 *)pos;
		return Transform (*vec3, Quaternion(0,0,0,1));
	}
	if (pos == NULL) {
		const Quaternion *quat = (const Quaternion *)ori;
		return Transform(Vector3(0,0,0), *quat);
	}
	const Vector3 *vec3 = (const Vector3 *)pos;
	const Quaternion *quat = (const Quaternion *)ori;

	return Transform (*vec3, *quat);
}

static int
lcreateCollisionBody(lua_State *L) {
	class PhysicsWorld * world = getW(L);

	// index 2 , 3 should be float3 and float4
	Transform trans = get_transform(L, 2);
	CollisionBody *body = world->createCollisionBody(trans);
	lua_pushlightuserdata(L, (void *)body);
	return 1;
}

static int
ldestroyCollisionBody(lua_State *L) {
	class PhysicsWorld * world = getW(L);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);

	world->destroyCollisionBody(body);
	return 0;
}

static int
lsetTransform(lua_State *L) {
//	class PhysicsWorld * world = getW(L);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);

	Transform trans = get_transform(L, 3);

	body->setTransform(trans);

	return 0;	
}

static int
lgetAABB(lua_State *L) {
//	class PhysicsWorld * world = getW(L);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);
	float *minv = (float *)lua_touserdata(L, 3);
	float *maxv = (float *)lua_touserdata(L, 4);

	AABB aabb = body->getAABB();
	const Vector3 v0 = aabb.getMin();
	const Vector3 v1 = aabb.getMax();

	minv[0] = v0.x;
	minv[1] = v0.y;
	minv[2] = v0.z;
	minv[3] = 1.0f;

	maxv[0] = v1.x;
	maxv[1] = v1.y;
	maxv[2] = v1.z;
	maxv[3] = 1.0f;

	return 0;
}

static inline int
maskbits(lua_State *L, int index) {
	int maskbits = (int)luaL_checkinteger(L, index);
	if (maskbits < 0 || maskbits > 0xffff)
		return luaL_error(L, "Invalid mask bits %x", maskbits);
	if (maskbits == 0)
		maskbits = 0xffff;
	return maskbits;
}

static int
laddCollisionShape(lua_State *L) {
//	class PhysicsWorld * world = getW(L);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);
	CollisionShape *shape = (CollisionShape *)lua_touserdata(L, 3);
	Transform trans = get_transform(L, 4);

	Collider *c = body->addCollider(shape, trans);
	lua_pushlightuserdata(L, (void *)c);
	return 1;
}

static int
lsetColliderMask(lua_State *L) {
//	class PhysicsWorld * world = getW(L);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	Collider *c = (Collider *)lua_touserdata(L, 2);
	int mask = maskbits(L, 3);
	if (mask > 0) {
		c->setCollisionCategoryBits((unsigned short)mask);
	}
	if (!lua_isnoneornil(L, 4)) {
		int mask_with = maskbits(L, 4);
		c->setCollideWithMaskBits((unsigned short)mask_with);
	}
	return 0;
}

class luaOverlapCallback : public OverlapCallback {
	bool hit;
public:
	luaOverlapCallback() : hit(false) {}
	bool isHit() const { return hit; }

	virtual void onOverlap(CallbackData& callbackData) override {
		hit = true;
	}
};

static int
ltestOverlap(lua_State *L) {
	class PhysicsWorld * world = getW(L);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);
	
	luaOverlapCallback cb;
	world->testOverlap(body, cb);
	lua_pushboolean(L, cb.isHit());
	return 1;
}

struct luaRaycastCallback : RaycastCallback {
	bool hit;
	Vector3 worldPoint;
	Vector3 worldNormal;
	CollisionBody *body;

	luaRaycastCallback() : hit (false), body(NULL) {}

	virtual decimal notifyRaycastHit(const RaycastInfo& raycastInfo) {
		hit = true;
		worldPoint = raycastInfo.worldPoint;
		worldNormal = raycastInfo.worldNormal;
		body = raycastInfo.body;
		// term
		return 0;
	}
};

// userdata world
// vector3 start
// vector3 end
// integer mask / pointer body
// vector3 &hitpoint
// vector3 &normal
// return true/false (isHit)
static int
lraycast(lua_State *L) {
	class PhysicsWorld * world = getW(L);
	const float * startp = (const float *)lua_touserdata(L, 2);
	const float * endp = (const float *)lua_touserdata(L, 3);
	float *hit = (float *)lua_touserdata(L, 5);
	float *normal = (float *)lua_touserdata(L, 6);

	Ray ray(Vector3(startp[0], startp[1], startp[2]), Vector3(endp[0], endp[1], endp[2]));

	if (lua_isinteger(L, 4)) {
		int categoryMaskBits = maskbits(L, 4);

		luaRaycastCallback cb;
		world->raycast(ray, &cb, (unsigned short)categoryMaskBits);

		hit[0] = cb.worldPoint.x;
		hit[1] = cb.worldPoint.y;
		hit[2] = cb.worldPoint.z;
		hit[3] = 1.0;

		normal[0] = cb.worldNormal.x;
		normal[1] = cb.worldNormal.y;
		normal[2] = cb.worldNormal.z;
		normal[3] = 0;

		lua_pushboolean(L, cb.hit);
		lua_pushlightuserdata(L, cb.body);
	} else {
		luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);	// it's a body
		CollisionBody *body = (CollisionBody *)lua_touserdata(L, 4);
		RaycastInfo raycastInfo;
		bool isHit = body->raycast(ray , raycastInfo);

		hit[0] = raycastInfo.worldPoint.x;
		hit[1] = raycastInfo.worldPoint.y;
		hit[2] = raycastInfo.worldPoint.z;
		hit[3] = 1.0;

		normal[0] = raycastInfo.worldNormal.x;
		normal[1] = raycastInfo.worldNormal.y;
		normal[2] = raycastInfo.worldNormal.z;
		normal[3] = 0;

		lua_pushboolean(L, isHit);
		lua_pushlightuserdata(L, raycastInfo.body);
	}
	return 2;
}

static int
lsphereShape(lua_State *L) {
	struct physics_common *P = getP(L);
	auto radius = (reactphysics3d::decimal)luaL_checknumber(L, 1);

	SphereShape * s = P->pc->createSphereShape(radius);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

static int
lboxShape(lua_State *L) {
	struct physics_common *P = getP(L);
	auto x = (reactphysics3d::decimal)luaL_checknumber(L, 1);
	auto y = (reactphysics3d::decimal)luaL_optnumber(L, 2, x);
	auto z = (reactphysics3d::decimal)luaL_optnumber(L, 3, y);

	Vector3 halfExtents(x,y,z);
	BoxShape * s = P->pc->createBoxShape(halfExtents);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

static int
lcapsuleShape(lua_State *L) {
	struct physics_common *P = getP(L);
	auto radius = (reactphysics3d::decimal)luaL_checknumber(L, 1);
	auto height = (reactphysics3d::decimal)luaL_checknumber(L, 2);

	CapsuleShape * s = P->pc->createCapsuleShape(radius, height);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

static int
lheightFieldShape(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, "RP3DCOMMON") != LUA_TUSERDATA) {
		return luaL_error(L, "Can't get PhysicsCommon");
	}
	struct physics_common *P = (struct physics_common *)lua_touserdata(L, -1);
	lua_pop(L, 1);

	auto grid_width = (uint32_t)luaL_checkinteger(L, 1);
	auto grid_height = (uint32_t)luaL_checkinteger(L, 2);

	auto min_height = (reactphysics3d::decimal)luaL_checknumber(L, 3);
	auto max_height = (reactphysics3d::decimal)luaL_checknumber(L, 4);

	auto heightfield_data = (float*)lua_touserdata(L, 5);

	auto height_scaling = (reactphysics3d::decimal)luaL_checknumber(L, 6);
	auto scaling = (reactphysics3d::Vector3*)lua_touserdata(L, 7);

	const uint32_t upaxis_Y = 1;
	HeightFieldShape * hfs = P->pc->createHeightFieldShape(grid_width, grid_height, min_height, max_height, heightfield_data, 
	reactphysics3d::HeightFieldShape::HeightDataType::HEIGHT_FLOAT_TYPE, upaxis_Y, height_scaling, *scaling);
	lua_pushlightuserdata(L, hfs);

	return 1;
}

static int
lrayfilter(lua_State *L) {
	return 2;
}

static int
ldestroySphereShape(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct physics_common *P = getP(L);
	P->pc->destroySphereShape((SphereShape *)lua_touserdata(L, 1));
	return 0;
}

static int
ldestroyBoxShape(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct physics_common *P = getP(L);
	P->pc->destroyBoxShape((BoxShape *)lua_touserdata(L, 1));
	return 0;
}

static int
ldestroyCapsuleShape(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct physics_common *P = getP(L);
	P->pc->destroyCapsuleShape((CapsuleShape *)lua_touserdata(L, 1));
	return 0;
}

static int
ldestroyHeightFieldShape(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct physics_common *P = getP(L);
	P->pc->destroyHeightFieldShape((HeightFieldShape *)lua_touserdata(L, 1));
	return 0;
}

// memory profiler

class AllocatorProfiler : public MemoryAllocator {
	size_t memory;
public:
	AllocatorProfiler() : memory(0) {}
	virtual ~AllocatorProfiler() override = default;
	AllocatorProfiler& operator=(AllocatorProfiler& allocator) = default;
	virtual void* allocate(size_t size) override {
		this->memory += size;
		return malloc(size);
	}
	virtual void release(void* pointer, size_t size) override {
		this->memory -= size;
		free(pointer);
	}
	size_t get_memory() const { return memory; }
};

static int
release_physics_common(lua_State *L) {
	struct physics_common *P = (struct physics_common *)lua_touserdata(L, 1);
	if (P->logger) {
		P->pc->destroyDefaultLogger(P->logger);
		P->logger = NULL;
	}
	if (P->pc) {
		delete P->pc;
		P->pc = NULL;
	}
	if (P->alloc) {
		delete P->alloc;
		P->alloc = NULL;
	}
	return 0;
}

static int
create_physics_common(lua_State *L) {
	struct physics_common *P = (struct physics_common *)lua_newuserdata(L, sizeof(*P));
	P->pc = NULL;
	P->logger = NULL;
	P->alloc = new AllocatorProfiler;
	P->pc = new PhysicsCommon(P->alloc);

	lua_newtable(L);
	lua_pushcfunction(L, release_physics_common);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	return 1;
}

static int
lmemory(lua_State *L) {
	struct physics_common *P = getP(L);
	lua_pushinteger(L, P->alloc->get_memory());
	return 1;
}

static int
llogger(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	struct physics_common *P = getP(L);

	DefaultLogger* logger = P->pc->createDefaultLogger();

	uint logLevelFlag = (uint)Logger::Level::Error;
	const char * level = getstring(L, 1, "Level");
	if (level) {
		switch(level[0]) {
		case 'e':
		case 'E':
			break;
		case 'w':
		case 'W':
			logLevelFlag |= (uint)Logger::Level::Warning;
			break;
		case 'i':
		case 'I':
			logLevelFlag |= (uint)Logger::Level::Warning;
			logLevelFlag |= (uint)Logger::Level::Information;
			break;
		default:
			luaL_error(L, "Level should be Error/Warning/Information");
			break;
		}
	}
	const char * format = getstring(L, 1, "Format");
	DefaultLogger::Format f = DefaultLogger::Format::Text;
	if (format) {
		switch(format[0]) {
		case 't':
		case 'T':
			break;
		case 'h':
		case 'H':
			f = DefaultLogger::Format::HTML;
			break;
		default:
			luaL_error(L, "Format should be Text/HTML");
			break;
		}
	}

	const char * filename = getstring(L, 1, "File");
	if (filename) {
		logger->addFileDestination(filename, logLevelFlag, f);
	} else {
		logger->addStreamDestination(std::cout, logLevelFlag, f);
	}

	PhysicsCommon::setLogger(logger);
	if (P->logger) {
		P->pc->destroyDefaultLogger(P->logger);
		P->logger = logger;
	}

	return 0;
}

extern "C" { LUAMOD_API int	
luaopen_rp3d_core(lua_State* L) {
	luaL_checkversion(L);

	if (sizeof(decimal) != sizeof(float)) {
		luaL_error(L, "decimal should be float");
	}

	create_physics_common(L);
	lua_pushvalue(L, -1);
	lua_setfield(L, LUA_REGISTRYINDEX, "RP3DCOMMON");

	int pc_index = lua_gettop(L);

	luaL_Reg collision_world[] = {
		{ "body_create", lcreateCollisionBody },
		{ "body_destroy", ldestroyCollisionBody },
		{ "set_transform", lsetTransform },
		{ "get_aabb", lgetAABB },
		{ "add_shape", laddCollisionShape },
		{ "set_mask", lsetColliderMask },
		{ "test_overlap", ltestOverlap },
		{ "raycast", lraycast },
		{ "__gc", NULL },
		{ NULL, NULL },
	};

	// collision_world metatable
	luaL_newlib(L, collision_world);
	int world_mt = lua_gettop(L);

	lua_pushvalue(L, pc_index);
	lua_pushcclosure(L, ldestroy_world, 1);
	lua_setfield(L, world_mt, "__gc");

	luaL_Reg worldcommon[] = {
		{ "rayfilter", NULL },
		{ "memory", lmemory },
		{ "logger", llogger },
		{ "create_world", NULL },
		{ "collision_world_mt", NULL },

		{ "create_sphere", lsphereShape },
		{ "create_box", lboxShape },
		{ "create_capsule", lcapsuleShape },

		{ "destroy_sphere", ldestroySphereShape },
		{ "destroy_box", ldestroyBoxShape },
		{ "destroy_capsule", ldestroyCapsuleShape },
		{ "destroy_heightfield",  ldestroyHeightFieldShape},

		{ NULL, NULL },
	};
	luaL_newlibtable(L, worldcommon);
	lua_pushvalue(L, pc_index);
	luaL_setfuncs(L, worldcommon, 1);
	int lib_index = lua_gettop(L);

	lua_pushcfunction(L, lrayfilter);
	lua_setfield(L, lib_index, "rayfilter");

	// lheightFieldShape should be a cfunction
	lua_pushcfunction(L, lheightFieldShape);
	lua_setfield(L, lib_index, "create_heightfield");

	lua_pushvalue(L, pc_index);
	lua_pushvalue(L, world_mt);
	lua_pushcclosure(L, lcreate_world, 2);
	lua_setfield(L, lib_index, "create_world");

	lua_pushvalue(L, world_mt);
	lua_setfield(L, lib_index, "collision_world_mt");
	
	return 1;
}}
