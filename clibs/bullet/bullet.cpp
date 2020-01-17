#define LUA_LIB

#include "btBulletDynamicsCommon.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"

#include <lua.hpp>
#include <vector>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdlib>

static btVector3 get_vec(lua_State* L, int idx) {
    lua_geti(L, idx, 3);
    lua_geti(L, idx, 2);
    lua_geti(L, idx, 1);
    btScalar x = (btScalar)lua_tonumber(L, -1); lua_pop(L, 1);
    btScalar y = (btScalar)lua_tonumber(L, -1); lua_pop(L, 1);
    btScalar z = (btScalar)lua_tonumber(L, -1); lua_pop(L, 1);
    return btVector3(x, y, z);
}

static void push_vec(lua_State* L, const btVector3& v){
    lua_createtable(L, 3, 0);
    for (lua_Integer i = 1; i <= 3; ++i) {
        lua_pushnumber(L, v[i-1]);
        lua_seti(L, -2, i);
    }
}

struct collworld_node {
    btDefaultCollisionConfiguration *cfg;
    btCollisionDispatcher           *dispatcher;
    btDbvtBroadphase                *broadphase;
    btCollisionWorld                *world;
};

static  collworld_node* get_worldnode(lua_State *L, int idx) {
    luaL_checktype(L, idx, LUA_TUSERDATA);
    return (collworld_node*)lua_touserdata(L, idx);
}

template<typename T>
static inline void
check_delete(T* &p) {
    if (p) {
        delete p;
        p = nullptr;
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

static inline btHeightfieldTerrainShape *
create_terrain_shape(lua_State *L, int index) {
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

namespace object {
    static int create(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        auto shape = (btCollisionShape*)lua_touserdata(L, 2);
        if (shape == nullptr) {
            luaL_error(L, "invalid shape object");
            return 0;
        }
        btCollisionObject* coll_obj = new btCollisionObject;
        if (!lua_isnil(L, 3)){
            const int useridx = (int)lua_tointeger(L, 5);
            coll_obj->setUserIndex(useridx);
        }
        void *userdata = lua_isnoneornil(L, 4) ? nullptr : lua_touserdata(L, 6);
        coll_obj->setUserPointer(userdata);
        coll_obj->setCollisionShape(shape);
        if (shape->getShapeType() == TERRAIN_SHAPE_PROXYTYPE) {
            int flags = coll_obj->getCollisionFlags();
            flags |= btCollisionObject::CF_DISABLE_VISUALIZE_OBJECT;
            coll_obj->setCollisionFlags(flags);
        }
        worldnode->world->addCollisionObject(coll_obj);
        lua_pushlightuserdata(L, coll_obj);
        return 1;
    }
    static int destroy(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        auto obj = (btCollisionObject*)lua_touserdata(L, 2);
        if (obj->getWorldArrayIndex() != -1) {
            worldnode->world->removeCollisionObject(obj);
        }
        check_delete(obj);
        return 0;
    }
    static int get_aabb(lua_State *L){
        auto obj = (btCollisionObject*)lua_touserdata(L, 2);
        auto shape = obj->getCollisionShape();
        btVector3 min, max;
        shape->getAabb(obj->getWorldTransform(), min, max);
        push_vec(L, min);
        push_vec(L, max);
        return 2;
    }
    static int set_transform(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
        auto obj = (btCollisionObject*)lua_touserdata(L, 2);
        auto m = (const float*)lua_touserdata(L, 3);
        obj->setWorldTransform(*(btTransform*)m);
        worldnode->world->updateSingleAabb(obj);
        return 0;
    }
    static int set_useridx(lua_State *L){
        auto obj = (btCollisionObject*)lua_touserdata(L, 2);
        int useridx = (int)luaL_checkinteger(L, 3);
        obj->setUserIndex(useridx);
        return 0;
    }
}

namespace world {
    static int ray_test(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
        btVector3& from = *(btVector3*)lua_touserdata(L, 2);
        btVector3& to   = *(btVector3*)lua_touserdata(L, 3);
        btCollisionWorld::ClosestRayResultCallback result(from, to);
        worldnode->world->rayTest(from, to, result);
        lua_pushboolean(L, result.hasHit());
        if (!result.hasHit()) {
            return 1;
        }
        lua_createtable(L, 0, 7);
        lua_pushinteger(L, result.m_collisionObject->getUserIndex()); lua_setfield(L, -2, "useridx");
        lua_pushinteger(L, result.m_closestHitFraction);   lua_setfield(L, -2, "hit_fraction");
        push_vec(L,        result.m_hitPointWorld);        lua_setfield(L, -2, "hit_pt_in_WS");
        push_vec(L,        result.m_hitNormalWorld);       lua_setfield(L, -2, "hit_normal_in_WS");
        lua_pushinteger(L, result.m_collisionFilterGroup); lua_setfield(L, -2, "filter_group");
        lua_pushinteger(L, result.m_collisionFilterMask);  lua_setfield(L, -2, "filter_mask");
        lua_pushinteger(L, result.m_flags);                lua_setfield(L, -2, "flags");
        return 2;
    }
    struct ContactResultCallback : public btCollisionWorld::ContactResultCallback {
        virtual btScalar addSingleResult(btManifoldPoint&, const btCollisionObjectWrapper*, int, int, const btCollisionObjectWrapper*, int, int) {
            m_hit = true;
            return 1.f;
        }
        bool m_hit = false;
    };
    static int contact_test(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
        auto obj = (btCollisionObject*)lua_touserdata(L, 2);
        auto m = (const float*)lua_touserdata(L, 3);
        btTransform srt = obj->getWorldTransform();
        obj->setWorldTransform(*(btTransform*)m);
        ContactResultCallback result;
        worldnode->world->contactTest(obj, result);
        obj->setWorldTransform(srt);
        lua_pushboolean(L, result.m_hit);
        return 1;
    }
    static int create(lua_State *L) {
        collworld_node *worldnode = (collworld_node*)lua_newuserdatauv(L, sizeof(collworld_node), 0);
        if (luaL_newmetatable(L, "BULLET_WORLD_NODE")) {
            lua_pushvalue(L, -1);
            lua_setfield(L, -2, "__index");
            luaL_Reg l[] = {
                {"object_create",        object::create},
                {"object_destroy",       object::destroy},
                {"object_get_aabb",      object::get_aabb},
                {"object_set_transform", object::set_transform},
                {"object_set_useridx",   object::set_useridx},
                {"ray_test",             world::ray_test},
                {"contact_test",         world::contact_test},
                {nullptr, nullptr},
            };
            luaL_setfuncs(L, l, 0);
        }
        lua_setmetatable(L, -2);
        worldnode->cfg        = new btDefaultCollisionConfiguration;
        worldnode->dispatcher = new btCollisionDispatcher(worldnode->cfg);
        worldnode->broadphase = new btDbvtBroadphase();
        worldnode->world      = new btCollisionWorld(worldnode->dispatcher, worldnode->broadphase, worldnode->cfg);
        return 1;
    }
    static int destroy(lua_State *L) {
        auto worldnode = get_worldnode(L, 1);
        auto &collobjs = worldnode->world->getCollisionObjectArray();
        while (collobjs.size()) {
            auto collobj = collobjs[1];
            if (collobj->getWorldArrayIndex() != -1) {
                worldnode->world->removeCollisionObject(collobj);
            }
            collobj->setCollisionShape(nullptr);
        }
        check_delete(worldnode->world);
        check_delete(worldnode->cfg);
        check_delete(worldnode->dispatcher);
        check_delete(worldnode->broadphase);
        return 0;
    }
}

namespace shape {
    static int create_sphere(lua_State *L) {
        const btScalar radius = (btScalar)luaL_checknumber(L, 1);
        lua_pushlightuserdata(L, new btSphereShape(radius));
        return 1;
    }
    static int create_box(lua_State *L) {
        btVector3 size = get_vec(L, 1);
        lua_pushlightuserdata(L, new btBoxShape(size));
        return 1;
    }
    static int create_plane(lua_State *L) {
        btVector3 normal = get_vec(L, 1);
        const btScalar distance = (btScalar)luaL_checknumber(L, 2);
        lua_pushlightuserdata(L, new btStaticPlaneShape(normal, distance));
        return 1;
    }
    static int create_capsule(lua_State *L) {
        const btScalar radius = (btScalar)luaL_checknumber(L, 1);
        const btScalar height = (btScalar)luaL_checknumber(L, 2);
        const char* axis = luaL_optstring(L, 3, "Y");
        assert(strlen(axis) > 0);
        switch (axis[0]) {
        case 'X':
            lua_pushlightuserdata(L, new btCapsuleShapeX(radius, height));
            return 1;
        case 'Y':
            lua_pushlightuserdata(L, new btCapsuleShape(radius, height));
            return 1;
        case 'Z':
            lua_pushlightuserdata(L, new btCapsuleShapeZ(radius, height));
            return 1;
        default:
            return luaL_error(L, "invalid axis data:%d", axis);
        }
    }
    static int create_compound(lua_State *L) {
        lua_pushlightuserdata(L, new btCompoundShape());
        return 1;
    }
    static int create_terrain(lua_State *L) {
        lua_pushlightuserdata(L, create_terrain_shape(L, 2));
        return 1;
    }
    static int destroy(lua_State *L) {
        luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
        auto shape = (btCollisionShape*)lua_touserdata(L, 1);
        check_delete(shape);
        return 0;
    }
    static int compound_add(lua_State *L) {
        luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        auto compound = (btCompoundShape*)lua_touserdata(L, 1);
        auto child = (btCollisionShape*)lua_touserdata(L, 2);
        btTransform localTrans;
        localTrans.setIdentity();
        if (!lua_isnoneornil(L, 3)) {
            luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
            btVector3* pos = (btVector3*)lua_touserdata(L, 3);
            localTrans.setOrigin(*pos);
        }
        compound->addChildShape(localTrans, child);
        return 0;
    }
    static int compound_finish(lua_State* L) {
        luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
        auto compound = (btCompoundShape*)lua_touserdata(L, 1);
        return 0;
    }
}

extern "C" {
    LUAMOD_API int
    luaopen_bullet(lua_State *L) {
        luaL_Reg l[] = {
            {"world_create", world::create},
            {"world_destroy", world::destroy},
            {"shape_create_sphere", shape::create_sphere},
            {"shape_create_box", shape::create_box},
            {"shape_create_plane", shape::create_plane},
            {"shape_create_capsule", shape::create_capsule},
            {"shape_create_compound", shape::create_compound},
            {"shape_create_terrain", shape::create_terrain},
            {"shape_destroy", shape::destroy},
            {"shape_compound_add", shape::compound_add},
            {"shape_compound_finish", shape::compound_finish},
            {nullptr, nullptr},
        };
        luaL_newlib(L, l);
        return 1;
    }
}
