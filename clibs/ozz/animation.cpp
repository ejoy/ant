#define LUA_LIB
#include <lua.hpp>

#include <binding/binding.h>

#include "ozz.h"

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


#define REGISTER_LUA_NAME(C) namespace bee::lua { template <> struct udata<C> { static inline auto name = #C; }; }
REGISTER_LUA_NAME(ozzJointRemap)
REGISTER_LUA_NAME(ozzSamplingContext)
REGISTER_LUA_NAME(ozzBindpose)
REGISTER_LUA_NAME(ozzPoseResult)
REGISTER_LUA_NAME(ozzAnimation)
REGISTER_LUA_NAME(ozzRawAnimation)
#undef REGISTER_LUA_NAME

namespace ozzlua::JointRemap {
	static int count(lua_State* L) {
		auto& jm = bee::lua::checkudata<ozzJointRemap>(L, 1);
		lua_pushinteger(L, jm.joints.size());
		return 1;
	}
	static int index(lua_State* L) {
		auto& jm = bee::lua::checkudata<ozzJointRemap>(L, 1);
		int idx = (int)luaL_checkinteger(L, 2)-1;
		if (idx < 0 || idx >= jm.joints.size()){
			luaL_error(L, "invalid index:", idx);
		}
		lua_pushinteger(L, jm.joints[idx]);
		return 1;
	}
	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "count", count },
			{ "index", index },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}
	static int create(lua_State* L) {
		auto& self = bee::lua::newudata<ozzJointRemap>(L, metatable);
		switch (lua_type(L, 1)) {
		case LUA_TTABLE: {
			size_t n = (size_t)lua_rawlen(L, 1);
			self.joints.resize(n);
			for (size_t i = 0; i < n; ++i){
				lua_geti(L, 1, i+1);
				self.joints[i] = (uint16_t)luaL_checkinteger(L, -1);
				lua_pop(L, 1);
			}
			break;
		}
		case LUA_TLIGHTUSERDATA: {
			const size_t jointnum = (size_t)luaL_checkinteger(L, 2);
			self.joints.resize(jointnum);
			const uint16_t *p = (const uint16_t*)lua_touserdata(L, 1);
			memcpy(&self.joints.front(), p, jointnum * sizeof(uint16_t));
			break;
		}
		default:
			return luaL_error(L, "not support type in argument 1");
		}
		return 1;
	}
}

namespace ozzlua::SamplingContext {
	static void metatable(lua_State* L) {
		lua_newtable(L);
	}
	static int create(lua_State* L) {
		int max_tracks = (int)luaL_optinteger(L, 1, 0);
		bee::lua::newudata<ozzSamplingContext>(L, metatable, max_tracks);
		return 1;
	}
}

namespace ozzlua::Bindpose {
	static int count(lua_State* L) {
		auto& bp = bee::lua::checkudata<ozzBindpose>(L, 1);
		lua_pushinteger(L, bp.size());
		return 1;
	}

	static int joint(lua_State *L) {
		auto& bp = bee::lua::checkudata<ozzBindpose>(L, 1);
		const auto jointidx = (uint32_t)luaL_checkinteger(L, 2) - 1;
		if (jointidx < 0 || jointidx > bp.size()){
			luaL_error(L, "invalid joint index:%d", jointidx);
		}

		float * r = (float*)lua_touserdata(L, 3);
		const ozz::math::Float4x4& trans = bp[jointidx];
		assert(sizeof(trans) <= sizeof(float) * 16);
		memcpy(r, &trans, sizeof(trans));
		return 0;
	}

	static int pointer(lua_State *L) {
		auto& bp = bee::lua::checkudata<ozzBindpose>(L, 1);
		lua_pushlightuserdata(L, &bp[0]);
		return 1;
	}

	static int transform(lua_State *L) {
		auto& bp = bee::lua::checkudata<ozzBindpose>(L, 1);
		auto trans = (const ozz::math::Float4x4*)lua_touserdata(L, 2);
		for (auto &p : bp) {
			p = p * *trans;
		}
		return 0;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "count", count },
			{ "joint", joint },
			{ "pointer", pointer },
			{ "transform", transform },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}
	static int getmetatable(lua_State* L) {
		bee::lua::getmetatable<ozzBindpose>(L, metatable);
		return 1;
	}
	static int create(lua_State* L) {
		lua_Integer numjoints = luaL_checkinteger(L, 1);
		if (numjoints <= 0) {
			luaL_error(L, "joints number should be > 0");
			return 0;
		}
		switch (lua_type(L, 2)) {
		case LUA_TNIL:
		case LUA_TNONE:
			bee::lua::newudata<ozzBindpose>(L, metatable, (size_t)numjoints);
			break;
		case LUA_TSTRING: {
			size_t size = 0;
			const float* data = (const float*)lua_tolstring(L, 2, &size);
			if (size != sizeof(ozz::math::Float4x4) * numjoints) {
				return luaL_error(L, "init data size is not valid, need:%d", sizeof(ozz::math::Float4x4) * numjoints);
			}
			bee::lua::newudata<ozzBindpose>(L, metatable, (size_t)numjoints, data);
			break;
		}
		case LUA_TUSERDATA:
		case LUA_TLIGHTUSERDATA: {
			const float* data = (const float*)lua_touserdata(L, 2);
			bee::lua::newudata<ozzBindpose>(L, metatable, (size_t)numjoints, data);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type, only support string/userdata/light userdata");
		}
		return 1;
	}
}

namespace ozzlua::PoseResult {
	static int setup(lua_State* L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		const auto hie = (hierarchy_build_data*)luaL_checkudata(L, 2, "HIERARCHY_BUILD_DATA");
		if (pr.m_ske) {
			if (pr.m_ske != hie->skeleton) {
				return luaL_error(L, "using sample pose_result but different skeleton");
			}
		} else {
			pr.m_ske = hie->skeleton;
		}
		return 0;
	}

	static int do_sample(lua_State* L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		auto& sc = bee::lua::checkudata<ozzSamplingContext>(L, 2);
		auto& animation = bee::lua::checkudata<ozzAnimation>(L, 3);
		float ratio = (float)luaL_checknumber(L, 4);
		float weight = (float)luaL_optnumber(L, 5, 1.0f);

		if (pr.m_ske->num_joints() > sc.v->max_tracks()){
			sc.v->Resize(pr.m_ske->num_joints());
		}
		bindpose_soa bp_soa(pr.m_ske->num_soa_joints());
		ozz::animation::SamplingJob job;
		job.animation = animation.v;
		job.context = sc.v;
		job.ratio = ratio;
		job.output = ozz::make_span(bp_soa);
		if (!job.Run()) {
			return luaL_error(L, "sampling animation failed!");
		}
		pr.m_results.emplace_back(bp_soa);
		ozz::animation::BlendingJob::Layer layer;
		layer.weight = weight;
		layer.transform = ozz::make_span(pr.m_results.back());
		pr.m_layers.emplace_back(layer);
		return 0;
	}

	static int fetch_result(lua_State* L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		if (pr.m_ske == nullptr)
			return luaL_error(L, "invalid skeleton!");

		ozz::animation::LocalToModelJob job;
		if (lua_isnoneornil(L, 2)){
			job.root = (ozz::math::Float4x4*)lua_touserdata(L, 2);
		}

		job.input = pr.m_results.empty() ? pr.m_ske->joint_rest_poses() : ozz::make_span(pr.m_results.back());
		job.skeleton = pr.m_ske;
		job.output = ozz::make_span(pr);
		if (!job.Run()) {
			return luaL_error(L, "doing blend result to ltm job failed!");
		}
		return 0;
	}

	static int clear(lua_State *L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		pr.m_ske = nullptr;
		pr.m_results.clear();
		pr.m_layers.clear();
		return 0;
	}

	static int fix_root_XZ(lua_State *L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		auto& bp_soa = pr.m_results.back();
		size_t n = (size_t)pr.m_ske->num_joints();
		const auto& parents = pr.m_ske->joint_parents();
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

	static int joint_local_srt(lua_State *L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		const auto poses = pr.m_results.empty() ? pr.m_ske->joint_rest_poses() : ozz::make_span(pr.m_results.back());
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

	static int count(lua_State* L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		lua_pushinteger(L, pr.size());
		return 1;
	}

	static int joint(lua_State *L) {
		auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 1);
		const auto jointidx = (uint32_t)luaL_checkinteger(L, 2) - 1;
		if (jointidx < 0 || jointidx > pr.size()){
			luaL_error(L, "invalid joint index:%d", jointidx);
		}

		float * r = (float*)lua_touserdata(L, 3);
		const ozz::math::Float4x4& trans = pr[jointidx];
		assert(sizeof(trans) <= sizeof(float) * 16);
		memcpy(r, &trans, sizeof(trans));
		return 0;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "setup", setup },
			{ "do_sample", do_sample },
			{ "fetch_result", fetch_result },
			{ "end_animation", clear },
			{ "clear", clear },
			{ "fix_root_XZ", fix_root_XZ },
			{ "joint_local_srt", joint_local_srt },
			{ "count", count },
			{ "joint", joint },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}

	static int getmetatable(lua_State* L) {
		bee::lua::getmetatable<ozzPoseResult>(L, metatable);
		return 1;
	}

	static int create(lua_State* L) {
		lua_Integer numjoints = luaL_checkinteger(L, 1);
		if (numjoints <= 0) {
			luaL_error(L, "joints number should be > 0");
			return 0;
		}
		switch (lua_type(L, 2)) {
		case LUA_TNIL:
		case LUA_TNONE:
			bee::lua::newudata<ozzPoseResult>(L, metatable, (size_t)numjoints);
			break;
		case LUA_TSTRING: {
			size_t size = 0;
			const float* data = (const float*)lua_tolstring(L, 2, &size);
			if (size != sizeof(ozz::math::Float4x4) * numjoints) {
				return luaL_error(L, "init data size is not valid, need:%d", sizeof(ozz::math::Float4x4) * numjoints);
			}
			bee::lua::newudata<ozzPoseResult>(L, metatable, (size_t)numjoints, data);
			break;
		}
		case LUA_TUSERDATA:
		case LUA_TLIGHTUSERDATA: {
			const float* data = (const float*)lua_touserdata(L, 2);
			bee::lua::newudata<ozzPoseResult>(L, metatable, (size_t)numjoints, data);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type, only support string/userdata/light userdata");
		}
		return 1;
	}
}

namespace ozzlua::Animation {
	static int duration(lua_State *L) {
		auto& animation = bee::lua::checkudata<ozzAnimation>(L, 1);
		lua_pushnumber(L, animation.v->duration());
		return 1;
	}

	static int num_tracks(lua_State *L) {
		auto& animation = bee::lua::checkudata<ozzAnimation>(L, 1);
		lua_pushinteger(L, animation.v->num_tracks());
		return 1;
	}

	static int name(lua_State *L) {
		auto& animation = bee::lua::checkudata<ozzAnimation>(L, 1);
		lua_pushstring(L, animation.v->name());
		return 1;
	}

	static int size(lua_State *L) {
		auto& animation = bee::lua::checkudata<ozzAnimation>(L, 1);
		lua_pushinteger(L, animation.v->size());
		return 1;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "duration", duration },
			{ "num_tracks",	num_tracks },
			{ "name", name },
			{ "size", size },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}

	static int create(lua_State* L, ozz::animation::Animation* v) {
		bee::lua::newudata<ozzAnimation>(L, metatable, v);
		return 1;
	}

	static const char* load(lua_State* L, ozz::io::IArchive &ia) {
		if (!ia.TestTag<ozz::animation::Animation>()) {		
			return nullptr;
		}

		auto ani = ozz::New<ozz::animation::Animation>();
		ia >> *ani;
		create(L, ani);
		return ozz::io::internal::Tag<const ozz::animation::Animation>::Get();
	}
}

namespace ozzlua::RawAnimation {
	static int setup(lua_State *L) {
		auto& base = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::RawAnimation* pv = base.v;
		const auto ske = (hierarchy_build_data*)luaL_checkudata(L, 2, "HIERARCHY_BUILD_DATA");
		base.m_skeleton = ske->skeleton;
		pv->duration = (float)lua_tonumber(L, 3);
		pv->tracks.resize(base.m_skeleton->num_joints());
		return 0;
	}

	static int push_prekey(lua_State *L) {
		auto& base = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::RawAnimation* pv = base.v;
		if(!base.m_skeleton) {
			luaL_error(L, "setup must be called first");
			return 0;
		}

		// joint name
		int idx = ozz::animation::FindJoint(*base.m_skeleton, lua_tostring(L, 2));
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

	static int build(lua_State *L) {
		auto& base = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::RawAnimation* pv = base.v;
		ozz::animation::offline::AnimationBuilder builder;
		ozz::animation::Animation *animation = builder(*pv).release();
		if (!animation) {
			luaL_error(L, "Failed to build animation");
			return 0;
		}
		return ozzlua::Animation::create(L, animation);
	}

	static int clear(lua_State* L) {
		auto& base = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::RawAnimation* pv = base.v;
		base.m_skeleton = nullptr;
		pv->tracks.clear();
		return 0;
	}

	static int clear_prekey(lua_State* L) {
		auto& base = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::RawAnimation* pv = base.v;
		if (!base.m_skeleton) {
			luaL_error(L, "setup must be called first");
			return 0;
		}

		// joint name
		int idx = ozz::animation::FindJoint(*base.m_skeleton, lua_tostring(L, 2));
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

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "setup", setup },
			{ "push_prekey", push_prekey },
			{ "build", build },
			{ "clear", clear },
			{ "clear_prekey", clear_prekey },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}

	static int getmetatable(lua_State* L) {
		bee::lua::getmetatable<ozzRawAnimation>(L, metatable);
		return 1;
	}

	static int create(lua_State* L) {
		bee::lua::newudata<ozzRawAnimation>(L, metatable);
		return 1;
	}
}

const char* check_read_animation(lua_State *L, ozz::io::IArchive &ia){
	return ozzlua::Animation::load(L, ia);
}

void init_animation(lua_State *L) {
	luaL_Reg l[] = {
		{ "new_joint_remap",			ozzlua::JointRemap::create },
		{ "new_sampling_context",		ozzlua::SamplingContext::create },
		{ "new_bind_pose",				ozzlua::Bindpose::create },
		{ "bind_pose_mt",				ozzlua::Bindpose::getmetatable },
		{ "new_pose_result",			ozzlua::PoseResult::create },
		{ "pose_result_mt",				ozzlua::PoseResult::getmetatable },
		{ "new_raw_animation", 			ozzlua::RawAnimation::create},
		{ "raw_animation_mt",			ozzlua::RawAnimation::getmetatable},
		{ NULL, NULL },
	};
	luaL_setfuncs(L,l,0);
}

