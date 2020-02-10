#include "hierarchy.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/offline/raw_skeleton.h>
#include <ozz/animation/offline/skeleton_builder.h>
#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/skeleton_utils.h>

#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/maths/soa_float4x4.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/io/stream.h>


#include <iostream>
#include <cstring>
#include <functional>
#include <unordered_map>

using namespace ozz::animation::offline;

struct hierarchy_tree {
	RawSkeleton * skl;
};

struct hierarchy {
	RawSkeleton::Joint *joint;
};

static inline ozz::animation::Skeleton*
get_ske(lua_State *L, int index = 1){
	auto builddata = (struct hierarchy_build_data*)luaL_checkudata(L, index, "HIERARCHY_BUILD_DATA");
	return builddata->skeleton;
}

static int
find_joint_index(const ozz::animation::Skeleton *ske, const char*name) {
	const auto& joint_names = ske->joint_names();
	for (int ii = 0; ii < (int)joint_names.count(); ++ii) {
		if (strcmp(name, joint_names[ii]) == 0) {
			return ii;
		}
	}

	return -1;
}

static inline int
get_joint_index(lua_State *L, const ozz::animation::Skeleton *ske, int index) {
	int type = lua_type(L, 2);
	int jointidx = -1;
	if (type == LUA_TNUMBER) {
		jointidx = (int)lua_tointeger(L, 2) - 1;
	} else if (type == LUA_TSTRING) {
		const char* slotname = lua_tostring(L, 2);
		jointidx = find_joint_index(ske, slotname);
	} else {
		luaL_error(L, "only support integer[joint index] or string[joint name], type : %d", type);
		return -1;
	}

	if (jointidx < 0 || jointidx >= (int)ske->joint_bind_poses().size()) {
		luaL_error(L, "invalid joint index : %d", jointidx);
		return -1;
	}
	return jointidx;
}

static int
lbuilddata_del(lua_State *L){
	struct hierarchy_build_data *builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	OZZ_DELETE(ozz::memory::default_allocator(), builddata->skeleton);	
	builddata->skeleton = NULL;
	return 0;
}

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
lbuilddata_len(lua_State *L){
	auto ske = get_ske(L);
	lua_pushinteger(L, ske->num_joints());
	return 1;
}

using serialize_skeop = std::function<void(const char*, ozz::animation::Skeleton*)>;

static inline int
serialize_skeleton(lua_State *L, serialize_skeop op) {
	auto ske = get_ske(L);
	const char* filepath = luaL_checkstring(L, 2);
	op(filepath, ske);
	return 0;
}


static int
lbuilddata_save(lua_State *L) {
	return serialize_skeleton(L, [](auto filepath, auto ske) {
		ozz::io::File ff(filepath, "wb");
		assert(ff.Exist(filepath));
		ozz::io::OArchive oa(&ff);
		oa << *ske;
	});
}

static int
lbuilddata_load(lua_State *L) {
	return serialize_skeleton(L, [](auto filepath, auto ske) {
		ozz::io::File ff(filepath, "rb");
		assert(ff.opened());
		ozz::io::IArchive ia(&ff);
		ia >> *ske;
	});
}

static int lbuilddata_isleaf(lua_State *L) {
	auto ske = get_ske(L);
	auto jointidx = get_joint_index(L, ske, 2);
	lua_pushboolean(L, ozz::animation::IsLeaf(*ske, jointidx));
	return 1;
}

static int lbuilddata_parent(lua_State *L) {
	auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);

	auto parents = ske->joint_parents();
	auto parentid = parents[jointidx];
	lua_pushinteger(L, parentid + 1);
	return 1;
}

static int lbuilddata_isroot(lua_State *L) {
	auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);

	auto parents = ske->joint_parents();
	auto parentid = parents[jointidx];

	lua_pushboolean(L, parentid == ozz::animation::Skeleton::kNoParent);
	return 1;
}

static int
lbuilddata_jointindex(lua_State *L) {
	auto ske = get_ske(L);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* name = lua_tostring(L, 2);

	auto jointidx = find_joint_index(ske, name);
	if (jointidx < 0) {
		luaL_error(L, "not found joint idx, name:%s", name);
	}

	lua_pushinteger(L, jointidx + 1);
	return 1;
}

static ozz::math::Float4x4
joint_matrix(const ozz::animation::Skeleton *ske, int jointidx) {
	auto poses = ske->joint_bind_poses();
	assert(0 <= jointidx && jointidx < (int)poses.size());
	
	auto pose = poses[jointidx / 4];
	auto subidx = jointidx % 4;

	const ozz::math::SoaFloat4x4 local_soa_matrices = ozz::math::SoaFloat4x4::FromAffine(
		pose.translation, pose.rotation, pose.scale);

	// Converts to aos matrices.
	ozz::math::Float4x4 local_aos_matrices[4];
	ozz::math::Transpose16x16(&local_soa_matrices.cols[0].x,
		local_aos_matrices->cols);

	return local_aos_matrices[subidx];
}

static int
lbuilddata_jointmatrix(lua_State *L) {
	const auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);

	const auto trans = joint_matrix(ske, jointidx);
	auto* p = lua_newuserdatauv(L, sizeof(trans), 0);
	memcpy(p, &trans, sizeof(trans));
	return 1;
}

static int
lbuilddata_jointpos(lua_State *L){
	const auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);

	const auto trans = joint_matrix(ske, jointidx);

	auto *p = lua_newuserdatauv(L, sizeof(ozz::math::SimdFloat4), 0);
	memcpy(p, &trans.cols[3], sizeof(ozz::math::SimdFloat4));
	return 1;
}

static int
lbuilddata_jointname(lua_State *L){
	const auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);

	auto name = ske->joint_names()[jointidx];

	lua_pushstring(L, name);
	return 1;
}

static int
lbuilddata_bindpose(lua_State *L) {
	auto ske = get_ske(L);

	luaL_checktype(L, 2, LUA_TUSERDATA);
	bind_pose* bpresult = (bind_pose*)lua_touserdata(L, 2);

	ozz::animation::LocalToModelJob job;
	job.skeleton = ske;
	job.input = ske->joint_bind_poses();
	job.output = ozz::make_range(bpresult->pose);

	if (!job.Run()) {
		luaL_error(L, "build local to model failed");
	}
	return 0;
}

static int
lbuilddata_size(lua_State *L){
	auto ske = get_ske(L);

	size_t buffersize = 0;

	auto bind_poses = ske->joint_bind_poses();
	buffersize += bind_poses.size() * sizeof(*bind_poses.begin);
	buffersize += ske->joint_parents().size() * sizeof(uint16_t);

	auto names = ske->joint_names();
	for (size_t ii = 0; ii < names.count(); ++ii){
		buffersize += strlen(names[ii]);
	}

	lua_pushinteger(L, buffersize);
	return 1;
}

static struct hierarchy_build_data*
create_builddata_userdata(lua_State *L){
	struct hierarchy_build_data *builddata = (struct hierarchy_build_data*)lua_newuserdatauv(L, sizeof(*builddata), 0);

	luaL_getmetatable(L, "HIERARCHY_BUILD_DATA");
	lua_setmetatable(L, -2);

	return builddata;
}

static int 
lbuild(lua_State *L){
	int type = lua_type(L, 1);

	if (type == LUA_TUSERDATA){
		struct hierarchy * hnode = (struct hierarchy *)lua_touserdata(L, 1);
		if (hnode->joint != NULL){
			luaL_error(L, "Not root node!");
		}

		struct hierarchy_tree * tree = get_tree(L, 1);
		struct hierarchy_build_data *builddata = create_builddata_userdata(L);

		ozz::animation::offline::SkeletonBuilder builder;
		builddata->skeleton = builder(*(tree->skl));	
		return 1;
	}

	if (type == LUA_TTABLE){
		struct hierarchy_build_data *builddata = create_builddata_userdata(L);
		auto tlen = lua_rawlen(L, 1);

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
		builddata->skeleton = builder(rawskeleton);
		return 1;
	}

	if (type == LUA_TSTRING) {
		const char* filepath = lua_tostring(L, 1);
		struct hierarchy_build_data *builddata = create_builddata_userdata(L);
		builddata->skeleton = OZZ_NEW(ozz::memory::default_allocator(), ozz::animation::Skeleton);
		ozz::io::File ff(filepath, "rb");
		if (!ff.opened()) {
			luaL_error(L, "could not open file : %s", filepath);
		}
		ozz::io::IArchive ia(&ff);
		ia >> *builddata->skeleton;

		return 1;
	}

	luaL_error(L, "not support type, %d", type);
	return 0;
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

static int
linvalidnode(lua_State *L) {
	struct hierarchy * h = (struct hierarchy *)luaL_checkudata(L,1,"HIERARCHY_NODE");
	lua_pushboolean(L, h->joint == NULL);
	return 1;
}


using serialize_op = std::function<void(const char*, struct hierarchy_tree *tree)>;

static inline int
serialize_rawskeleton(lua_State *L, serialize_op op) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);

	struct hierarchy * hnode = (struct hierarchy *)lua_touserdata(L, 1);
	if (hnode->joint != NULL) {
		luaL_error(L, "need hierarchy root node");
	}

	struct hierarchy_tree * tree = get_tree(L, 1);

	const char* filepath = lua_tostring(L, 2);
	op(filepath, tree);
	return 0;
}

static int
lhnode_save(lua_State *L) {
	return serialize_rawskeleton(L, [](const char* filepath, struct hierarchy_tree *tree) {
		ozz::io::File ff(filepath, "wb");		
		ozz::io::OArchive oa(&ff);
		oa << *tree->skl;
	});

	return 0;
}

static int
lhnode_load(lua_State *L) {
	return serialize_rawskeleton(L, [](const char* filepath, struct hierarchy_tree *tree) {
		ozz::io::File ff(filepath, "rb");
		assert(ff.opened());
		
		ozz::io::IArchive ia(&ff);
		ia >> *tree->skl;
	});
}

static int
lnewhierarchy(lua_State *L) {
	struct hierarchy * node = (struct hierarchy *)lua_newuserdatauv(L, sizeof(*node), 0);
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

static inline void
fetch_srt(lua_State *L, int sidx, int ridx, int tidx, ozz::math::Transform &trans) {
	auto fetchdata = [L](int idx, auto &value) {
		if (!lua_isnil(L, idx)) {
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
	const int top = lua_gettop(L);

	RawSkeleton::Joint::Children * c = get_children(L, 1);
	size_t n = c->size();
	expand_children(L, 1, c, n + 1);

	RawSkeleton::Joint *joint = &(c->at(n));
	const char* name = luaL_checkstring(L, 2);
	joint->name = name;

	switch (top) {
	case 2:
		break;
	case 5:
		fetch_srt(L, 3, 4, 5, joint->transform);
		break;
	default:
		luaL_error(L, "invalid argument number:%d, need argument like: ([node], [name], opt[s], opt[r], opt[t])", top);
	}

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
lhnode_transform(lua_State *L) {
	const int top = lua_gettop(L);

	luaL_checkudata(L, 1, "HIERARCHY_NODE");
	struct hierarchy * hnode = (struct hierarchy *)lua_touserdata(L, 1);
	auto trans = hnode->joint->transform;
	if (top == 1) {		
		lua_pushlightuserdata(L, &(trans.scale.x));
		lua_pushlightuserdata(L, &(trans.rotation.x));
		lua_pushlightuserdata(L, &(trans.translation.x));

		return 3;
	} 
	
	fetch_srt(L, 2, 3, 4, trans);
	return 0;
}

static int
lhnode_name(lua_State *L) {
	const int top = lua_gettop(L);
	luaL_checkudata(L, 1, "HIERARCHY_NODE");

	struct hierarchy * hnode = (struct hierarchy *)lua_touserdata(L, 1);
	if (top == 1) {
		lua_pushstring(L, hnode->joint->name.c_str());
		return 1;
	}

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

// static int
// lhnode_getnode(lua_State *L) {
// 	const size_t n = (int)lua_tointeger(L, 2);
// 	if (n <= 0) {
// 		return luaL_error(L, "Invalid children index %f", lua_tonumber(L, 2));
// 	}
// 	RawSkeleton::Joint::Children * c = get_children(L, 1);	
// 	if (n > c->size()) {
// 		return 0;
// 	}

// 	RawSkeleton::Joint *joint = &c->at(n - 1);
// 	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
// 		return luaL_error(L, "Missing cache lhnodeget");
// 	}
// 	if (lua_rawgetp(L, -1, (const void *)joint) == LUA_TUSERDATA) {
// 		return 1;
// 	}
// 	lua_pop(L, 1);

// 	return push_hierarchy_node(L, joint);
// }

static void
register_hierarchy_builddata(lua_State *L) {
	if (luaL_newmetatable(L, "HIERARCHY_BUILD_DATA")) {
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		luaL_Reg l[] = {
			{"__gc", lbuilddata_del},
			{"__len", lbuilddata_len},
			{"save", lbuilddata_save},
			{"load", lbuilddata_load},
			{"isleaf", lbuilddata_isleaf},
			{"parent", lbuilddata_parent},
			{"isroot", lbuilddata_isroot},
			{"joint_index", lbuilddata_jointindex},
			{"joint_matrix", lbuilddata_jointmatrix},
			{"joint_pos", lbuilddata_jointpos},
			{"joint_name", lbuilddata_jointname},
			{"bind_pose", lbuilddata_bindpose},
			{"size", lbuilddata_size},
			{nullptr, nullptr},
		};

		luaL_setfuncs(L, l, 0);
	}
}

static void
register_hierarchy_node(lua_State *L) {
	luaL_newmetatable(L, "HIERARCHY_NODE");	
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"__len", lhnode_childcount},
		{"save", lhnode_save},
		{"load", lhnode_load},
		{"add_child", lhnode_addchild},
		{"remove_child", lhnode_removechild},
		{"transform", lhnode_transform,	},
		{"name", lhnode_name},
		{"size", lhnode_size},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);	
}

static int
lhnode_metatable(lua_State *L) {
	luaL_getmetatable(L, "HIERARCHY_NODE");
	return 1;
}

static int
lbuilddata_metatable(lua_State *L) {
	luaL_getmetatable(L, "HIERARCHY_BUILD_DATA");
	return 1;
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy(lua_State *L) {	
	luaL_checkversion(L);
	register_hierarchy_node(L);
	register_hierarchy_builddata(L);

	luaL_Reg l[] = {
		{ "new", lnewhierarchy },
		{ "invalid", linvalidnode },
		{ "build", lbuild},
		{ "node_metatable", lhnode_metatable},
		{ "builddata_metatable", lbuilddata_metatable},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

}