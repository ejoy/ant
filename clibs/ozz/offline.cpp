#include <lua.hpp>
#include <bee/lua/binding.h>
#include "../luabind/lua2struct.h"

#include "ozz.h"

#include <ozz/animation/offline/animation_builder.h>
#include <ozz/animation/offline/animation_optimizer.h>
#include <ozz/animation/runtime/skeleton_utils.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>

#include <cstring>

namespace ozzlua {
	namespace Animation {
		int create(lua_State* L, ozz::animation::Animation&& v);
	}
}

namespace ozzlua::RawAnimation {
	static int setup(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 2);
		raw.duration = (float)lua_tonumber(L, 3);
		raw.tracks.resize(ske.num_joints());
		return 0;
	}

	static int push_prekey(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 2);
		int idx = ozz::animation::FindJoint(ske, luaL_checkstring(L, 3));
		if (idx < 0) {
			luaL_error(L, "Can not found joint name");
			return 0;
		}
		ozz::animation::offline::RawAnimation::JointTrack& track = raw.tracks[idx];

		// time
		float time = (float)lua_tonumber(L, 4);

		// scale
		ozz::math::Float3 scale;
		memcpy(&scale, lua_touserdata(L, 5), sizeof(scale));
		ozz::animation::offline::RawAnimation::ScaleKey PreScaleKey;
		PreScaleKey.time = time;
		PreScaleKey.value = scale;
		track.scales.push_back(PreScaleKey);

		// rotation
		ozz::math::Quaternion rotation;
		memcpy(&rotation, lua_touserdata(L, 6), sizeof(rotation));
		ozz::animation::offline::RawAnimation::RotationKey PreRotationKey;
		PreRotationKey.time = time;
		PreRotationKey.value = rotation;
		track.rotations.push_back(PreRotationKey);

		// translation
		ozz::math::Float3 translation;
		memcpy(&translation, lua_touserdata(L, 7), sizeof(translation));
		ozz::animation::offline::RawAnimation::TranslationKey PreTranslationKeys;
		PreTranslationKeys.time = time;
		PreTranslationKeys.value = translation;
		track.translations.push_back(PreTranslationKeys);
		return 0;
	}

	static int build(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		ozz::animation::offline::AnimationBuilder builder;
		ozz::animation::Animation* animation = builder(raw).release();
		if (!animation) {
			luaL_error(L, "Failed to build animation");
			return 0;
		}
		return ozzlua::Animation::create(L, std::move(*animation));
	}

	static int clear(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		raw.tracks.clear();
		return 0;
	}

	static int clear_prekey(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 2);
		int idx = ozz::animation::FindJoint(ske, lua_tostring(L, 3));
		if (idx < 0) {
			luaL_error(L, "Can not found joint name");
			return 0;
		}
		ozz::animation::offline::RawAnimation::JointTrack& track = raw.tracks[idx];
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
		bee::lua::getmetatable<ozz::animation::offline::RawAnimation>(L);
		return 1;
	}

	static int create(lua_State* L) {
		bee::lua::newudata<ozz::animation::offline::RawAnimation>(L);
		return 1;
	}
}

namespace ozzlua {
	struct AnimationOptimizerSetting {
		struct JointsSetting {
			float tolerance;
			float distance;
			std::string name;
		};
		float tolerance;
		float distance;
		std::vector<JointsSetting> joints;
	};
	struct AnimationOptimizerStatistics {
		float translation_ratio;
		float rotation_ratio;
		float scale_ratio;
	};
	static int AnimationOptimizer(lua_State* L) {
		auto& raw_animation = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		auto& skeleton = bee::lua::checkudata<ozz::animation::Skeleton>(L, 2);
		auto setting = lua_struct::unpack<AnimationOptimizerSetting>(L, 3);
		ozz::animation::offline::AnimationOptimizer optimizer;
		optimizer.setting.tolerance = setting.tolerance;
		optimizer.setting.distance = setting.distance;
		for (auto& joint_setting : setting.joints) {
			ozz::animation::offline::AnimationOptimizer::Setting setting;
			setting.tolerance = joint_setting.tolerance;
			setting.distance = joint_setting.distance;
			for (int j = 0; j < skeleton.num_joints(); ++j) {
				const char* joint_name = skeleton.joint_names()[j];
				if (ozz::strmatch(joint_name, joint_setting.name.c_str())) {
					optimizer.joints_setting_override.emplace(j, setting);
				}
			}
		}
		ozz::animation::offline::RawAnimation raw_optimized_animation;
		if (!optimizer(raw_animation, skeleton, &raw_optimized_animation)) {
			return luaL_error(L, "Failed to optimize animation.");
		}

		size_t opt_translations = 0, opt_rotations = 0, opt_scales = 0;
		for (size_t i = 0; i < raw_optimized_animation.tracks.size(); ++i) {
			const auto& track = raw_optimized_animation.tracks[i];
			opt_translations += track.translations.size();
			opt_rotations += track.rotations.size();
			opt_scales += track.scales.size();
		}
		size_t non_opt_translations = 0, non_opt_rotations = 0, non_opt_scales = 0;
		for (size_t i = 0; i < raw_animation.tracks.size(); ++i) {
			const auto& track = raw_animation.tracks[i];
			non_opt_translations += track.translations.size();
			non_opt_rotations += track.rotations.size();
			non_opt_scales += track.scales.size();
		}

		AnimationOptimizerStatistics statistics;
		statistics.translation_ratio = opt_translations != 0 ? 1.f * non_opt_translations / opt_translations : 0.f;
		statistics.rotation_ratio = opt_rotations != 0 ? 1.f * non_opt_rotations / opt_rotations : 0.f;
		statistics.scale_ratio = opt_scales != 0 ? 1.f * non_opt_scales / opt_scales : 0.f;

		bee::lua::newudata<ozz::animation::offline::RawAnimation>(L, raw_optimized_animation);
		lua_struct::pack(L, statistics);
		return 2;
	}
}


static int lsave(lua_State* L) {
	auto& anim = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
	const char* filename = luaL_checkstring(L, 2);
	ozz::io::File ofile(filename, "wb");
	ozz::io::OArchive oa(&ofile);
	oa << (ozz::animation::Animation&)anim;
	return 0;
}

extern "C" int
luaopen_ozz_offline(lua_State *L) {
	luaL_checkversion(L);
	lua_newtable(L);
	static luaL_Reg lib[] = {
		{ "RawAnimation",		ozzlua::RawAnimation::create },
		{ "RawAnimationMt",		ozzlua::RawAnimation::getmetatable },
		{ "AnimationOptimizer", ozzlua::AnimationOptimizer },
		{ "save", lsave },
		{ NULL, NULL },
	};
	luaL_setfuncs(L, lib, 0);
	return 1;
}

namespace bee::lua {
	template <>
	struct udata<ozz::animation::offline::RawAnimation> {
		static inline auto name = "ozz::RawAnimation";
		static inline auto metatable = ozzlua::RawAnimation::metatable;
	};
}
