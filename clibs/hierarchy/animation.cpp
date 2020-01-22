#define LUA_LIB
#include <lua.hpp>

#include "hierarchy.h"
#include "meshbase/meshbase.h"

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/blending_job.h>
#include <ozz/animation/runtime/skeleton.h>

#include <ozz/geometry/runtime/skinning_job.h>
#include <ozz/base/platform.h>

#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/maths/soa_float4x4.h>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/containers/vector.h>
#include <ozz/base/maths/math_ex.h>

#include <../samples/framework/mesh.h>

// glm
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

// stl
#include <string>
#include <cstring>
#include <algorithm>
#include <sstream>

template <typename T>
class luaClass {
protected:
	typedef luaClass<T> base_type;
	template <typename ...Args>
	static T* constructor(lua_State* L, Args ...args) {
		T* o = (T*)lua_newuserdatauv(L, sizeof(T), 0);
		new (o) T(args...);
		if (luaL_newmetatable(L, kLuaName)) {
			lua_pushvalue(L, -1);
			lua_setfield(L, -2, "__index");
			luaL_Reg l[] = {
				{"__gc", destructor},
				{nullptr, nullptr},
			};
			luaL_setfuncs(L, l, 0);
		}
		lua_setmetatable(L, -2);
		return o;
	}
	static void set_method(lua_State* L, luaL_Reg l[]) {
		if (lua_getmetatable(L, -1)) {
			luaL_setfuncs(L, l, 0);
			lua_pop(L, 1);
		}
	}
private:
	static const char kLuaName[];
	static int destructor(lua_State* L) {
		get(L, 1)->~T();
		return 0;
	}
public:
	static T* get(lua_State* L, int idx) {
		return (T*)luaL_testudata(L, idx, kLuaName);
	}
};
#define REGISTER_LUA_CLASS(C) template<> const char luaClass<C>::kLuaName[] = #C;

struct ozzJointRemap : public luaClass<ozzJointRemap> {
	ozz::Vector<uint16_t>::Std joints;
	ozzJointRemap()
	: joints()
	{ }
	~ozzJointRemap()
	{ }

	static int create(lua_State* L) {
		ozzJointRemap* self = base_type::constructor(L);
		switch (lua_type(L, 1)) {
		case LUA_TTABLE: {
			size_t n = (size_t)lua_rawlen(L, 1);
			self->joints.resize(n);
			for (size_t i = 0; i < n; ++i){
				lua_geti(L, 1, i+1);
				self->joints[i] = (uint16_t)luaL_checkinteger(L, -1);
				lua_pop(L, 1);
			}
			break;
		}
		case LUA_TLIGHTUSERDATA: {
			const size_t jointnum = (size_t)luaL_checkinteger(L, 2);
			self->joints.resize(jointnum);
			const uint16_t *p = (const uint16_t*)lua_touserdata(L, 1);
			memcpy(&self->joints.front(), p, jointnum * sizeof(uint16_t));
			break;
		}
		default:
			return luaL_error(L, "not support type in argument 1");
		}
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzJointRemap)

template<typename DataType>
struct vertex_data {
	struct data_stride {
		typedef DataType Type;
		DataType* data;
		uint32_t offset;
		uint32_t stride;
	};

	data_stride positions;
	data_stride normals;
	data_stride tangents;
};

struct in_vertex_data : public vertex_data<const void> {
	data_stride joint_weights;
	data_stride joint_indices;
};

typedef vertex_data<void> out_vertex_data;

template <typename DataStride>
static void
read_data_stride(lua_State *L, const char* name, int index, DataStride &ds){
	const int type = lua_getfield(L, index, name);
	if (type != LUA_TNIL)
	{
		lua_geti(L, -1, 1);
		const int type = lua_type(L, -1);
		switch (type){
		case LUA_TSTRING: ds.data = (typename DataStride::Type*)lua_tostring(L, -1); break;
		case LUA_TLIGHTUSERDATA:
		case LUA_TUSERDATA: ds.data = (typename DataStride::Type*)lua_touserdata(L, -1); break;
		default:
			luaL_error(L, "not support data type in data stride, only string and userdata is support, type:%d", type);
			return;
		}
		lua_pop(L, 1);

		lua_geti(L, -1, 2);
		ds.offset = (uint32_t)lua_tointeger(L, -1) - 1;
		lua_pop(L, 1);

		lua_geti(L, -1, 3);
		ds.stride = (uint32_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
}

template<typename DataType>
static void
read_vertex_data(lua_State* L, int index, vertex_data<DataType>& vd) {
	read_data_stride(L, "POSITION", index, vd.positions);
	read_data_stride(L, "NORMAL", index, vd.normals);
	read_data_stride(L, "TANGENT", index, vd.tangents);
}

static void
read_in_vertex_data(lua_State *L, int index, in_vertex_data &vd){
	read_vertex_data(L, index, vd);
	read_data_stride(L, "WEIGHT", index, vd.joint_weights);
	read_data_stride(L, "INDICES", index, vd.joint_indices);
}

template<typename T, typename DataT>
static void
fill_skinning_job_field(uint32_t num_vertices, const DataT &d, ozz::Range<T> &r, size_t &stride) {
	const uint8_t* begin_data = (const uint8_t*)d.data + d.offset;
	r.begin = (T*)(begin_data);
	r.end	= (T*)(begin_data + d.stride * num_vertices);
	stride = d.stride;
}

static void
build_skinning_matrices(bind_pose *skinning_matrices, 
	const bind_pose* current_pose, 
	const bind_pose* inverse_bind_matrices, 
	const ozzJointRemap *jarray){
	if (jarray){
		assert(jarray->joints.size() == inverse_bind_matrices->pose.size());
		for (size_t ii = 0; ii < jarray->joints.size(); ++ii){
			skinning_matrices->pose[ii] = current_pose->pose[jarray->joints[ii]] * inverse_bind_matrices->pose[ii];
		}
	} else {
		assert(skinning_matrices->pose.size() == inverse_bind_matrices->pose.size() &&
			skinning_matrices->pose.size() == current_pose->pose.size());
		for (size_t ii = 0; ii < inverse_bind_matrices->pose.size(); ++ii){
			skinning_matrices->pose[ii] = current_pose->pose[ii] * inverse_bind_matrices->pose[ii];
		}
	}
}

static int
lbuild_skinning_matrices(lua_State *L){
	auto skinning_matrices = (bind_pose*)luaL_checkudata(L, 1, "OZZ_BIND_POSE");
	auto current_bind_pose = (bind_pose*)luaL_checkudata(L, 2, "OZZ_BIND_POSE");
	auto inverse_bind_matrices = (bind_pose*)luaL_checkudata(L, 3, "OZZ_BIND_POSE");
	const ozzJointRemap *jarray = lua_isnoneornil(L, 4) ? nullptr : ozzJointRemap::get(L, 4);
	if (skinning_matrices->pose.size() < inverse_bind_matrices->pose.size()){
		return luaL_error(L, "invalid skinning matrices and inverse bind matrices, skinning matrices must larger than inverse bind matrices");
	}
	build_skinning_matrices(skinning_matrices, current_bind_pose, inverse_bind_matrices, jarray);
	return 0;
}

static int
lmesh_skinning(lua_State *L){
	bind_pose *skinning_matrices = (bind_pose*)luaL_checkudata(L, 1, "OZZ_BIND_POSE");

	luaL_checktype(L, 2, LUA_TTABLE);
	in_vertex_data vd = {0};
	read_in_vertex_data(L, 2, vd);

	luaL_checktype(L, 3, LUA_TTABLE);
	out_vertex_data ovd = {0};
	read_vertex_data(L, 3, ovd);

	luaL_checktype(L, 4, LUA_TNUMBER);
	const uint32_t num_vertices = (uint32_t)lua_tointeger(L, 4);

	const uint32_t influences_count = (uint32_t)luaL_optinteger(L, 5, 4);

	ozz::geometry::SkinningJob skinning_job;
	skinning_job.vertex_count = num_vertices;
	skinning_job.influences_count = influences_count;
	skinning_job.joint_matrices = ozz::make_range(skinning_matrices->pose);
	
	assert(vd.positions.data && "skinning system must provide 'position' attribute");

	fill_skinning_job_field(num_vertices, vd.positions, skinning_job.in_positions, skinning_job.in_positions_stride);
	fill_skinning_job_field(num_vertices, ovd.positions, skinning_job.out_positions, skinning_job.out_positions_stride);

	if (vd.normals.data) {
		fill_skinning_job_field(num_vertices, vd.normals, skinning_job.in_normals, skinning_job.in_normals_stride);
	}

	if (ovd.normals.data) {
		fill_skinning_job_field(num_vertices, ovd.normals, skinning_job.out_normals, skinning_job.out_normals_stride);
	}
	
	if (vd.tangents.data) {
		fill_skinning_job_field(num_vertices, vd.tangents, skinning_job.in_tangents, skinning_job.in_tangents_stride);
	}

	if (ovd.tangents.data) {
		fill_skinning_job_field(num_vertices, ovd.tangents, skinning_job.out_tangents, skinning_job.out_tangents_stride);
	}

	if (influences_count > 1) {
		assert(vd.joint_weights.data && "joint weight data is not valid!");
		fill_skinning_job_field(num_vertices, vd.joint_weights, skinning_job.joint_weights, skinning_job.joint_weights_stride);
	}
		
	assert(vd.joint_indices.data && "skinning job must provide 'indices' attribute");
	fill_skinning_job_field(num_vertices, vd.joint_indices, skinning_job.joint_indices, skinning_job.joint_indices_stride);

	if (!skinning_job.Run()) {
		luaL_error(L, "running skinning failed!");
	}

	return 0;
}

static inline void
create_joint_table(lua_State *L, const ozz::math::Float4x4 &joint) {
	lua_createtable(L, 16, 0);
	for (auto icol = 0; icol < 4; ++icol) {
		for (auto ii = 0; ii < 4; ++ii) {
			const float* col = (const float*)(&(joint.cols[icol]));
			lua_pushnumber(L, col[ii]);
			lua_seti(L, -2, icol * 4 + ii + 1);
		}
	}
}

static int
lbp_result_init(lua_State *L){
	size_t size;
	const char* buffer = luaL_checklstring(L, 1, &size);
	float* dstbuffer = (float*)lua_touserdata(L, 2);
	memcpy(dstbuffer, buffer, size);
	return 0;
}

static int
lbp_result_joint(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bind_pose * result = (bind_pose*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TNUMBER);
	const size_t idx = (size_t)lua_tointeger(L, 2) - 1;
	const auto joint_count = result->pose.size();

	if (idx >= joint_count) {
		luaL_error(L, "invalid index:%d, joints count:%d", idx, joint_count);
	}

	auto &joint = result->pose[idx];
	
	if (lua_isnoneornil(L, 3)){
		auto p = &(joint.cols[0]);
		lua_pushlightuserdata(L, (void*)p);
		return 1;
	}

	auto intype = lua_type(L, 3);
	const ozz::math::Float4x4 *inputdata = nullptr;
	if (intype == LUA_TLIGHTUSERDATA || intype == LUA_TUSERDATA){
		inputdata = (const ozz::math::Float4x4*)lua_touserdata(L, 3);
	} else if (intype == LUA_TSTRING){
		size_t size;
		inputdata = (const ozz::math::Float4x4*)lua_tolstring(L, 3, &size);
		if (sizeof(ozz::math::Float4x4) != size){
			return luaL_error(L, "invalid string data size:%d, not match joint data size:%d", size, sizeof(joint));
		}
	}

	if (inputdata){
		joint = *inputdata;
	}
	
	return 0;
}

static int
lbp_result_joints(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	const bind_pose * result = (bind_pose*)lua_touserdata(L, 1);

	auto jointcount = result->pose.size();
	lua_createtable(L, (int)jointcount, 0);

	for (size_t ii = 0; ii < jointcount; ++ii) {
		create_joint_table(L, result->pose[ii]);
		lua_seti(L, -2, ii + 1);
	}
	return 1;
}

static int
lbp_result_count(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	const bind_pose * result = (bind_pose*)lua_touserdata(L, 1);

	lua_pushinteger(L, result->pose.size());
	return 1;
}

static int
lbp_result_transform(lua_State *L){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bind_pose * result = (bind_pose*)lua_touserdata(L, 1);

	auto mat = (const ozz::math::Float4x4*)lua_touserdata(L, 2);
	auto except_root = lua_isnoneornil(L, 3) ? false : lua_toboolean(L, 3);

	for (size_t ii = (except_root ? 1 : 0); ii < result->pose.size(); ++ii){
		result->pose[ii] = *mat * result->pose[ii];
	}
	
	return 0;
}

static int
ldel_bpresult(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bind_pose *result = (bind_pose *)lua_touserdata(L, 1);	
	result->pose.~vector();
	return 0;
}

static int
lnew_bind_pose(lua_State *L) {
	luaL_checktype(L, 1, LUA_TNUMBER);
	const size_t numjoints = (size_t)lua_tointeger(L, 1);

	if (numjoints <= 0) {
		luaL_error(L, "joints number should be > 0");
		return 0;
	}

	size_t initdata_size = 0;
	const float* initdata = nullptr;

	if (!lua_isnoneornil(L, 2)){
		switch (lua_type(L, 2)){
			case LUA_TSTRING: 
				initdata = (const float*)lua_tolstring(L, 2, &initdata_size); 
				if (initdata_size != sizeof(ozz::math::Float4x4) * numjoints){
					return luaL_error(L, "init data size is not valid, need:%d", sizeof(ozz::math::Float4x4) * numjoints);
				}
			break;
			case LUA_TUSERDATA:
			case LUA_TLIGHTUSERDATA:
				initdata = (const float*)lua_touserdata(L, 2);
				initdata_size = numjoints * sizeof(ozz::math::Float4x4);
			break;
			default:
			return luaL_error(L, "argument 2 is not support type, only support string/userdata/light userdata");
		}
	} 

	bind_pose *result = (bind_pose*)lua_newuserdatauv(L, sizeof(bind_pose), 0);
	luaL_getmetatable(L, "OZZ_BIND_POSE");
	lua_setmetatable(L, -2);
	new(&result->pose)bind_pose::bind_pose_type(numjoints);

	if (initdata){
		memcpy(&result->pose[0], initdata, initdata_size);
	}

	return 1;
}

struct ozzAllocator : public luaClass<ozzAllocator> {
	void* v;
	ozzAllocator(size_t size, size_t alignment)
	: v(ozz::memory::default_allocator()->Allocate(size, alignment))
	{ }
	~ozzAllocator() {
		ozz::memory::default_allocator()->Deallocate(v);
	}

	static int lpointer(lua_State* L) {
		lua_pushlightuserdata(L, base_type::get(L, 1)->v);
		return 1;
	}
	static int create(lua_State* L) {
		const size_t sizebytes = (size_t)luaL_checkinteger(L, 1);
		const size_t aligned = (size_t)luaL_optinteger(L, 2, 4);
		base_type::constructor(L, sizebytes, aligned);
		luaL_Reg l[] = {
			{"pointer", lpointer},
			{nullptr, nullptr},
		};
		base_type::set_method(L, l);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzAllocator)

static void
register_bind_pose_mt(lua_State *L) {
	luaL_newmetatable(L, "OZZ_BIND_POSE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"", lbp_result_init},
		{"joint", lbp_result_joint},
		{"joints", lbp_result_joints},
		{"count", lbp_result_count},
		{"transform", lbp_result_transform},
		{"__gc", ldel_bpresult},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

bool
do_ltm(const ozz::animation::Skeleton *ske, 
	const bind_pose_soa::bind_pose_type &intermediateResult, 
	bind_pose::bind_pose_type &joints,
	const ozz::math::Float4x4 *root = nullptr,
	int from = ozz::animation::Skeleton::kNoParent,
	int to = ozz::animation::Skeleton::kMaxJoints) {
	ozz::animation::LocalToModelJob ltmjob;
	ltmjob.root = root;
	ltmjob.input = ozz::make_range(intermediateResult);
	ltmjob.skeleton = ske;
	ltmjob.output = ozz::make_range(joints);
	return ltmjob.Run();
}

struct ozzSamplingCache : public luaClass<ozzSamplingCache> {
	ozz::animation::SamplingCache* v;
	ozzSamplingCache(int max_tracks)
	: v(OZZ_NEW(ozz::memory::default_allocator(), ozz::animation::SamplingCache)(max_tracks))
	{ }
	~ozzSamplingCache() {
		OZZ_DELETE(ozz::memory::default_allocator(), v);
	}
	static int create(lua_State* L) {
		int max_tracks = (int)luaL_optinteger(L, 1, 0);
		base_type::constructor(L, max_tracks);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzSamplingCache)

struct ozzAnimation : public luaClass<ozzAnimation> {
	ozz::animation::Animation* v;
	ozzAnimation()
	: v(OZZ_NEW(ozz::memory::default_allocator(), ozz::animation::Animation)())
	{ }
	~ozzAnimation() {
		OZZ_DELETE(ozz::memory::default_allocator(), v);
	}

	static int duration(lua_State *L) {
		lua_pushnumber(L, base_type::get(L, 1)->v->duration());
		return 1;
	}
	static int size(lua_State *L) {
		lua_pushinteger(L, base_type::get(L, 1)->v->size());
		return 1;
	}
	static int create(lua_State* L) {
		const char* path = luaL_checkstring(L, 1);
		ozzAnimation* self = base_type::constructor(L);
		luaL_Reg l[] = {		
			{"duration", duration},
			{"size", size},
			{nullptr, nullptr},
		};
		base_type::set_method(L, l);

		ozz::io::File file(path, "rb");
		if (!file.opened()) {
			luaL_error(L, "file could not open : %s", path);
		}
		ozz::io::IArchive archive(&file);
		if (!archive.TestTag<ozz::animation::Animation>()) {		
			luaL_error(L, "file is not ozz::animation, file : %s", path);
		}
		archive >> *(self->v);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzAnimation)

struct ozzBlendingJob : public luaClass<ozzBlendingJob> {
	ozz::animation::Skeleton*                            m_ske = nullptr;
	ozz::Vector<bind_pose_soa::bind_pose_type>::Std      m_result;
	ozz::Vector<ozz::animation::BlendingJob::Layer>::Std m_layers;

	int setup(lua_State* L) {
		luaL_checktype(L, 1, LUA_TUSERDATA);
		auto hie = (hierarchy_build_data*)lua_touserdata(L, 1);
		m_ske = hie->skeleton;
		m_result.clear();
		m_layers.clear();
		return 0;
	}
	int do_sample(lua_State* L) {
		ozzSamplingCache* sampling = ozzSamplingCache::get(L, 1);
		ozzAnimation* animation = ozzAnimation::get(L, 2);
		float ratio = (float)luaL_checknumber(L, 3);
		float weight = (float)luaL_optnumber(L, 4, 1.0f);
		bind_pose_soa::bind_pose_type pose(m_ske->num_soa_joints());
		ozz::animation::SamplingJob job;
		if (m_ske->num_joints() > sampling->v->max_tracks()){
			sampling->v->Resize(m_ske->num_joints());
		}
		job.animation = animation->v;
		job.cache = sampling->v;
		job.ratio = ratio;
		job.output = ozz::make_range(pose);
		if (!job.Run()) {
			return luaL_error(L, "sampling animation failed!");
		}
		m_result.emplace_back(pose);
		ozz::animation::BlendingJob::Layer layer;
		layer.weight = weight;
		layer.transform = ozz::make_range(m_result.back());
		m_layers.emplace_back(layer);
		return 0;
	}
	int do_blend(lua_State* L) {
		const char* blendtype = luaL_checkstring(L, 1);
		lua_Integer n = luaL_checkinteger(L, 2);
		float weight = (float)luaL_optnumber(L, 3, 1.0f);
		float threshold = (float)luaL_optnumber(L, 4, 0.1f);
		size_t max = m_layers.size();
		if (n <= 0 || (size_t)n > max) {
			return luaL_error(L, "invalid blend range: %d", n);
		}
		if (n == 1) {
			m_layers.back().weight = weight;
			return 0;
		}
		ozz::animation::BlendingJob job;
		bind_pose_soa::bind_pose_type pose(m_ske->num_soa_joints());
		if (strcmp(blendtype, "blend") == 0) {
			job.layers = ozz::Range(&m_layers[max-n], n);
		} else if (strcmp(blendtype, "additive") == 0) {
			job.additive_layers = ozz::Range(&m_layers[max-n], n);
		} else {
			return luaL_error(L, "invalid blend type: %s", blendtype);
		}
		job.bind_pose = m_ske->joint_bind_poses();
		job.threshold = threshold;
		job.output = ozz::make_range(pose);
		if (!job.Run()) {
			return luaL_error(L, "blend failed");
		}
		m_result.resize(max-n);
		m_layers.resize(max-n);
		m_result.emplace_back(pose);
		ozz::animation::BlendingJob::Layer layer;
		layer.weight = weight;
		layer.transform = ozz::make_range(m_result.back());
		m_layers.emplace_back(layer);
		return 0;
	}
	int do_ik(lua_State* L) {
		return 0;
	}
	
	static void fix_root_translation(ozz::animation::Skeleton *ske, bind_pose_soa::bind_pose_type& pose){
		size_t n = (size_t)ske->num_joints();
		const auto& parents = ske->joint_parents();
		for (size_t i = 0; i < n; ++i) {
			if (parents[i] == ozz::animation::Skeleton::kNoParent) {
				auto& trans = pose[i / 4];
				const auto newtrans = ozz::math::simd_float4::zero();
				trans.translation.x = ozz::math::SetI(trans.translation.x, newtrans, 0);
				trans.translation.z = ozz::math::SetI(trans.translation.z, newtrans, 0);
				return;
			}
		}
	}

	int get_result(lua_State* L) {
		if (m_result.empty()) {
			return luaL_error(L, "no result");
		}
		auto aniresult = (bind_pose*)lua_touserdata(L, 1);
		const bool fixroot = lua_isnoneornil(L, 2) ? false : lua_toboolean(L, 2);
		if (fixroot) {
			fix_root_translation(m_ske, m_result.back());
		}
		if (!do_ltm(m_ske, m_result.back(), aniresult->pose)){
			return luaL_error(L, "doing blend result to ltm job failed!");
		}
		return 0;
	}
	static int lsetup(lua_State* L) {
		return base_type::get(L, lua_upvalueindex(1))
			->setup(L);
	}
	static int ldo_sample(lua_State* L) {
		return base_type::get(L, lua_upvalueindex(1))
			->do_sample(L);
	}
	static int ldo_blend(lua_State* L) {
		return base_type::get(L, lua_upvalueindex(1))
			->do_blend(L);
	}
	static int ldo_ik(lua_State* L) {
		return base_type::get(L, lua_upvalueindex(1))
			->do_ik(L);
	}
	static int lget_result(lua_State* L) {
		return base_type::get(L, lua_upvalueindex(1))
			->get_result(L);
	}
	static int init(lua_State* L) {
		base_type::constructor(L);
		luaL_Reg l[] = {
			{ "setup",		lsetup},
			{ "do_sample",	ldo_sample},
			{ "do_blend",	ldo_blend},
			{ "do_ik",		ldo_ik},
			{ "get_result",	lget_result},
			{ nullptr, nullptr},
		};
		luaL_setfuncs(L, l, 1);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzBlendingJob)

extern "C" {
LUAMOD_API int
luaopen_hierarchy_animation(lua_State *L) {
	register_bind_pose_mt(L);
	lua_newtable(L);
	luaL_Reg l[] = {
		{ "mesh_skinning",				lmesh_skinning},
		{ "build_skinning_matrices",	lbuild_skinning_matrices},
		{ "new_animation",				ozzAnimation::create},
		{ "new_sampling_cache",			ozzSamplingCache::create},
		{ "new_bind_pose",				lnew_bind_pose},
		{ "new_aligned_memory",			ozzAllocator::create},
		{ "new_joint_remap",			ozzJointRemap::create},
		{ NULL, NULL },
	};
	luaL_setfuncs(L,l,0);
	ozzBlendingJob::init(L);
	return 1;
}

}
