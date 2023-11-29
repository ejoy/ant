#include "hierarchy.h"
#include "../luabind/fastio.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/skeleton_utils.h>

#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/maths/soa_float4x4.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/io/archive_traits.h>
#include <ozz/base/io/stream.h>


#include <iostream>
#include <cstring>
#include <functional>
#include <unordered_map>

static inline ozz::animation::Skeleton*
get_ske(lua_State *L, int index = 1){
	auto builddata = (struct hierarchy_build_data*)luaL_checkudata(L, index, "HIERARCHY_BUILD_DATA");
	return builddata->skeleton;
}

static int
find_joint_index(const ozz::animation::Skeleton *ske, const char*name) {
	const auto& joint_names = ske->joint_names();
	for (int ii = 0; ii < (int)joint_names.size(); ++ii) {
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
	} else {
		luaL_error(L, "only support integer[joint index] or string[joint name], type : %d", type);
		return -1;
	}

	if (jointidx < 0 || jointidx >= (int)ske->num_joints()) {
		luaL_error(L, "invalid joint index : %d", jointidx);
		return -1;
	}
	return jointidx;
}

static int
lbuilddata_del(lua_State *L){
	struct hierarchy_build_data *builddata = (struct hierarchy_build_data*)lua_touserdata(L, 1);
	ozz::Delete(builddata->skeleton);
	builddata->skeleton = NULL;
	return 0;
}

static int
lbuilddata_len(lua_State *L){
	auto ske = get_ske(L);
	lua_pushinteger(L, ske->num_joints());
	return 1;
}

using serialize_skeop = std::function<void(const char*, ozz::animation::Skeleton*)>;

static int
lbuilddata_serialize(lua_State *L) {
	auto ske = get_ske(L);

	//TODO: implement a custom stream can remove one more memory copy
	ozz::io::MemoryStream ms;
	ozz::io::OArchive oa(&ms);
	oa << *ske;

	ozz::io::IArchive ia(&ms);
	std::string s; s.resize(ms.Size());
	ia.LoadBinary(s.data(), s.size());
	lua_pushlstring(L, s.data(), s.size());
	return 1;
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
	if (jointidx >= 0) {
		lua_pushinteger(L, jointidx + 1);
		return 1;
	}
	return 0;
}

static ozz::math::Float4x4
joint_matrix(const ozz::animation::Skeleton *ske, int jointidx) {
	auto poses = ske->joint_rest_poses();
	assert(0 <= jointidx && jointidx < ske->num_joints());
	
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
lbuilddata_joint(lua_State *L) {
	const auto ske = get_ske(L);
	const int jointidx = get_joint_index(L, ske, 2);
	auto *r = (float*)lua_touserdata(L, 3);

	const auto trans = joint_matrix(ske, jointidx);
	assert(sizeof(trans) <= sizeof(float) * 16);
	memcpy(r, &trans, sizeof(trans));
	return 0;
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
	bindpose* bpresult = (bindpose*)lua_touserdata(L, 2);

	ozz::animation::LocalToModelJob job;
	job.skeleton = ske;
	job.input = ske->joint_rest_poses();
	job.output = ozz::make_span(*bpresult);

	if (!job.Run()) {
		luaL_error(L, "build local to model failed");
	}
	return 0;
}

static int
lbuilddata_size(lua_State *L){
	auto ske = get_ske(L);

	size_t buffersize = 0;

	auto bind_poses = ske->joint_rest_poses();
	buffersize += bind_poses.size_bytes();
	buffersize += ske->joint_parents().size() * sizeof(uint16_t);

	auto names = ske->joint_names();
	for (size_t ii = 0; ii < names.size(); ++ii){
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

static void
register_hierarchy_builddata(lua_State *L) {
	if (luaL_newmetatable(L, "HIERARCHY_BUILD_DATA")) {
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		luaL_Reg l[] = {
			{"__gc",		lbuilddata_del},
			{"__len",		lbuilddata_len},
			{"serialize",	lbuilddata_serialize},
			{"isleaf",		lbuilddata_isleaf},
			{"parent",		lbuilddata_parent},
			{"isroot",		lbuilddata_isroot},
			{"joint_index", lbuilddata_jointindex},
			{"joint", 		lbuilddata_joint},
			{"joint_name", 	lbuilddata_jointname},
			{"bind_pose", 	lbuilddata_bindpose},
			{"size", 		lbuilddata_size},
			{nullptr, 		nullptr},
		};

		luaL_setfuncs(L, l, 0);
	}
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

extern int init_animation(lua_State *L);

extern ozz::animation::Skeleton * build_hierarchy_data(lua_State *L, int index);
extern void register_hierarchy_node(lua_State *L);
extern int lnewhierarchy(lua_State *L);
extern int linvalidnode(lua_State *L);

static int
lbuild(lua_State *L){
	auto ske = build_hierarchy_data(L, 1);
	if (!ske){
		luaL_error(L, "build hierarchy data failed");
	}
	auto h = create_builddata_userdata(L);
	h->skeleton = ske;
	return 1;
}

int init_skeleton(lua_State *L) {
	register_hierarchy_node(L);
	register_hierarchy_builddata(L);
	luaL_Reg l[] = {
		{ "new", 				lnewhierarchy },
		{ "invalid", 			linvalidnode },
		{ "build", 				lbuild},
		{ "node_metatable", 	lhnode_metatable},
		{ "builddata_metatable",lbuilddata_metatable},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

#include <bx/allocator.h>

class HeapAllocator : public ozz::memory::Allocator {
public:
	size_t count = 0;

protected:
	struct Header {
		void* unaligned;
		size_t size;
	};
	void* Allocate(size_t _size, size_t _alignment) {
		const size_t to_allocate = _size + sizeof(Header) + _alignment - 1;
		char* unaligned = reinterpret_cast<char*>(malloc(to_allocate));
		if (!unaligned) {
			return nullptr;
		}
		char* aligned = ozz::Align(unaligned + sizeof(Header), _alignment);
		assert(aligned + _size <= unaligned + to_allocate);
		Header* header = reinterpret_cast<Header*>(aligned - sizeof(Header));
		assert(reinterpret_cast<char*>(header) >= unaligned);
		header->unaligned = unaligned;
		header->size = to_allocate;
		count += to_allocate;
		return aligned;
	}
	void Deallocate(void* _block) {
		if (_block) {
			Header* header = reinterpret_cast<Header*>(reinterpret_cast<char*>(_block) - sizeof(Header));
			count -= header->size;
			free(header->unaligned);
		}
	}
};

HeapAllocator g_heap_allocator;

static int
lmemory(lua_State* L) {
	lua_pushinteger(L, g_heap_allocator.count);
	return 1;
}

class MemoryPtrStream : public ozz::io::Stream {
public:
	MemoryPtrStream(const std::string_view &s) : ms(s){}
	bool opened() const override { return !ms.empty(); }
	size_t Read(void* _buffer, size_t _size) override{
		if (moffset + _size > ms.size()){
			return 0;
		}
		memcpy(_buffer, ms.data() + moffset, _size);
		moffset += (int)_size;
		return _size;
	}

	int Seek(int _offset, Origin _origin) override {
		int origin = 0;
		switch (_origin) {
			case kCurrent: 	origin = moffset; 		break;
			case kEnd: 		origin = (int)ms.size();break;
			case kSet:		origin = 0;				break;
			default:								return -1;
		}

		int r = (int)origin + _offset;
		if (r < 0 || r > ms.size()){
			return -1;
		}
		moffset = r;
		return 0;
	}

	int Tell() const override{ return moffset; }
	size_t Size() const override { return ms.size();}

public:
	size_t Write(const void* _buffer, size_t _size) override { assert(false && "Not support"); return 0; }
private:
	const std::string_view ms;
	int moffset = 0;
};

static const char*
check_read_skeleton(lua_State *L, ozz::io::IArchive& ia){
	if (ia.TestTag<ozz::animation::Skeleton>()){
		struct hierarchy_build_data *builddata = create_builddata_userdata(L);
		builddata->skeleton = ozz::New<ozz::animation::Skeleton>();
		ia >> *builddata->skeleton;
		return ozz::io::internal::Tag<const ozz::animation::Skeleton>::Get();
	}
	return nullptr;
}

extern const char* check_read_raw_skeleton(lua_State *L, ozz::io::IArchive& ia);
extern const char* check_read_animation(lua_State *L, ozz::io::IArchive &ia);

static int
lload(lua_State *L){
	auto m = getmemory(L, 1);
	MemoryPtrStream ms(m);

	std::function<decltype(check_read_animation)> check_funcs[] = {
		check_read_animation, check_read_skeleton, check_read_raw_skeleton
	};
	
	const char* type = nullptr;
	for (auto f : check_funcs){
		ozz::io::IArchive ia(&ms);
		type = f(L, ia);
		if (type){
			break;
		}
		ms.Seek(0, ozz::io::Stream::kSet);
	}

	if (nullptr == type){
		return luaL_error(L, "Can not read ozz data");
	}
	lua_pushstring(L, type);
	return 2;
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy(lua_State *L) {
	luaL_checkversion(L);

	ozz::memory::SetDefaulAllocator(&g_heap_allocator);
	lua_newtable(L);
	init_skeleton(L);
	lua_setfield(L, -2, "skeleton");
	init_animation(L);
	lua_setfield(L, -2, "animation");
	lua_pushcfunction(L, lmemory);
	lua_setfield(L, -2, "memory");

	lua_pushcfunction(L, lload);
	lua_setfield(L, -2, "load");
	return 1;
}

}