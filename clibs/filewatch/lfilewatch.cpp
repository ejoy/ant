#include <lua.hpp>
#include "fsevent.h"
#include "unicode.h"

namespace ant { namespace lua {
#if defined(_WIN32)
	typedef std::wstring string_type;
#else
	typedef std::string string_type;
#endif

	inline string_type to_string(lua_State* L, int idx)
	{
		size_t len = 0;
		const char* buf = luaL_checklstring(L, idx, &len);
#if defined(_WIN32)
		return u2w(std::string_view(buf, len));
#else
		return std::string(buf, len);
#endif
	}

	inline void push_string(lua_State* L, const string_type& str)
	{
#if defined(_WIN32) 
		std::string utf8 = w2u(str);
		lua_pushlstring(L, utf8.data(), utf8.size());
#else
		lua_pushlstring(L, str.data(), str.size());
#endif
	}
}}


namespace luafw {
	static ant::fsevent::watch& to(lua_State* L) {
		return *(ant::fsevent::watch*)lua_touserdata(L, lua_upvalueindex(1));
	}
	static int add(lua_State* L) {
		ant::fsevent::watch& self = to(L);
		auto path = ant::lua::to_string(L, 1);
		ant::fsevent::taskid id = self.add(path);
		if (id == ant::fsevent::kInvalidTaskId) {
			lua_pushnil(L);
			//lua_pushstring(L, ant::w2u(ant::error_message()).c_str());
			return 1;
		}
		lua_pushinteger(L, id);
		return 1;
	}

	static int remove(lua_State* L) {
		ant::fsevent::watch& self = to(L);
		self.remove((ant::fsevent::taskid)luaL_checkinteger(L, 1));
		return 0;
	}

	static int select(lua_State* L) {
		ant::fsevent::watch& self = to(L);
		ant::fsevent::notify notify;
		if (!self.select(notify)) {
			return 0;
		}
		switch (notify.type) {
		case ant::fsevent::tasktype::Error:
			lua_pushstring(L, "error");
			break;
		case ant::fsevent::tasktype::Create:
			lua_pushstring(L, "create");
			break;
		case ant::fsevent::tasktype::Delete:
			lua_pushstring(L, "delete");
			break;
		case ant::fsevent::tasktype::Modify:
			lua_pushstring(L, "modify");
			break;
		case ant::fsevent::tasktype::Rename:
			lua_pushstring(L, "rename");
			break;
		default:
			lua_pushstring(L, "unknown");
			break;
		}
		ant::lua::push_string(L, notify.path);
		return 2;
	}

	static int gc(lua_State* L) {
		ant::fsevent::watch& self = to(L);
		self.~watch();
		return 0;
	}
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_filewatch(lua_State* L) {
	ant::fsevent::watch* fw = (ant::fsevent::watch*)lua_newuserdata(L, sizeof(ant::fsevent::watch));
    new (fw)ant::fsevent::watch;

    static luaL_Reg lib[] = {
        { "add",    luafw::add },
        { "remove", luafw::remove },
        { "select", luafw::select },
        { "__gc",   luafw::gc },
        { NULL, NULL }
    };
    lua_newtable(L);
    lua_pushvalue(L, -2);
    luaL_setfuncs(L, lib, 1);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    return 1;
}
