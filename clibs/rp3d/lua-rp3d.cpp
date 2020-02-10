#define IS_LOGGING_ACTIVE

#include "reactphysics3d.h"

using namespace reactphysics3d;

extern "C" {

#include "lua.h"
#include "lauxlib.h"

LUAMOD_API int luaopen_rp3d_core(lua_State *L);

}

#include <iostream>
#include <cstdio>
#include <cmath>

#define LUA_LIB

struct collision_world {
	class CollisionWorld *w;
	class Logger *logger;
};

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
getint(lua_State *L, int index, const char *key, int *ret) {
	lua_getfield(L, index, key);
	if (lua_isinteger(L, -1)) {
		*ret = (int)lua_tointeger(L, -1);
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
lcollision_world(lua_State *L) {
	struct collision_world *world = (struct collision_world *)lua_newuserdatauv(L, sizeof(struct collision_world), 0);

	world->w = NULL;
	world->logger = NULL;

	WorldSettings settings;

	if (lua_istable(L,1)) {
		const char *worldName = getstring(L, 1, "worldName");
		if (worldName) {
			settings.worldName = worldName;
		}
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
		getint(L, 1, "nbMaxContactManifoldsConvexShape", &settings.nbMaxContactManifoldsConvexShape);
		getint(L, 1, "nbMaxContactManifoldsConcaveShape", &settings.nbMaxContactManifoldsConcaveShape);
		getdecimal(L, 1, "cosAngleSimilarContactManifold", &settings.cosAngleSimilarContactManifold);

#ifdef IS_LOGGING_ACTIVE
		world->logger = new Logger;
		if (lua_getfield(L, 1, "logger") == LUA_TTABLE) {
			uint logLevelFlag = (uint)Logger::Level::Error;
			const char * level = getstring(L, -1, "Level");
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
			const char * format = getstring(L, -1, "Format");
			Logger::Format f = Logger::Format::Text;
			if (format) {
				switch(format[0]) {
				case 't':
				case 'T':
					break;
				case 'h':
				case 'H':
					f = Logger::Format::HTML;
					break;
				default:
					luaL_error(L, "Format should be Text/HTML");
					break;
				}
			}
			const char * filename = getstring(L, -1, "File");
			if (filename) {
				world->logger->addFileDestination(filename, logLevelFlag, f);
			} else {
				world->logger->addStreamDestination(std::cout, logLevelFlag, f);
			}
		}
		lua_pop(L,1);
#endif
	}

	world->w = new CollisionWorld(settings, world->logger);
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);

	return 1;
}

static int
lcollision_world_gc(lua_State *L) {
	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
	if (world->w) {
		delete world->w;
		world->w = NULL;
	}

#ifdef IS_LOGGING_ACTIVE
	if (world->logger) {
		delete world->logger;
		world->logger = NULL;
	}
#endif

	return 0;
}

static Transform
get_transform(lua_State *L, int index) {
	const float * pos = (const float *)lua_touserdata(L, index);
	const float * ori = (const float *)lua_touserdata(L, index+1);
	printf("pos = %p ori = %p\n", pos, ori);
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
	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);

	// index 2 , 3 should be float3 and float4
	Transform trans = get_transform(L, 2);
	CollisionBody *body = world->w->createCollisionBody(trans);
	lua_pushlightuserdata(L, (void *)body);
	return 1;
}

static int
ldestroyCollisionBody(lua_State *L) {
	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);

	world->w->destroyCollisionBody(body);
	return 0;
}

static int
lsetTransform(lua_State *L) {
//	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);

	Transform trans = get_transform(L, 3);

	body->setTransform(trans);

	return 0;	
}

static int
lgetAABB(lua_State *L) {
//	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
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

static int
laddCollisionShape(lua_State *L) {
//	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);
	CollisionShape *shape = (CollisionShape *)lua_touserdata(L, 3);

	Transform trans = get_transform(L, 4);

	ProxyShape* proxy = body->addCollisionShape(shape, trans);
	lua_pushlightuserdata(L, (void *)proxy);
	return 1;
}

static int
ldeleteShape(lua_State *L) {
	CollisionShape *shape = (CollisionShape *)lua_touserdata(L, 1);
	delete shape;
	return 0;
}

class luaOverlapCallback : public OverlapCallback {
	lua_State *L;
	bool hit;
public:
	luaOverlapCallback(lua_State *L) : L(L), hit(false) {}
	virtual ~luaOverlapCallback() {}
	bool isHit() const { return hit; }

	virtual void notifyOverlap(CollisionBody* collisionBody) {
		hit = true;
	}
};

static int
ltestOverlap(lua_State *L) {
	struct collision_world * world = (struct collision_world *)lua_touserdata(L, 1);
	CollisionBody *body = (CollisionBody*)lua_touserdata(L, 2);
	unsigned short categoryMaskBits = 0xFFFF;	// todo : support mask
	
	luaOverlapCallback cb(L);
	world->w->testOverlap(body, &cb, categoryMaskBits);
	lua_pushboolean(L, cb.isHit());
	return 1;
}

static int
lsphereShape(lua_State *L) {
	double radius = luaL_checknumber(L, 1);

	SphereShape * s = new SphereShape(radius);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

static int
lboxShape(lua_State *L) {
	double x = luaL_checknumber(L, 1);
	double y = luaL_optnumber(L, 2, x);
	double z = luaL_optnumber(L, 3, y);

	Vector3 halfExtents(x,y,z);
	BoxShape * s = new BoxShape(halfExtents);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

static int
lcapsuleShape(lua_State *L) {
	double radius = luaL_checknumber(L, 1);
	double height = luaL_checknumber(L, 2);

	CapsuleShape * s = new CapsuleShape(radius, height);
	lua_pushlightuserdata(L, (void *)s);

	return 1;
}

extern "C" {
	LUAMOD_API int
	luaopen_rp3d_core(lua_State* L) {
	luaL_Reg collision_world[] = {
		{ "body_create", lcreateCollisionBody },
		{ "body_destroy", ldestroyCollisionBody },
		{ "set_transform", lsetTransform },
		{ "get_aabb", lgetAABB },
		{ "add_shape", laddCollisionShape },
		{ "test_overlap", ltestOverlap },
		{ "__gc", lcollision_world_gc },
		{ NULL, NULL },
	};

	luaL_checkversion(L);

	if (sizeof(decimal) != sizeof(float)) {
		luaL_error(L, "decimal should be float");
	}

	lua_newtable(L);
	int lib_index = lua_gettop(L);

	// collision_world metatable
	luaL_newlib(L, collision_world);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	lua_pushvalue(L, -1);
	lua_setfield(L, lib_index, "collision_world_mt");

	lua_pushcclosure(L, lcollision_world, 1);
	lua_setfield(L, lib_index, "collision_world");

	luaL_Reg collision_shape[] = {
		{ "sphere", lsphereShape },
		{ "box", lboxShape },
		{ "capsule", lcapsuleShape },
		{ NULL, NULL },
	};

	luaL_newlib(L, collision_shape);
	lua_setfield(L, lib_index, "shape");
	lua_pushcfunction(L, ldeleteShape);
	lua_setfield(L, lib_index, "delete_shape");

	return 1;
}
}