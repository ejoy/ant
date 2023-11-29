
extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/offline/raw_skeleton.h>
#include <ozz/animation/offline/skeleton_builder.h>

#include <ozz/animation/runtime/skeleton.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/io/archive_traits.h>

using RawSkeleton = ozz::animation::offline::RawSkeleton;

struct hierarchy_tree {
	RawSkeleton * skl;
};

struct hierarchy {
	RawSkeleton::Joint *joint;
};

static inline struct hierarchy_tree*
get_tree(lua_State *L, int index){
	if (lua_getiuservalue(L, index, 1) != LUA_TTABLE) {
		luaL_error(L, "Missing cache in get_tree");
	}

	if (lua_geti(L, -1, 1) != LUA_TUSERDATA) {
		luaL_error(L, "Missing root in get_tree");
	}

	struct hierarchy_tree * tree = (struct hierarchy_tree *)lua_touserdata(L, -1);
	lua_pop(L, 2);

	return tree;
}

static int
ldelhtree(lua_State *L) {
	struct hierarchy_tree * tree = (struct hierarchy_tree *)lua_touserdata(L, 1);
	delete tree->skl;
	tree->skl = NULL;
	return 0;
}

RawSkeleton::Joint::Children *
get_children(lua_State *L, int index) {
	struct hierarchy * hnode = (struct hierarchy *)lua_touserdata(L, index);
	if (hnode->joint == NULL) {
		struct hierarchy_tree *tree = get_tree(L, 1);
		assert(tree);
		return &tree->skl->roots;
	} else {
		return &hnode->joint->children;
	}
}

static int
lhnode_childcount(lua_State *L) {
	RawSkeleton::Joint::Children *children = get_children(L, 1);
	lua_pushinteger(L, children->size());
	return 1;
}

static void
change_addr(lua_State *L, int cache_index, RawSkeleton::Joint *old_ptr, RawSkeleton::Joint *new_ptr) {
	if (lua_rawgetp(L, cache_index, (void *)old_ptr) == LUA_TUSERDATA) {
		struct hierarchy *h = (struct hierarchy *)lua_touserdata(L, -1);
		h->joint = new_ptr;
		lua_rawsetp(L, cache_index, (void *)new_ptr);
		lua_pushnil(L);
		lua_rawsetp(L, cache_index, (void *)old_ptr);
	} else {
		lua_pop(L, 1);
	}
}

static void init_transform(RawSkeleton::Joint::Children *c, size_t beg, size_t end) {
	for (auto b = beg; b < end; ++b) {
		c->at(b).transform.identity();
	}
}


static void
expand_children(lua_State *L, int index, RawSkeleton::Joint::Children *c, size_t n) {
	size_t old_size = c->size();
	if (old_size == 0) {
		c->resize(n);
		init_transform(c, 0, old_size);
		return;
	}
	RawSkeleton::Joint *old_ptr = &c->at(0);
	c->resize(n);
	init_transform(c, old_size, n);
	RawSkeleton::Joint *new_ptr = &c->at(0);
	if (old_ptr == new_ptr) {
		return;
	}
	if (lua_getiuservalue(L, index, 1) != LUA_TTABLE) {
		luaL_error(L, "Missing cache expand_children");
	}
	int cache_index = lua_gettop(L);
	size_t i;
	for (i=0;i<old_size;i++) {
		change_addr(L, cache_index, old_ptr+i, new_ptr+i);
	}
	lua_pop(L, 1);
}

static void
remove_child(lua_State *L, int index, RawSkeleton::Joint::Children * c, size_t child) {
	if (lua_getiuservalue(L, index, 1) != LUA_TTABLE) {
		luaL_error(L, "Missing cache");
	}
	int cache_index = lua_gettop(L);
	RawSkeleton::Joint *node = &c->at(child);
	if (lua_rawgetp(L, cache_index, (void *)node) == LUA_TUSERDATA) {
		struct hierarchy *h = (struct hierarchy *)lua_touserdata(L, -1);
		h->joint = NULL;
		lua_pushnil(L);
		// HIERARCHY_NODE nil
		lua_setiuservalue(L, -2, 1);
	}
	lua_pop(L, 1);
	lua_pushnil(L);
	lua_rawsetp(L, cache_index, (void *)node);

	size_t size = c->size();
	size_t i;
	for (i=child+1;i<size;i++) {
		node = &c->at(i);
		change_addr(L, cache_index, node, node-1);
	}
	c->erase(c->begin() + child);
}

static inline int
push_hierarchy_node(lua_State *L, RawSkeleton::Joint *joint){
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
		return luaL_error(L, "Missing cache lhnodeget");
	}

	if (lua_rawgetp(L, -1, (const void *)joint) != LUA_TUSERDATA) {
		lua_pop(L, 1);

		struct hierarchy * h = (struct hierarchy *)lua_newuserdatauv(L, sizeof(hierarchy), 1); // stack : hnode
		h->joint = joint;

		luaL_getmetatable(L, "HIERARCHY_NODE");		// stack : hnode, HIERARCHY_NODE, 
		lua_setmetatable(L, -2);					// stack : hnode,

		lua_pushvalue(L, -1);						// stack : hnode, hnode
		lua_rawsetp(L, -3, (const void *)joint);	// stack : hnode

		luaL_getmetatable(L, "HIERARCHY_CACHE");	// stack : hnode, HIERARCHY_CACHE
		lua_setiuservalue(L, -2, 1);					// stack : hnode ---> HIERARCHY_CACHE as hnode's user value		
	}

	return 1;
}

static inline void
fetch_srt(lua_State *L, int sidx, int ridx, int tidx, ozz::math::Transform &trans) {
	auto fetchdata = [L](int idx, auto &value) {
		if (!lua_isnoneornil(L, idx)) {
			luaL_checktype(L, idx, LUA_TLIGHTUSERDATA);
			const float* v = (const float*)lua_touserdata(L, idx);
			memcpy(&value.x, v, sizeof(value));
		}
	};
	fetchdata(sidx, trans.scale);
	fetchdata(ridx, trans.rotation);
	fetchdata(tidx, trans.translation);
}

static int
lhnode_addchild(lua_State *L) {
	RawSkeleton::Joint::Children * c = get_children(L, 1);
	size_t n = c->size();
	expand_children(L, 1, c, n + 1);

	RawSkeleton::Joint *joint = &(c->at(n));
	const char* name = luaL_checkstring(L, 2);
	joint->name = name;

	fetch_srt(L, 3, 4, 5, joint->transform);
	return push_hierarchy_node(L, joint);
}

static int
lhnode_removechild(lua_State *L) {
	RawSkeleton::Joint::Children * c = get_children(L, 1);
	const size_t whichchild = lua_tointeger(L, 2);
	const size_t numchild = c->size();
	if (0 <= whichchild && whichchild < numchild) {
		remove_child(L, 1, c, whichchild);		
	} else {
		luaL_error(L, "invalid child index:%d", whichchild);
	}
	return 0;
}

static int
lhnode_get_transform(lua_State *L) {
	auto hnode = (struct hierarchy *)luaL_checkudata(L, 1, "HIERARCHY_NODE");
	auto &trans = hnode->joint->transform;
	auto s = (float*)lua_touserdata(L, 2);
	auto r = (float*)lua_touserdata(L, 3);
	auto t = (float*)lua_touserdata(L, 4);

	auto copy_op = [](float *dst, const auto &v){
		assert(sizeof(v) < sizeof(float) * 16);
		memcpy(dst, &v, sizeof(v));
	};

	copy_op(s, trans.scale);
	copy_op(r, trans.rotation);
	copy_op(t, trans.translation);
	return 0;
}

static int
lhnode_set_transform(lua_State *L){
	auto hnode = (struct hierarchy *)luaL_checkudata(L, 1, "HIERARCHY_NODE");
	auto &t = hnode->joint->transform;
	t.scale = *((ozz::math::Float3*)lua_touserdata(L, 2));
	t.rotation = *(ozz::math::Quaternion*)lua_touserdata(L, 3);
	t.translation = *(ozz::math::Float3*)lua_touserdata(L, 4);
	return 0;
}

static int
lhnode_name(lua_State *L) {
	auto hnode = (struct hierarchy *)luaL_checkudata(L, 1, "HIERARCHY_NODE");
	lua_pushstring(L, hnode->joint->name.c_str());
	return 1;
}

static int
lhnode_set_name(lua_State *L){
	auto hnode = (struct hierarchy *)luaL_checkudata(L, 1, "HIERARCHY_NODE");
	const char* name = luaL_checkstring(L, 2);
	hnode->joint->name = name;
	return 0;
}

static size_t 
rawskeleton_size(const ozz::animation::offline::RawSkeleton::Joint::Children &joints){
	size_t buffersize = 0;
	for (const auto &j : joints){
		if (!j.children.empty()){
			buffersize += rawskeleton_size(j.children);
		}

		buffersize += j.name.size();
		buffersize += sizeof(j.transform);
	}

	return buffersize;
}

static int
lhnode_size(lua_State *L){
	luaL_checkudata(L, 1, "HIERARCHY_NODE");
	auto tree = get_tree(L, 2);	
	lua_pushinteger(L, rawskeleton_size(tree->skl->roots));
	return 1;
}

static int
lhnode_getchild(lua_State *L) {
	const size_t n = (int)lua_tointeger(L, 2);
	if (n <= 0) {
		return luaL_error(L, "Invalid children index %f", lua_tonumber(L, 2));
	}
	RawSkeleton::Joint::Children * c = get_children(L, 1);	
	if (n > c->size()) {
		return 0;
	}

	RawSkeleton::Joint *joint = &c->at(n - 1);
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
		return luaL_error(L, "Missing cache lhnodeget");
	}
	if (lua_rawgetp(L, -1, (const void *)joint) == LUA_TUSERDATA) {
		return 1;
	}
	lua_pop(L, 1);

	return push_hierarchy_node(L, joint);
}

int
linvalidnode(lua_State *L) {
	struct hierarchy * h = (struct hierarchy *)luaL_checkudata(L,1,"HIERARCHY_NODE");
	lua_pushboolean(L, h->joint == NULL);
	return 1;
}

int
lnewhierarchy(lua_State *L) {
	struct hierarchy * node = (struct hierarchy *)lua_newuserdatauv(L, sizeof(*node), 1);
	node->joint = NULL;
	luaL_getmetatable(L, "HIERARCHY_NODE");
	lua_setmetatable(L, -2);
	// stack: HIERARCHY_NODE

	lua_createtable(L,1,0);
	if (luaL_newmetatable(L, "HIERARCHY_CACHE")) {
		lua_pushstring(L, "v");
		lua_setfield(L, -2, "__mode");
	}
	lua_setmetatable(L, -2);

	// stack: HIERARCHY_NODE HIERARCHY_CACHE

	struct hierarchy_tree * tree = (struct hierarchy_tree *)lua_newuserdatauv(L, sizeof(*tree), 1);
	tree->skl = new RawSkeleton;
	if (luaL_newmetatable(L, "HIERARCHY_TREE")) {
		lua_pushcfunction(L, ldelhtree);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);

	lua_pushvalue(L, -1);
	lua_pushboolean(L, 1);
	// stack: HIERARCHY_NODE HIERARCHY_CACHE HIERARCHY_TREE HIERARCHY_TREE true
	lua_rawset(L, -4);	// HIERARCHY_CACHE[HIERARCHY_TREE] = true
	// stack: HIERARCHY_NODE HIERARCHY_CACHE HIERARCHY_TREE
	lua_rawseti(L, -2, 1);	// HIERARCHY_CACHE[1] = HIERARCHY_TREE

	lua_setiuservalue(L, -2, 1);	// HIERARCHY_CACHE -> uv of HIERARCHY_NODE
	
	// return HIERARCHY_NODE
	return 1;
}

ozz::animation::Skeleton *
build_hierarchy_data(lua_State *L, int index){
	int type = lua_type(L, index);

	if (type == LUA_TUSERDATA){
        struct hierarchy * hnode = (struct hierarchy *)luaL_checkudata(L, index, "HIERARCHY_NODE");
        if (hnode->joint != NULL){
            luaL_error(L, "Not root node!");
        }

        struct hierarchy_tree * tree = get_tree(L, 1);
        ozz::animation::offline::SkeletonBuilder builder;
        return builder(*(tree->skl)).release();
	}

	if (type == LUA_TTABLE){
		auto tlen = lua_rawlen(L, index);

		ozz::animation::offline::RawSkeleton rawskeleton;
		rawskeleton.roots.resize(tlen);
		for (size_t ii = 0; ii < tlen; ++ii){
			auto &joint = rawskeleton.roots[ii];
			lua_geti(L, 1, ii+1);{
				lua_getfield(L, -1, "name");
				joint.name = lua_tostring(L, -1);
				lua_pop(L, 1);

				auto get_table_value = [](lua_State *L, const char* name, float *v, int num){					
					lua_getfield(L, -1, name);
					for (int ii = 0; ii < num; ++ii){
						lua_geti(L, -1, ii+1);
						v[ii] = (float)lua_tonumber(L, -1);
						lua_pop(L, 1);
					}
					lua_pop(L, 1);
				};

				get_table_value(L, "s", &joint.transform.scale.x, 3);
				get_table_value(L, "r", &joint.transform.rotation.x, 4);
				get_table_value(L, "t", &joint.transform.translation.x, 3);		
			}
			lua_pop(L, 1);
		}

		ozz::animation::offline::SkeletonBuilder builder;
		return builder(rawskeleton).release();
	}

	luaL_error(L, "not support type, %d", type);
	return nullptr;
}

const char*
check_read_raw_skeleton(lua_State *L, ozz::io::IArchive& ia){
	if (ia.TestTag<ozz::animation::offline::RawSkeleton>()){
		lnewhierarchy(L);
		auto tree = get_tree(L, 1);
		ia >> *(tree->skl);
		
		return ozz::io::internal::Tag<const ozz::animation::offline::RawSkeleton>::Get();
	}
	return nullptr;
}


void
register_hierarchy_node(lua_State *L) {
	luaL_newmetatable(L, "HIERARCHY_NODE");	
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"__len", 			lhnode_childcount},
		{"add_child", 		lhnode_addchild},
		{"remove_child",	lhnode_removechild},
		{"get_child", 		lhnode_getchild},
		{"transform", 		lhnode_get_transform},
		{"set_transform", 	lhnode_set_transform},
		{"name", 			lhnode_name},
		{"set_name", 		lhnode_set_name},
		{"size", 			lhnode_size},
		{nullptr, 			nullptr},
	};

	luaL_setfuncs(L, l, 0);	
}