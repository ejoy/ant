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
#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/io/stream.h>


#include <iostream>
#include <cstring>
#include <functional>

using namespace ozz::animation::offline;

struct hierarchy_tree {
	RawSkeleton * skl;
};

struct hierarchy {
	RawSkeleton::Joint *joint;
};

static int
lbuilddata_del(lua_State *L){
	struct hierarchy_build_data *builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(builddata->skeleton);	
	builddata->skeleton = NULL;
	return 0;
}

static inline struct hierarchy_tree*
get_tree(lua_State *L, int index){
	if (lua_getuservalue(L, index) != LUA_TTABLE) {
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
	struct hierarchy_build_data* buildata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	lua_pushinteger(L, buildata->skeleton->num_joints());
	return 1;
}

using serialize_skeop = std::function<void(const char*, struct hierarchy_build_data*)>;

static inline int
serialize_skeleton(lua_State *L, serialize_skeop op) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);

	struct hierarchy_build_data* builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	if (builddata->skeleton == nullptr) {
		luaL_error(L, "data not build!");
	}

	const char* filepath = lua_tostring(L, 2);
	op(filepath, builddata);
	return 0;
}


static int
lbuilddata_save(lua_State *L) {
	return serialize_skeleton(L, [](auto filepath, auto builddata) {
		ozz::io::File ff(filepath, "wb");
		assert(ff.Exist(filepath));
		ozz::io::OArchive oa(&ff);
		oa << *builddata->skeleton;
	});
}

static int
lbuilddata_load(lua_State *L) {
	return serialize_skeleton(L, [](auto filepath, auto builddata) {
		ozz::io::File ff(filepath, "rb");
		assert(ff.opened());
		ozz::io::IArchive ia(&ff);
		ia >> *(builddata->skeleton);
	});
}

static bool
get_properties(lua_State *L, ozz::animation::Skeleton::JointProperties &p) {
	struct hierarchy_build_data* builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	auto ske = builddata->skeleton;
	if (ske) {
		int jointidx = (int)lua_tointeger(L, 2) - 1;
		if (jointidx >= ske->num_joints()) {
			luaL_error(L, "joint index invalid:%d, joint number:%d", jointidx, ske->num_joints());
		}
		p = ske->joint_properties()[jointidx];
		return true;
	}	
	return false;
}

static int lbuilddata_isleaf(lua_State *L) {
	ozz::animation::Skeleton::JointProperties properties;
	if (get_properties(L, properties)) {
		lua_pushboolean(L, properties.is_leaf);
		return 1;
	}	
	return 0;
}

static int lbuilddata_parent(lua_State *L) {
	ozz::animation::Skeleton::JointProperties properties;
	if (get_properties(L, properties)) {
		lua_pushinteger(L, properties.parent + 1);
		return 1;
	}
	return 0;
}

static int lbuilddata_isroot(lua_State *L) {
	ozz::animation::Skeleton::JointProperties properties;
	if (get_properties(L, properties)) {
		lua_pushboolean(L, properties.parent == ozz::animation::Skeleton::kNoParentIndex);
		return 1;
	}
	return 0;
}

static int
lbuilddata_get(lua_State *L){
	struct hierarchy_build_data* builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	switch (lua_type(L, 2)){
		case LUA_TNUMBER:{
			auto skeleton = builddata->skeleton;
			int idx = (int)lua_tointeger(L, 2) - 1;
			if (idx < 0)
				luaL_error(L, "get build data index out of range, idx is %d", idx);

			auto joints_num = skeleton->num_joints();
			if (idx >= joints_num)
				return 0;

			auto poses = skeleton->bind_pose();
			auto names = skeleton->joint_names();

			auto pose = poses[idx / 4];
			
			lua_createtable(L, 0, 4);
			
			lua_pushstring(L, names[idx]);
			lua_setfield(L, -2, "name");

			auto subidx = idx % 4;

			char buffer[4 * sizeof(float) + 15];	// 4 float and 16 bytes align
#define STACK_ALIGN(_ADDRESS) (float*)(((size_t)((char*)(_ADDRESS) + 15)) & ~0x0f)
			float *a_buffer = STACK_ALIGN(buffer);
			
			auto create_transform_elem = [=](auto name, auto num, auto v) {
				lua_createtable(L, num, 0);

				for (int ii = 0; ii < num; ++ii) {
					ozz::math::StorePtr(v[ii], a_buffer);
					lua_pushnumber(L, a_buffer[subidx]);
					lua_seti(L, -2, ii + 1);
				}
				lua_setfield(L, -2, name);
			};

			create_transform_elem("s", 3, &(pose.scale.x));
			create_transform_elem("r", 4, &(pose.rotation.x));
			create_transform_elem("t", 3, &(pose.translation.x));
			return 1;			
		}

		case LUA_TSTRING:{
			auto name = lua_tostring(L, 2);

			std::tuple<const char*, lua_CFunction> tpl[] = {
				std::make_tuple("isleaf", lbuilddata_isleaf),
				std::make_tuple("parent", lbuilddata_parent),
				std::make_tuple("isroot", lbuilddata_isroot),
			};

			for (auto& t : tpl) {
				auto &[n, func] = t;
				if (strcmp(n, name) == 0) {
					lua_pushcfunction(L, func);
					return 1;
				}
			}
		}
		default:
			return 0;
	}
}

static struct hierarchy_build_data*
create_builddata_userdata(lua_State *L){
	struct hierarchy_build_data *builddata = (struct hierarchy_build_data*)lua_newuserdata(L, sizeof(*builddata));

	if (luaL_newmetatable(L, "HIERARCHY_BUILD_DATA")){
		luaL_Reg l[] = {
			"__gc", lbuilddata_del,
			"__index", lbuilddata_get,
			"__len", lbuilddata_len,
			"__save", lbuilddata_save,
			"__load", lbuilddata_load,
			nullptr, nullptr,
		};

		luaL_setfuncs(L, l, 0);
	}
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
		builddata->skeleton = ozz::memory::default_allocator()->New<ozz::animation::Skeleton>();
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
lhnodechildren(lua_State *L) {
	RawSkeleton::Joint::Children *children = get_children(L, 1);
	lua_pushinteger(L, children->size());
	return 1;
}

static void
change_property(lua_State *L, RawSkeleton::Joint * joint, const char * p, int value_index) {
	if (strcmp(p, "name") == 0) {
		const char * v = luaL_checkstring(L, value_index);
		joint->name = v;
	} else if (strcmp(p, "transform") == 0) {
		luaL_checktype(L, value_index, LUA_TTABLE);

		joint->transform.identity();

		auto fetch_transform = [=](auto name, auto num, auto v, auto def_v) {
			int type = lua_getfield(L, -1, name);
			if (type == LUA_TTABLE){
				size_t tlen = lua_rawlen(L, -1);
				if (tlen == 1) {
					lua_geti(L, -1, 1);
					float n = (float)lua_tonumber(L, -1);
					lua_pop(L, 1);
					v[0] = v[1] = v[2] = n;
				}else{
					if (tlen != (size_t)num){
						luaL_error(L, "array len is %d, is not equal request len %d", tlen, num);
					}
					for (int ii = 0; ii < num; ++ii) {
						lua_geti(L, -1, ii + 1);
						v[ii] = (float)lua_tonumber(L, -1);
						lua_pop(L, 1);
					}	
				}		
			} else if (type == LUA_TNIL) {
				for (int ii = 0; ii < num; ++ii){
					v[ii] = def_v[ii];
				}				
			}

			lua_pop(L, 1);
		};

		auto scaledef = ozz::math::Float3::one();
		fetch_transform("s", 3, &joint->transform.scale.x, &scaledef.x);
		auto quaterniondef = ozz::math::Quaternion::identity();
		fetch_transform("r", 4, &joint->transform.rotation.x, &quaterniondef.x);
		auto translationdef = ozz::math::Float4::zero();
		fetch_transform("t", 3, &joint->transform.translation.x, &translationdef.x);
	} else {
		luaL_error(L, "Invalid property %s", p);
	}
}

static int
get_property(lua_State *L, RawSkeleton::Joint * joint, const char * p) {
	if (strcmp(p, "name") == 0) {
		lua_pushstring(L, joint->name.c_str());
		return 1;
	} else if (strcmp(p, "transform") == 0) {
		lua_createtable(L, 0, 3);

		auto push_transform = [=](auto name, auto num, auto v){
			lua_createtable(L, num, 0);
			for (int ii=0; ii < num; ++ii){
				lua_pushnumber(L, v[ii]);
				lua_seti(L, -2, ii+1);
			}
			lua_setfield(L, -2, name);
		};
		push_transform("s", 3, &joint->transform.scale.x);
		push_transform("r", 4, &joint->transform.rotation.x);
		push_transform("t", 3, &joint->transform.translation.x);
		return 1;
	} else {
		return luaL_error(L, "Invalid property %s", p);
	}
}

static void
set_properties(lua_State *L, RawSkeleton::Joint * joint, int values) {
	luaL_checktype(L, values, LUA_TTABLE);
	lua_pushnil(L);
	while (lua_next(L, values) != 0) {
		const char * p = luaL_checkstring(L, -2);
		change_property(L, joint, p, -1);
		lua_pop(L, 1);
	}
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
		c->at(b).transform = ozz::math::Transform::identity();
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
	if (lua_getuservalue(L, index) != LUA_TTABLE) {
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
	if (lua_getuservalue(L, index) != LUA_TTABLE) {
		luaL_error(L, "Missing cache");
	}
	int cache_index = lua_gettop(L);
	RawSkeleton::Joint *node = &c->at(child);
	if (lua_rawgetp(L, cache_index, (void *)node) == LUA_TUSERDATA) {
		struct hierarchy *h = (struct hierarchy *)lua_touserdata(L, -1);
		h->joint = NULL;
		lua_pushnil(L);
		// HIERARCHY_NODE nil
		lua_setuservalue(L, -2);
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

static int
lhnodeset(lua_State *L) {
	int key = lua_type(L, 2);
	if (key == LUA_TNUMBER) {
		// new child or change child
		size_t n = (int)lua_tointeger(L, 2);
		if (n <= 0) {
			return luaL_error(L, "Invalid children index %f", lua_tonumber(L, 2));
		}
		RawSkeleton::Joint::Children * c = get_children(L, 1);
		size_t size = c->size();
		if (n > size) {
			if (n == size + 1) {
				// new child
				expand_children(L, 1, c, n);
			} else {
				return luaL_error(L, "Out of range %d/%d", n, size);
			}
		}
		if (lua_isnil(L, 3)) {
			// remove child
			remove_child(L, 1, c, n-1);
		} else {
			RawSkeleton::Joint *node = &c->at(n-1);
			set_properties(L, node, 3);
		}
	} else if (key == LUA_TSTRING) {
		// change name or transform
		struct hierarchy * h = (struct hierarchy *)lua_touserdata(L,1);
		const char * property = lua_tostring(L, 2);
		RawSkeleton::Joint * node = h->joint;
		if (node == NULL) {
			return luaL_error(L, "Root has no property");
		}
		change_property(L, node, property, 3);
	} else {
		return luaL_error(L, "Invalid key type %s", lua_typename(L, key));
	}
	return 0;	
}

static inline void
push_hierarchy_node(lua_State *L, RawSkeleton::Joint *joint){
	struct hierarchy * h = (struct hierarchy *)lua_newuserdata(L, sizeof(*joint)); // stack : hnode
	h->joint = joint;
	
	luaL_getmetatable(L, "HIERARCHY_NODE");		// stack : hnode, HIERARCHY_NODE, 
	lua_setmetatable(L, -2);					// stack : hnode,

	lua_pushvalue(L, -1);						// stack : hnode, hnode
	lua_rawsetp(L, -3, (const void *)joint);	// stack : hnode

	luaL_getmetatable(L, "HIERARCHY_CACHE");	// stack : hnode, HIERARCHY_CACHE
	lua_setuservalue(L, -2);					// stack : hnode ---> HIERARCHY_CACHE as hnode's user value

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
lhnodeget(lua_State *L) {
	assert(lua_type(L, 1) == LUA_TUSERDATA);
	int keytype = lua_type(L, 2);
	if (keytype == LUA_TSTRING) {
		struct hierarchy * h = (struct hierarchy *)lua_touserdata(L, 1);
		RawSkeleton::Joint * joint = h->joint;
		if (joint == NULL) {			
			return luaL_error(L, "Invalid node");
		}
		const char * p = luaL_checkstring(L, 2);
		return get_property(L, joint, p);
	} else if (keytype == LUA_TNUMBER) {
		size_t n = (int)lua_tointeger(L, 2);
		if (n <= 0) {
			return luaL_error(L, "Invalid children index %f", lua_tonumber(L, 2));
		}
		RawSkeleton::Joint::Children * c = get_children(L, 1);
		size_t size = c->size();
		if (n > size) {
			return 0;
		}
		RawSkeleton::Joint *joint = &c->at(n-1);
		if (lua_getuservalue(L, 1) != LUA_TTABLE) {
			return luaL_error(L, "Missing cache lhnodeget");
		}
		if (lua_rawgetp(L, -1, (const void *)joint) == LUA_TUSERDATA) {
			return 1;
		}
		lua_pop(L, 1);

		push_hierarchy_node(L, joint);

		return 1;
	} else {
		return luaL_error(L, "Invalid key type %s", lua_typename(L, keytype));
	}
}

static int
lnewhierarchy(lua_State *L) {
	struct hierarchy * node = (struct hierarchy *)lua_newuserdata(L, sizeof(*node));
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

	struct hierarchy_tree * tree = (struct hierarchy_tree *)lua_newuserdata(L, sizeof(*tree));
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

	lua_setuservalue(L, -2);	// HIERARCHY_CACHE -> uv of HIERARCHY_NODE
	
	// return HIERARCHY_NODE
	return 1;
}

static int
lsave(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);

	if (luaL_getmetafield(L, 1, "__save") == LUA_TNIL)	
		luaL_error(L, "no __save in userdata metatable");

	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_call(L, 2, 0);
	return 0;// nothing to return
}

static int
lload(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);

	if (luaL_getmetafield(L, 1, "__load") == LUA_TNIL)
		luaL_error(L, "no __load in userdata metatable");

	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_call(L, 2, 1);

	return 1;	// will return the load result, userdata or table
}

extern "C" {

LUAMOD_API int
luaopen_hierarchy(lua_State *L) {
	luaL_checkversion(L);
	luaL_newmetatable(L, "HIERARCHY_NODE");
	lua_pushcfunction(L, lhnodeset);
	lua_setfield(L, -2, "__newindex");
	lua_pushcfunction(L, lhnodeget);
	lua_setfield(L, -2, "__index");
	lua_pushcfunction(L, lhnodechildren);
	lua_setfield(L, -2, "__len");
	lua_pushcfunction(L, lhnode_save);
	lua_setfield(L, -2, "__save");
	lua_pushcfunction(L, lhnode_load);
	lua_setfield(L, -2, "__load");

	luaL_Reg l[] = {
		{ "new", lnewhierarchy },
		{ "invalid", linvalidnode },
		{ "build", lbuild},
		{ "save", lsave},
		{ "load", lload },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

}
