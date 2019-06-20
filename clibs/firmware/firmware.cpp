#include <lua.hpp>
#include "incbin.h"
#include <string_view>
#include <map>

INCBIN(FirmwareBootstrap, "../../engine/firmware/bootstrap.lua");
INCBIN(FirmwareIo, "../../engine/firmware/io.lua");
INCBIN(FirmwareVfs, "../../engine/firmware/vfs.lua");

struct bin {
	const char* data;
	size_t      size;
};

#define INIT_BIN(name) { (const char*)g##name##Data, (size_t)g##name##Size }

std::map<std::string_view, bin> firmware = {
	{ "bootstrap.lua", INIT_BIN(FirmwareBootstrap) },
	{ "io.lua", INIT_BIN(FirmwareIo) },
	{ "vfs.lua", INIT_BIN(FirmwareVfs) },
};

static int load_resource(lua_State* L, const std::string_view& filename, const char* chunkname) {
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
        lua_pushnil(L);
        lua_pushfstring(L, "%s:No such file or directory.", filename.data());
		return LUA_ERRRUN;
	}
	auto file = it->second;
    return luaL_loadbuffer(L, file.data, file.size, chunkname);
}

static int lloadfile(lua_State* L) {
	size_t size;
	const char* name = luaL_checklstring(L, 1, &size);
	lua_pushstring(L, "@/firmware/");
	lua_pushvalue(L, 1);
	lua_concat(L, 2);
	if (LUA_OK != load_resource(L, std::string_view(name, size), lua_tostring(L, -1))) {
		return 2;
	}
	return 1;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_firmware(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "loadfile", lloadfile },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
    return 1;
}
