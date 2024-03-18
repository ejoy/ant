#include <lua.hpp>
#include <string>
#include "firmware.h"
#include "memfile.h"

static std::string_view luaL_checkstrview(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, idx, &sz);
	return std::string_view(str, sz);
}

static std::string_view luaL_optstrview(lua_State* L, int idx, const char* def) {
	size_t sz = 0;
	const char* str = luaL_optlstring(L, idx, def, &sz);
	return std::string_view(str, sz);
}

static int loadfile(lua_State* L) {
	std::string_view filename = luaL_checkstrview(L, 1);
	auto def_chunkname = "@/engine/firmware/"+std::string(filename);
	std::string_view chunkname = luaL_optstrview(L, 2, def_chunkname.c_str());
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
		return luaL_error(L, "%s:No such file or directory.", filename.data());
	}
	auto file = it->second;
	if (LUA_OK != luaL_loadbuffer(L, file.data(), file.size(), chunkname.data()/*file.data*/)) {
		return lua_error(L);
	}
	return 1;
}

static int readall_v(lua_State* L) {
	std::string_view filename = luaL_checkstrview(L, 1);
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
		return luaL_error(L, "%s:No such file or directory.", filename.data());
	}
	auto file = memory_file_cstr(it->second.data(), it->second.size());
	if (!file) {
		return luaL_error(L, "not enough memory");
	}
	lua_pushlightuserdata(L, file);
	return 1;
}

extern "C"
int luaopen_firmware(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "loadfile", loadfile },
		{ "readall_v", readall_v },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
