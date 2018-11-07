#include "preload_module.h"

extern "C" {
int luaopen_bgfx(lua_State* L);
int luaopen_bgfx_baselib(lua_State* L);
int luaopen_bgfx_nuklear(lua_State* L);
int luaopen_bgfx_util(lua_State* L);
int luaopen_bullet(lua_State* L);
int luaopen_clibs(lua_State* L);
int luaopen_crypt(lua_State* L);
int luaopen_debugger_hookmgr(lua_State* L);
int luaopen_hierarchy(lua_State* L);
int luaopen_hierarchy_animation(lua_State* L);
int luaopen_lsocket(lua_State* L);
int luaopen_math3d(lua_State* L);
int luaopen_math3d_baselib(lua_State* L);
int luaopen_memoryfile(lua_State* L);
int luaopen_protocol(lua_State* L);
int luaopen_remotedebug(lua_State* L);
int luaopen_thread(lua_State* L);
}

std::map<std::string, lua_CFunction> preload_module() {
	return {
		{ "bgfx", luaopen_bgfx },
		{ "bgfx.baselib", luaopen_bgfx_baselib },
		{ "bgfx.nuklear", luaopen_bgfx_nuklear },
		{ "bgfx.util", luaopen_bgfx_util },
		{ "bullet", luaopen_bullet },
		{ "clibs", luaopen_clibs },
		{ "crypt", luaopen_crypt },
		{ "debugger.hookmgr", luaopen_debugger_hookmgr },
		{ "hierarchy", luaopen_hierarchy },
		{ "hierarchy.animation", luaopen_hierarchy_animation },
		{ "lsocket", luaopen_lsocket },
		{ "math3d", luaopen_math3d },
		{ "math3d.baselib", luaopen_math3d_baselib },
		{ "memoryfile", luaopen_memoryfile },
		{ "protocol", luaopen_protocol },
		{ "remotedebug", luaopen_remotedebug },
		{ "thread", luaopen_thread },
	};
}
