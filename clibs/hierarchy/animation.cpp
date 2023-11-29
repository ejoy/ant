#define LUA_LIB
#include <lua.hpp>

#include "hierarchy.h"
//#include "meshbase/meshbase.h"
#include <ozz/animation/offline/raw_animation.h>
#include <ozz/animation/offline/animation_builder.h>

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/blending_job.h>
#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/runtime/skeleton_utils.h>

#include <ozz/geometry/runtime/skinning_job.h>
#include <ozz/base/platform.h>

#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/maths/soa_float4x4.h>
#include <ozz/base/maths/simd_quaternion.h>

#include <ozz/animation/runtime/ik_two_bone_job.h>
#include <ozz/animation/runtime/ik_aim_job.h>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/containers/vector.h>
#include <ozz/base/containers/map.h>
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
		reigister_mt(L, nullptr);
		lua_setmetatable(L, -2);
		return o;
	}
	static void set_method(lua_State* L, luaL_Reg l[]) {
		if (lua_getmetatable(L, -1)) {
			luaL_setfuncs(L, l, 0);
			lua_pop(L, 1);
		}
	}

	static void reigister_mt(lua_State *L, luaL_Reg *ll){
		if (luaL_newmetatable(L, kLuaName)) {
			lua_pushvalue(L, -1);
			lua_setfield(L, -2, "__index");
			luaL_Reg l[] = {
				{"__gc", destructor},
				{nullptr, nullptr},
			};
			luaL_setfuncs(L, l, 0);

			if (ll)
				luaL_setfuncs(L, ll, 0);
		}
	}
protected:
	static const char kLuaName[];
private:
	static int destructor(lua_State* L) {
		get(L, 1)->~T();
		return 0;
	}
public:
	static T* get(lua_State* L, int idx) {
#ifdef _DEBUG
		return (T*)luaL_checkudata(L, idx, kLuaName);
#else
		return (T*)luaL_testudata(L, idx, kLuaName);
#endif
	}

	static int getMT(lua_State *L){
		luaL_getmetatable(L, kLuaName);
		return 1;
	}
};
#define REGISTER_LUA_CLASS(C) template<> const char luaClass<C>::kLuaName[] = #C;

struct ozzJointRemap : public luaClass<ozzJointRemap> {
	ozz::vector<uint16_t> joints;
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

	static int
	lcount(lua_State *L){
		auto jm = (ozzJointRemap*)luaL_checkudata(L, 1, "ozzJointRemap");
		lua_pushinteger(L, jm->joints.size());
		return 1;
	}

	static int
	lindex(lua_State *L){
		auto jm = (ozzJointRemap*)luaL_checkudata(L, 1, "ozzJointRemap");
		int idx = (int)luaL_checkinteger(L, 2)-1;
		if (idx < 0 || idx >= jm->joints.size()){
			luaL_error(L, "invalid index:", idx);
		}
		lua_pushinteger(L, jm->joints[idx]);
		return 1;
	}

	static void registerMetatable(lua_State *L){
		luaL_Reg l[] = {
			{"count", 	lcount},
			{"index",	lindex},
			{nullptr, 	nullptr,}
		};
		base_type::reigister_mt(L, l);
		lua_pop(L, 1);
	}
};
REGISTER_LUA_CLASS(ozzJointRemap)


template <typename T>
struct ozzBindposeT : public bindpose, luaClass<T> {
public:
	typedef luaClass<T> base_type;

	ozzBindposeT(size_t numjoints)
		: bindpose(numjoints)
	{}

	ozzBindposeT(size_t numjoints, const float* data)
		: bindpose(numjoints)
	{
		memcpy(&(*this)[0], data, sizeof(ozz::math::Float4x4) * numjoints);
	}

	static bindpose* getBP(lua_State *L, int index){
		#ifdef _DEBUG
			if (!luaL_testudata(L, index, "ozzBindpose") && !luaL_testudata(L, index, "ozzPoseResult")) {
				luaL_argexpected(L, false, index, "ozzBindpose");
			}
		#endif
		return (bindpose*)lua_touserdata(L, index);
	}

protected:
	static int lcount(lua_State* L) {
		auto bp = getBP(L, 1);
		lua_pushinteger(L, bp->size());
		return 1;
	}

	static int ljoint(lua_State *L){
		auto bp = getBP(L, 1);
		const auto jointidx = (uint32_t)luaL_checkinteger(L, 2) - 1;
		if (jointidx < 0 || jointidx > bp->size()){
			luaL_error(L, "invalid joint index:%d", jointidx);
		}

		float * r = (float*)lua_touserdata(L, 3);
		const ozz::math::Float4x4& trans = (*bp)[jointidx];
		assert(sizeof(trans) <= sizeof(float) * 16);
		memcpy(r, &trans, sizeof(trans));
		return 0;
	}

	static int lpointer(lua_State *L){
		auto bp = getBP(L, 1);
		lua_pushlightuserdata(L, &(*bp)[0]);
		return 1;
	}

	static int ltransform(lua_State *L){
		auto bp = getBP(L, 1);
		auto trans = (const ozz::math::Float4x4*)lua_touserdata(L, 2);
		for ( auto &p : *bp){
			p = p * *trans;
		}

		return 0;
	}
public:
	static int create(lua_State* L) {
		lua_Integer numjoints = luaL_checkinteger(L, 1);
		if (numjoints <= 0) {
			luaL_error(L, "joints number should be > 0");
			return 0;
		}
		switch (lua_type(L, 2)) {
		case LUA_TNIL:
		case LUA_TNONE:
			base_type::constructor(L, (size_t)numjoints);
			break;
		case LUA_TSTRING: {
			size_t size = 0;
			const float* data = (const float*)lua_tolstring(L, 2, &size);
			if (size != sizeof(ozz::math::Float4x4) * numjoints) {
				return luaL_error(L, "init data size is not valid, need:%d", sizeof(ozz::math::Float4x4) * numjoints);
			}
			base_type::constructor(L, (size_t)numjoints, data);
			break;
		}
		case LUA_TUSERDATA:
		case LUA_TLIGHTUSERDATA: {
			const float* data = (const float*)lua_touserdata(L, 2);
			base_type::constructor(L, (size_t)numjoints, data);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type, only support string/userdata/light userdata");
		}
		return 1;
	}

	static void registerMetatable(lua_State *L){
		luaL_Reg l[] = {
			{"count", 		lcount},
			{"joint", 		ljoint},
			{"pointer",		lpointer},
			{"transform",	ltransform},
			{nullptr, 		nullptr,}
		};
		base_type::reigister_mt(L, l);
		lua_pop(L, 1);
	}
};

struct alignas(8) ozzBindpose : public ozzBindposeT<ozzBindpose>{
	ozzBindpose(size_t numjoints):ozzBindposeT<ozzBindpose>(numjoints){}
	ozzBindpose(size_t numjoints, const float *data):ozzBindposeT<ozzBindpose>(numjoints, data){}
};
REGISTER_LUA_CLASS(ozzBindpose)

extern bool
do_ik(lua_State* L,
	const ozz::animation::Skeleton *ske,
	bindpose_soa &bp_soa, 
	bindpose &result_pose);

struct ozzAllocator : public luaClass<ozzAllocator> {
	void* v;
	size_t s;
	ozzAllocator(size_t size, size_t alignment)
	: v(ozz::memory::default_allocator()->Allocate(size, alignment))
	, s(size)
	{ }
	~ozzAllocator() {
		ozz::memory::default_allocator()->Deallocate(v);
	}

	static int lpointer(lua_State* L) {
		lua_pushlightuserdata(L, base_type::get(L, 1)->v);
		return 1;
	}

	static int lsize(lua_State *L){
		lua_pushinteger(L, base_type::get(L, 1)->s);
		return 1;
	}
	static int create(lua_State* L) {
		const size_t sizebytes = (size_t)luaL_checkinteger(L, 1);
		const size_t aligned = (size_t)luaL_optinteger(L, 2, 4);
		base_type::constructor(L, sizebytes, aligned);
		luaL_Reg l[] = {
			{"pointer", lpointer},
			{"size", lsize},
			{nullptr, nullptr},
		};
		base_type::set_method(L, l);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzAllocator)

struct ozzSamplingContext : public luaClass<ozzSamplingContext> {
	ozz::animation::SamplingJob::Context*  v;
	ozzSamplingContext(int max_tracks)
	: v(ozz::New<ozz::animation::SamplingJob::Context>(max_tracks))
	{ }
	~ozzSamplingContext() {
		ozz::Delete(v);
	}
	static int create(lua_State* L) {
		int max_tracks = (int)luaL_optinteger(L, 1, 0);
		base_type::constructor(L, max_tracks);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzSamplingContext)

struct ozzAnimation : public luaClass<ozzAnimation> {
	ozz::animation::Animation* v;
	ozzAnimation()
		: v(ozz::New<ozz::animation::Animation>()) {
	}
	ozzAnimation(ozz::animation::Animation* p)
		: v(p) {
	}
	~ozzAnimation() {
		ozz::Delete(v);
	}

	static int lduration(lua_State *L) {
		lua_pushnumber(L, base_type::get(L, 1)->v->duration());
		return 1;
	}
	static int lsize(lua_State *L) {
		lua_pushinteger(L, base_type::get(L, 1)->v->size());
		return 1;
	}

	static int lnum_tracks(lua_State *L){
		lua_pushinteger(L, base_type::get(L, 1)->v->num_tracks());
		return 1;
	}

	static int lname(lua_State *L){
		lua_pushstring(L, base_type::get(L, 1)->v->name());
		return 1;
	}

	static const char* create(lua_State* L, ozz::io::IArchive &ia) {
		if (!ia.TestTag<ozz::animation::Animation>()) {		
			return nullptr;
		}

		ozzAnimation* self = base_type::constructor(L);
		luaL_Reg l[] = {		
			{"duration", lduration},
			{"num_tracks", lnum_tracks},
			{"name", lname},
			{"size", lsize},
			{nullptr, nullptr},
		};
		base_type::set_method(L, l);
		ia >> *(self->v);
		auto type = ozz::io::internal::Tag<const ozz::animation::Animation>::Get();
		return type;
	}

	static int instance(lua_State *L, ozz::animation::Animation *animation) {
		ozzAnimation* self = base_type::constructor(L, animation);
		luaL_Reg l[] = {
			{"duration", lduration},
			{"num_tracks", lnum_tracks},
			{"name", lname},
			{"size", lsize},
			{nullptr, nullptr},
		};
		base_type::set_method(L, l);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzAnimation)

struct alignas(8) ozzRawAnimation : public luaClass<ozzRawAnimation> {
	ozz::animation::offline::RawAnimation* v;
	ozz::animation::Skeleton* m_skeleton;

	ozzRawAnimation() {
		v = ozz::New<ozz::animation::offline::RawAnimation>();
		m_skeleton = nullptr;
	}
	~ozzRawAnimation() {
		ozz::Delete(v);
	}

	static int lclear(lua_State* L) {
		auto base = base_type::get(L, 1);
		ozz::animation::offline::RawAnimation* pv = base->v;

		base->m_skeleton = nullptr;
		pv->tracks.clear();
		return 0;
	}

	static int lclear_prekey(lua_State* L) {
		auto base = base_type::get(L, 1);
		ozz::animation::offline::RawAnimation* pv = base->v;
		if(!base->m_skeleton) {
			luaL_error(L, "setup must be called first");
			return 0;
		}

		// joint name
		int idx = ozz::animation::FindJoint(*base->m_skeleton, lua_tostring(L, 2));
		if (idx < 0) {
			luaL_error(L, "Can not found joint name");
			return 0;
		}
		ozz::animation::offline::RawAnimation::JointTrack& track = pv->tracks[idx];
		track.scales.clear();
		track.rotations.clear();
		track.translations.clear();
		return 0;
	}

	static int lsetup(lua_State *L) {
		auto base = base_type::get(L, 1);
		ozz::animation::offline::RawAnimation* pv = base->v;

		const auto ske = (hierarchy_build_data*)luaL_checkudata(L, 2, "HIERARCHY_BUILD_DATA");
		base->m_skeleton = ske->skeleton;
		pv->duration = (float)lua_tonumber(L, 3);
		pv->tracks.resize(base->m_skeleton->num_joints());
		return 0;
	}

	static int lpush_prekey(lua_State *L) {
		auto base = base_type::get(L, 1);
		ozz::animation::offline::RawAnimation* pv = base_type::get(L, 1)->v;
		if(!base->m_skeleton) {
			luaL_error(L, "setup must be called first");
			return 0;
		}

		// joint name
		int idx = ozz::animation::FindJoint(*base->m_skeleton, lua_tostring(L, 2));
		if (idx < 0) {
			luaL_error(L, "Can not found joint name");
			return 0;
		}
		ozz::animation::offline::RawAnimation::JointTrack& track = pv->tracks[idx];

		// time
		float time = (float)lua_tonumber(L, 3);

		// scale
		ozz::math::Float3 scale;
		memcpy(&scale, lua_touserdata(L, 4), sizeof(scale));
		ozz::animation::offline::RawAnimation::ScaleKey PreScaleKey;
		PreScaleKey.time = time;
		PreScaleKey.value = scale;
		track.scales.push_back(PreScaleKey);

		// rotation
		ozz::math::Quaternion rotation;
		memcpy(&rotation, lua_touserdata(L, 5), sizeof(rotation));
		ozz::animation::offline::RawAnimation::RotationKey PreRotationKey;
		PreRotationKey.time = time;
		PreRotationKey.value = rotation;
		track.rotations.push_back(PreRotationKey);

		// translation
		ozz::math::Float3 translation;
		memcpy(&translation, lua_touserdata(L, 6), sizeof(translation));
		ozz::animation::offline::RawAnimation::TranslationKey PreTranslationKeys;
		PreTranslationKeys.time = time;
		PreTranslationKeys.value = translation;
		track.translations.push_back(PreTranslationKeys);

		return 0;
	}

	static int lbuild(lua_State *L) {
		auto base = base_type::get(L, 1);
		ozz::animation::offline::RawAnimation* pv = base_type::get(L, 1)->v;

		ozz::animation::offline::AnimationBuilder builder;
		ozz::animation::Animation *animation = builder(*pv).release();
		if (!animation) {
			luaL_error(L, "Failed to build animation");
			return 0;
		}

		return ozzAnimation::instance(L, animation);
	}

	static int create(lua_State *L) {
		base_type::constructor(L);
		return 1;
	}

	static void registerMetatable(lua_State* L) {
		luaL_Reg l[] = {
			{"setup",        lsetup},
			{"push_prekey",  lpush_prekey},
			{"build", 	     lbuild},
			{"clear", 	     lclear},
			{"clear_prekey", lclear_prekey},
			{nullptr, 	     nullptr,}
		};
		base_type::reigister_mt(L, l);
		lua_pop(L, 1);
	}
};
REGISTER_LUA_CLASS(ozzRawAnimation)

struct alignas(8) ozzPoseResult : public ozzBindposeT<ozzPoseResult> {
public:
	typedef luaClass<ozzPoseResult> luaClassType;

	ozz::vector<bindpose_soa>  m_results;
	ozz::vector<ozz::animation::BlendingJob::Layer> m_layers;
	ozz::animation::Skeleton*   m_ske;
	ozzPoseResult(size_t numjoints)
		: ozzBindposeT<ozzPoseResult>(numjoints)
		, m_ske(nullptr)
	{
	}

	ozzPoseResult(size_t numjoints, const float *data)
		: ozzBindposeT<ozzPoseResult>(numjoints, data)
		, m_ske(nullptr)
	{
	}
private:
	void _push_pose(bindpose_soa const& pose, float weight) {
		m_results.emplace_back(pose);
		ozz::animation::BlendingJob::Layer layer;
		layer.weight = weight;
		layer.transform = ozz::make_span(m_results.back());
		m_layers.emplace_back(layer);
	}

	inline int 
	fix_root_XZ(lua_State *L) {
		auto &bp_soa = m_results.back();
		size_t n = (size_t)m_ske->num_joints();
		const auto& parents = m_ske->joint_parents();
		for (size_t i = 0; i < n; ++i) {
			if (parents[i] == ozz::animation::Skeleton::kNoParent) {
				auto& trans = bp_soa[i / 4];
				const auto newtrans = ozz::math::simd_float4::zero();
				trans.translation.x = ozz::math::SetI(trans.translation.x, newtrans, 0);
				trans.translation.z = ozz::math::SetI(trans.translation.z, newtrans, 0);
				return 0;
			}
		}
		return 0;
	}

	int setup(lua_State* L) {
		const auto hie = (hierarchy_build_data*)luaL_checkudata(L, 2, "HIERARCHY_BUILD_DATA");
		if (m_ske){
			if (m_ske != hie->skeleton){
				return luaL_error(L, "using sample pose_result but different skeleton");
			}
		} else {
			m_ske = hie->skeleton;
		}
		return 0;
	}

	int do_sample(lua_State* L) {
		ozzSamplingContext* sc = ozzSamplingContext::get(L, 2);
		ozzAnimation* animation = ozzAnimation::get(L, 3);
		float ratio = (float)luaL_checknumber(L, 4);
		float weight = (float)luaL_optnumber(L, 5, 1.0f);

		if (m_ske->num_joints() > sc->v->max_tracks()){
			sc->v->Resize(m_ske->num_joints());
		}
		bindpose_soa bp_soa(m_ske->num_soa_joints());
		ozz::animation::SamplingJob job;
		job.animation = animation->v;
		job.context = sc->v;
		job.ratio = ratio;
		job.output = ozz::make_span(bp_soa);
		if (!job.Run()) {
			return luaL_error(L, "sampling animation failed!");
		}
		_push_pose(bp_soa, weight);
		return 0;
	}

	int do_ik(lua_State* L) {
		if (!::do_ik(L, m_ske, m_results.back(), *this)){
			luaL_error(L, "do_ik failed!");
		}
		return 0;
	}

	int fetch_result(lua_State* L) {
		if (m_ske == nullptr)
			return luaL_error(L, "invalid skeleton!");

		ozz::animation::LocalToModelJob job;
		if (lua_isnoneornil(L, 2)){
			job.root = (ozz::math::Float4x4*)lua_touserdata(L, 2);
		}

		job.input = m_results.empty() ? m_ske->joint_rest_poses() : ozz::make_span(m_results.back());
		job.skeleton = m_ske;
		job.output = ozz::make_span(*(bindpose*)this);
		if (!job.Run()) {
			return luaL_error(L, "doing blend result to ltm job failed!");
		}
		return 0;
	}

	int clear(lua_State *L){
		m_ske = nullptr;
		m_results.clear();
		m_layers.clear();
		return 0;
	}

	int joint_local_srt(lua_State *L){
		const auto poses = m_results.empty() ? m_ske->joint_rest_poses() : ozz::make_span(m_results.back());
		const int joint_idx = (int)luaL_checkinteger(L, 2)-1;
		if (joint_idx >= poses.size() || joint_idx < 0){
			return luaL_error(L, "Invalid joint index:%d", joint_idx);
		}

		const int si = joint_idx & 3;
		const auto pose = poses[joint_idx];
		
    	float * s = (float*)lua_touserdata(L, 3);
		float * r = (float*)lua_touserdata(L, 4);
		float * t = (float*)lua_touserdata(L, 5);

		
		float ss[4][3];
		ozz::math::StorePtr(pose.scale.x, ss[0]);
		ozz::math::StorePtr(pose.scale.y, ss[1]);
		ozz::math::StorePtr(pose.scale.z, ss[2]);
		s[0] = ss[0][si]; s[1] = ss[1][si]; s[0] = ss[2][si];

		float rr[4][4];
		ozz::math::StorePtr(pose.rotation.x, rr[0]);
		ozz::math::StorePtr(pose.rotation.y, rr[1]);
		ozz::math::StorePtr(pose.rotation.z, rr[2]);
		ozz::math::StorePtr(pose.rotation.w, rr[3]);

		r[0] = rr[0][si]; r[1] = rr[1][si]; r[0] = rr[2][si]; r[0] = rr[3][si];

		float tt[4][3];
		ozz::math::StorePtr(pose.translation.x, tt[0]);
		ozz::math::StorePtr(pose.translation.y, tt[1]);
		ozz::math::StorePtr(pose.translation.z, tt[2]);
		t[0] = tt[0][si]; t[1] = tt[1][si]; t[0] = tt[2][si];

		return 0;
	}

#define STATIC_MEM_FUNC(_NAME)	static int l##_NAME(lua_State* L){ auto pr = ozzPoseResult::get(L, 1); return pr->_NAME(L); }
	STATIC_MEM_FUNC(setup);
	STATIC_MEM_FUNC(do_sample);
	STATIC_MEM_FUNC(fetch_result);
	STATIC_MEM_FUNC(do_ik);
	STATIC_MEM_FUNC(clear);
	STATIC_MEM_FUNC(fix_root_XZ);
	STATIC_MEM_FUNC(joint_local_srt);
#undef MEM_FUNC

public:
	static int registerMetatable(lua_State* L) {
		luaL_Reg l[] = {
			{ "setup",		  	lsetup},
			{ "do_sample",	  	ldo_sample},
			{ "fetch_result", 	lfetch_result},
			{ "do_ik",		  	ldo_ik},
			{ "end_animation",	lclear},
			{ "clear",			lclear},
			{ "fix_root_XZ", 	lfix_root_XZ},
			{ "count", 			lcount},
			{ "joint", 			ljoint},
			{ "joint_local_srt",ljoint_local_srt},
			{ nullptr, 			nullptr},
		};

		luaClassType::reigister_mt(L, l);
		lua_pop(L, 1);
		return 1;
	}
};
REGISTER_LUA_CLASS(ozzPoseResult)

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
fill_skinning_job_field(uint32_t num_vertices, const DataT &d, ozz::span<T> &r, size_t &stride) {
	const uint8_t* begin_data = (const uint8_t*)d.data + d.offset;
	r = ozz::span<T>((T*)(begin_data), (T*)(begin_data + d.stride * num_vertices));
	stride = d.stride;
}

static void
build_skinning_matrices(bindpose* skinning_matrices,
	const bindpose* current_pose,
	const bindpose* inverse_bind_matrices,
	const ozzJointRemap *jarray,
	const ozz::math::Float4x4 *worldmat){
	if (jarray){
		assert(jarray->joints.size() == inverse_bind_matrices->size());
		if (worldmat){
			for (size_t ii = 0; ii < jarray->joints.size(); ++ii){
				const auto m = (*current_pose)[jarray->joints[ii]] * (*inverse_bind_matrices)[ii];
				(*skinning_matrices)[ii] = (*worldmat) * m;
			}
		} else {
			for (size_t ii = 0; ii < jarray->joints.size(); ++ii){
				(*skinning_matrices)[ii] = (*current_pose)[jarray->joints[ii]] * (*inverse_bind_matrices)[ii];
			}
		}

	} else {
		assert(current_pose->size() == inverse_bind_matrices->size() && skinning_matrices->size() == current_pose->size());
		if (worldmat){
			for (size_t ii = 0; ii < inverse_bind_matrices->size(); ++ii){
				const auto m = (*current_pose)[ii] * (*inverse_bind_matrices)[ii];
				(*skinning_matrices)[ii] = (*worldmat) * m;
			}
		} else {
			for (size_t ii = 0; ii < inverse_bind_matrices->size(); ++ii){
				(*skinning_matrices)[ii] = (*current_pose)[ii] * (*inverse_bind_matrices)[ii];
			}
		}
	}
}

static int
lbuild_skinning_matrices(lua_State *L){
	auto skinning_matrices = ozzBindpose::getBP(L, 1);
	auto current_bind_pose = ozzBindpose::getBP(L, 2);
	auto inverse_bind_matrices = ozzBindpose::getBP(L, 3);
	const ozzJointRemap *jarray = lua_isnoneornil(L, 4) ? nullptr : ozzJointRemap::get(L, 4);
	if (skinning_matrices->size() < inverse_bind_matrices->size()){
		return luaL_error(L, "invalid skinning matrices and inverse bind matrices, skinning matrices must larger than inverse bind matrices");
	}
	auto worldmat = lua_isnoneornil(L, 5) ? nullptr : (const ozz::math::Float4x4*)(lua_touserdata(L, 5));
	build_skinning_matrices(skinning_matrices, current_bind_pose, inverse_bind_matrices, jarray, worldmat);
	return 0;
}

static int
lmesh_skinning(lua_State *L){
	auto skinning_matrices = ozzPoseResult::getBP(L, 1);

	luaL_checktype(L, 2, LUA_TTABLE);
	in_vertex_data vd = {0};
	read_in_vertex_data(L, 2, vd);

	luaL_checktype(L, 3, LUA_TTABLE);
	out_vertex_data ovd = {0};
	read_vertex_data(L, 3, ovd);

	const uint32_t num_vertices = (uint32_t)luaL_checkinteger(L, 4);
	const uint32_t influences_count = (uint32_t)luaL_optinteger(L, 5, 4);

	ozz::geometry::SkinningJob skinning_job;
	skinning_job.vertex_count = num_vertices;
	skinning_job.influences_count = influences_count;
	skinning_job.joint_matrices = ozz::make_span(*skinning_matrices);
	
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

const char* check_read_animation(lua_State *L, ozz::io::IArchive &ia){
	return ozzAnimation::create(L, ia);
}

int init_animation(lua_State *L) {
	ozzJointRemap::registerMetatable(L);
	ozzBindpose::registerMetatable(L);
	ozzPoseResult::registerMetatable(L);
	ozzRawAnimation::registerMetatable(L);

	lua_newtable(L);
	luaL_Reg l[] = {
		{ "mesh_skinning",				lmesh_skinning},
		{ "build_skinning_matrices",	lbuild_skinning_matrices},
		{ "new_raw_animation", 			ozzRawAnimation::create},
		{ "raw_animation_mt",           ozzRawAnimation::getMT},
		{ "new_bind_pose",				ozzBindpose::create},
		{ "new_sampling_context",		ozzSamplingContext::create},
		{ "bind_pose_mt",				ozzBindpose::getMT},
		{ "new_pose_result",			ozzPoseResult::create},
		{ "pose_result_mt",				ozzPoseResult::getMT},
		{ "new_aligned_memory",			ozzAllocator::create},
		{ "new_joint_remap",			ozzJointRemap::create},
		{ NULL, NULL },
	};
	luaL_setfuncs(L,l,0);
	return 1;
}

