#include <lua.hpp>
#include <bee/lua/udata.h>
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
	static int set_duration(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		raw.duration = (float)luaL_checknumber(L, 2);
		return 0;
	}
	static int resize(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		raw.tracks.resize(luaL_checkinteger(L, 2));
		return 0;
	}
	static int add_key(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		lua_Integer joint_index = luaL_checkinteger(L, 2);
		float time = (float)luaL_checknumber(L, 3);
		auto const& scale = *(ozz::math::Float3*)lua_touserdata(L, 4);
		auto const& rotation = *(ozz::math::Quaternion*)lua_touserdata(L, 5);
		auto const& translation = *(ozz::math::Float3*)lua_touserdata(L, 6);

		auto& track = raw.tracks[joint_index-1];
		track.scales.emplace_back(ozz::animation::offline::RawAnimation::ScaleKey { time, scale });
		track.rotations.emplace_back(ozz::animation::offline::RawAnimation::RotationKey { time, rotation });
		track.translations.emplace_back(ozz::animation::offline::RawAnimation::TranslationKey { time, translation });
		return 0;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "set_duration", set_duration },
			{ "resize", resize },
			{ "add_key", add_key },
			{ nullptr, nullptr },
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

		auto& raw_optimized_animation = bee::lua::newudata<ozz::animation::offline::RawAnimation>(L);
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

		lua_struct::pack(L, statistics);
		return 2;
	}

	static int AnimationBuilder(lua_State* L) {
		auto& raw_animation = bee::lua::checkudata<ozz::animation::offline::RawAnimation>(L, 1);
		ozz::animation::offline::AnimationBuilder builder;
		builder.iframe_interval = (float)luaL_optnumber(L, 2, 10.f);
		auto animation = builder(raw_animation);
		if (!animation) {
			luaL_error(L, "Failed to build runtime animation.");
			return 0;
		}
		return ozzlua::Animation::create(L, std::move(*animation.get()));
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

extern "C"
int luaopen_ozz_offline(lua_State *L) {
	static luaL_Reg lib[] = {
		{ "RawAnimation", ozzlua::RawAnimation::create },
		{ "RawAnimationMt", ozzlua::RawAnimation::getmetatable },
		{ "AnimationOptimizer", ozzlua::AnimationOptimizer },
		{ "AnimationBuilder", ozzlua::AnimationBuilder },
		{ "save", lsave },
		{ NULL, NULL },
	};
	luaL_newlib(L, lib);
	return 1;
}

namespace bee::lua {
	template <>
	struct udata<ozz::animation::offline::RawAnimation> {
		static inline auto metatable = ozzlua::RawAnimation::metatable;
	};
}
