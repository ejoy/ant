#include <lua.hpp>
#include <bee/lua/udata.h>

#include "ozz.h"

#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>

#include <cstring>

namespace ozzlua::Uint16Verctor {
	static int __len(lua_State* L) {
		auto& vec = bee::lua::checkudata<ozzUint16Verctor>(L, 1);
		lua_pushinteger(L, vec.size());
		return 1;
	}
	static int __index(lua_State* L) {
		auto& vec = bee::lua::checkudata<ozzUint16Verctor>(L, 1);
		size_t idx = (size_t)luaL_checkinteger(L, 2);
		if (idx <= 0 || idx > vec.size()){
			luaL_error(L, "invalid index:", idx);
		}
		lua_pushinteger(L, vec[idx-1]);
		return 1;
	}
	static void metatable(lua_State* L) {
		static luaL_Reg mt[] = {
			{ "__index", __index },
			{ "__len", __len },
			{ nullptr, nullptr }
		};
		luaL_setfuncs(L, mt, 0);
	}
	static int create(lua_State* L) {
		switch (lua_type(L, 1)) {
		case LUA_TNIL:
		case LUA_TNONE:
			bee::lua::newudata<ozzUint16Verctor>(L);
			break;
		case LUA_TNUMBER: {
			lua_Integer n = luaL_checkinteger(L, 1);
			bee::lua::newudata<ozzUint16Verctor>(L, (size_t)n);
			break;
		}
		case LUA_TSTRING: {
			size_t size = 0;
			const uint16_t* data = (const uint16_t*)lua_tolstring(L, 1, &size);
			if (size % sizeof(uint16_t) != 0) {
				return luaL_error(L, "init data size is not valid, mod %d == 0", sizeof(uint16_t));
			}
			bee::lua::newudata<ozzUint16Verctor>(L, (size_t)(size / sizeof(uint16_t)), data);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type");
		}
		return 1;
	}
}

namespace ozzlua::MatrixVector {
	static int count(lua_State* L) {
		auto& bp = bee::lua::checkudata<ozzMatrixVector>(L, 1);
		lua_pushinteger(L, bp.size());
		return 1;
	}

	static int pointer(lua_State* L) {
		auto& bp = bee::lua::checkudata<ozzMatrixVector>(L, 1);
		lua_pushlightuserdata(L, &bp[0]);
		return 1;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "count", count },
			{ "pointer", pointer },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}
	static int getmetatable(lua_State* L) {
		bee::lua::getmetatable<ozzMatrixVector>(L);
		return 1;
	}
	static int create(lua_State* L) {
		switch (lua_type(L, 1)) {
		case LUA_TNIL:
		case LUA_TNONE:
			bee::lua::newudata<ozzMatrixVector>(L);
			break;
		case LUA_TNUMBER: {
			lua_Integer n = luaL_checkinteger(L, 1);
			bee::lua::newudata<ozzMatrixVector>(L, (size_t)n);
			break;
		}
		case LUA_TSTRING: {
			size_t size = 0;
			const float* data = (const float*)lua_tolstring(L, 1, &size);
			if (size % sizeof(ozz::math::Float4x4) != 0) {
				return luaL_error(L, "init data size is not valid, mod %d == 0", sizeof(ozz::math::Float4x4));
			}
			bee::lua::newudata<ozzMatrixVector>(L, (size_t)(size / sizeof(ozz::math::Float4x4)), data);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type");
		}
		return 1;
	}
}

namespace ozzlua::SoaTransformVector {
	static void metatable(lua_State* L) {
	}
	static int create(lua_State* L) {
		switch (lua_type(L, 1)) {
		case LUA_TNUMBER: {
			lua_Integer n = luaL_checkinteger(L, 1);
			bee::lua::newudata<ozzSoaTransformVector>(L, (size_t)n);
			break;
		}
		default:
			return luaL_error(L, "argument 2 is not support type");
		}
		return 1;
	}
}

namespace ozzlua::Animation {
	static int duration(lua_State* L) {
		auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
		lua_pushnumber(L, animation.duration());
		return 1;
	}

	static int num_tracks(lua_State* L) {
		auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
		lua_pushinteger(L, animation.num_tracks());
		return 1;
	}

	static int num_soa_tracks(lua_State* L) {
		auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
		lua_pushinteger(L, animation.num_soa_tracks());
		return 1;
	}

	static int name(lua_State* L) {
		auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
		lua_pushstring(L, animation.name());
		return 1;
	}

	static int size(lua_State* L) {
		auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
		lua_pushinteger(L, animation.size());
		return 1;
	}

	static void metatable(lua_State* L) {
		static luaL_Reg lib[] = {
			{ "duration", duration },
			{ "num_tracks",	num_tracks },
			{ "num_soa_tracks", num_soa_tracks },
			{ "name", name },
			{ "size", size },
			{ nullptr, nullptr }
		};
		luaL_newlibtable(L, lib);
		luaL_setfuncs(L, lib, 0);
		lua_setfield(L, -2, "__index");
	}

	int create(lua_State* L, ozz::animation::Animation&& v) {
		bee::lua::newudata<ozz::animation::Animation>(L, std::forward<ozz::animation::Animation>(v));
		return 1;
	}

	bool load(lua_State* L, ozz::io::IArchive& ia) {
		if (!ia.TestTag<ozz::animation::Animation>()) {
			return false;
		}
		auto& o = bee::lua::newudata<ozz::animation::Animation>(L);
		ia >> (ozz::animation::Animation&)o;
		return true;
	}
}

void init_animation(lua_State* L) {
	static luaL_Reg lib[] = {
		{ "Uint16Verctor",		ozzlua::Uint16Verctor::create },
		{ "MatrixVector",		ozzlua::MatrixVector::create },
		{ "SoaTransformVector",	ozzlua::SoaTransformVector::create },
		{ "MatrixVectorMt",		ozzlua::MatrixVector::getmetatable },
		{ NULL, NULL },
	};
	luaL_setfuncs(L, lib, 0);
}

namespace bee::lua {
	template <>
	struct udata<ozzUint16Verctor> {
		static inline auto metatable = ozzlua::Uint16Verctor::metatable;
	};
	template <>
	struct udata<ozzMatrixVector> {
		static inline auto metatable = ozzlua::MatrixVector::metatable;
	};
	template <>
	struct udata<ozzSoaTransformVector> {
		static inline auto metatable = ozzlua::SoaTransformVector::metatable;
	};
	template <>
	struct udata<ozz::animation::Animation> {
		static inline auto metatable = ozzlua::Animation::metatable;
	};
}
