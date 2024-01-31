#include <lua.hpp>
#include <string_view>
#include <map>
#include <string>

#include "FirmwareBootstrap.h"
#include "FirmwareIo.h"
#include "FirmwareVfs.h"
#include "FirmwareInitThread.h"
#include "FirmwareDebugger.h"

struct bin {
	const char* data;
	size_t      size;
};

#define INIT_BIN(name) { (const char*)g##name##Data, sizeof(g##name##Data) - 1 }

std::map<std::string_view, bin> firmware = {
	{ "bootstrap.lua", INIT_BIN(FirmwareBootstrap) },
	{ "io.lua", INIT_BIN(FirmwareIo) },
	{ "vfs.lua", INIT_BIN(FirmwareVfs) },
	{ "init_thread.lua", INIT_BIN(FirmwareInitThread) },
	{ "debugger.lua", INIT_BIN(FirmwareDebugger) },
};

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

static int lloadfile(lua_State* L) {
	std::string_view filename  = luaL_checkstrview(L, 1);
	auto def_chunkname = "@/engine/firmware/"+std::string(filename);
	std::string_view chunkname = luaL_optstrview(L, 2, def_chunkname.c_str());
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
		lua_pushnil(L);
		lua_pushfstring(L, "%s:No such file or directory.", filename.data());
		return 2;
	}
	auto file = it->second;
	if (LUA_OK != luaL_loadbuffer(L, file.data, file.size, chunkname.data()/*file.data*/)) {
		lua_pushnil(L);
		lua_insert(L, -2);
		return 2;
	}
	return 1;
}

static int lreadfile(lua_State* L) {
	std::string_view filename  = luaL_checkstrview(L, 1);
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
		lua_pushnil(L);
		lua_pushfstring(L, "%s:No such file or directory.", filename.data());
		return 2;
	}
	auto file = it->second;
	lua_pushlstring(L, file.data, file.size);
	return 1;
}

extern "C"
int luaopen_firmware(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "loadfile", lloadfile },
		{ "readfile", lreadfile },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
