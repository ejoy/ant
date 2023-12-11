#include <lua.hpp>
#include <bee/lua/binding.h>

#include "ozz.h"

#include <ozz/animation/offline/animation_builder.h>
#include <ozz/animation/runtime/skeleton_utils.h>

#include <cstring>

namespace ozzlua {
	namespace Animation {
		int create(lua_State* L, ozz::animation::Animation&& v);
	}
}

namespace ozzlua::RawAnimation {
	static int setup(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 2);
		raw.duration = (float)lua_tonumber(L, 3);
		raw.tracks.resize(ske.num_joints());
		return 0;
	}

	static int push_prekey(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 2);
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
		auto& raw = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		ozz::animation::offline::AnimationBuilder builder;
		ozz::animation::Animation* animation = builder(raw).release();
		if (!animation) {
			luaL_error(L, "Failed to build animation");
			return 0;
		}
		return ozzlua::Animation::create(L, std::move(*animation));
	}

	static int clear(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		raw.tracks.clear();
		return 0;
	}

	static int clear_prekey(lua_State* L) {
		auto& raw = bee::lua::checkudata<ozzRawAnimation>(L, 1);
		auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 2);
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
		bee::lua::getmetatable<ozzRawAnimation>(L);
		return 1;
	}

	static int create(lua_State* L) {
		bee::lua::newudata<ozzRawAnimation>(L);
		return 1;
	}
}

void init_offline(lua_State* L) {
	static luaL_Reg lib[] = {
		{ "RawAnimation",		ozzlua::RawAnimation::create },
		{ "RawAnimationMt",		ozzlua::RawAnimation::getmetatable },
		{ NULL, NULL },
	};
	luaL_setfuncs(L, lib, 0);
}

namespace bee::lua {
	template <>
	struct udata<ozzRawAnimation> {
		static inline auto name = "ozzRawAnimation";
		static inline auto metatable = ozzlua::RawAnimation::metatable;
	};
}
