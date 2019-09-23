#include <lua.hpp>
#include "incbin.h"
#include <string_view>
#include <map>

INCBIN(FirmwareBootstrap, "../../engine/firmware/bootstrap.lua");
INCBIN(FirmwareIo, "../../engine/firmware/io.lua");
INCBIN(FirmwareVfs, "../../engine/firmware/vfs.lua");

#if defined(__MINGW32__)
#define FW_PLAT "mingw"
#elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#define FW_PLAT "osx"
#elif defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__)
#define FW_PLAT "ios"
#elif defined(_MSC_VER)
#define FW_PLAT "msvc"
#endif

#if defined(_DEBUG)
#define FW_MODE "debug"
#else
#define FW_MODE "release"
#endif

#define FW_ODIR "o/" FW_PLAT "/" FW_MODE "/"

INCBIN(FirmwareFsImage,   FW_ODIR "fs_imgui_image.sc");
INCBIN(FirmwareVsImage,   FW_ODIR "vs_imgui_image.sc");
INCBIN(FirmwareFsOcornut, FW_ODIR "fs_ocornut_imgui.sc");
INCBIN(FirmwareVsOcornut, FW_ODIR "vs_ocornut_imgui.sc");

struct bin {
	const char* data;
	size_t      size;
};

#define INIT_BIN(name) { (const char*)g##name##Data, (size_t)g##name##Size }

std::map<std::string_view, bin> firmware = {
	{ "bootstrap.lua", INIT_BIN(FirmwareBootstrap) },
	{ "io.lua", INIT_BIN(FirmwareIo) },
	{ "vfs.lua", INIT_BIN(FirmwareVfs) },

	{ "fs_imgui_image.sc", INIT_BIN(FirmwareFsImage) },
	{ "vs_imgui_image.sc", INIT_BIN(FirmwareVsImage) },
	{ "fs_ocornut_imgui.sc", INIT_BIN(FirmwareFsOcornut) },
	{ "vs_ocornut_imgui.sc", INIT_BIN(FirmwareVsOcornut) },
};

static std::string_view luaL_checkstrview(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, 1, &sz);
	return std::string_view(str, sz);
}

static int lloadfile(lua_State* L) {
	std::string_view filename  = luaL_checkstrview(L, 1);
	auto it = firmware.find(filename);
	if (it == firmware.end()) {
		lua_pushnil(L);
		lua_pushfstring(L, "%s:No such file or directory.", filename.data());
		return 2;
	}
	auto file = it->second;
	if (LUA_OK != luaL_loadbuffer(L, file.data, file.size, file.data)) {
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
#if defined(_WIN32)
__declspec(dllexport)
#endif
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
