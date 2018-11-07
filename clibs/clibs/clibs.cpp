#include <lua.hpp>
#include <map>
#include <sstream>
#include <mutex>
#include <Windows.h>
#include "foreach_clibs.h"
#include "preload_module.h"

std::once_flag g_initialized;
std::map<std::string, lua_CFunction> g_modules = preload_module();

static std::wstring u2w(const char* buf, size_t len) {
	if (!buf || !len) return L"";
	int wlen = ::MultiByteToWideChar(CP_UTF8, 0, buf, len, NULL, 0);
	if (wlen <= 0) return L"";
	std::vector<wchar_t> result(wlen);
	::MultiByteToWideChar(CP_UTF8, 0, buf, len, result.data(), wlen);
	return std::wstring(result.data(), result.size());
}

static std::wstring luaL_checkwstring(lua_State* L, int idx) {
	size_t len = 0;
	const char* buf = luaL_checklstring(L, idx, &len);
	return u2w(buf, len);
}

std::vector<std::wstring> split(const std::wstring& s, wchar_t delimiter) {
	std::vector<std::wstring> tokens;
	std::wstring token;
	std::wistringstream stream(s);
	while (std::getline(stream, token, delimiter)) {
		tokens.push_back(token);
	}
	return tokens;
}

static std::string toluaname(const std::string& api) {
	std::string out = api.substr(8);
	std::replace_if(out.begin(), out.end()
		,[](char c)->bool { return c == '_'; }
		, '.'
	);
	return out;
}

static void init_once(lua_State* L) {
	std::wstring cpath = luaL_checkwstring(L, 1);
	try {
		for (auto& dir : split(cpath, L';')) {
			size_t pos = dir.find_first_of(L'?');
			if (pos != std::wstring::npos) {
				if (dir[pos - 1] != L'/' && dir[pos - 1] != L'\\') {
					continue;
				}
				dir = dir.substr(0, pos);
			}
			foreach_clibs(dir, [&](const fs::path& dll, const std::string& api) {
				std::string name = toluaname(api);
				if (g_modules.find(name) != g_modules.end()) {
					return;
				}
				HMODULE m = LoadLibraryW(dll.c_str());
				if (!m) {
					return;
				}
				lua_CFunction f = (lua_CFunction)GetProcAddress(m, api.c_str());
				if (!f) {
					return;
				}
				g_modules.insert(std::make_pair(name, f));
			});
		}
	}
	catch (std::exception& e) {
		lua_pushstring(L, e.what());
		lua_error(L);
	}
}

static int init(lua_State* L) {
    std::call_once(g_initialized, [&](){
		init_once(L);
	});
	return 0;
}

static int all(lua_State *L) {
	lua_newtable(L);
	for (auto& m : g_modules) {
		lua_pushlstring(L, m.first.data(), m.first.size());
		lua_pushcfunction(L, m.second);
		lua_rawset(L, -3);
	}
	return 1;
}

static int searcher(lua_State *L) {
	size_t len = 0;
	const char* name = luaL_checklstring(L, 1, &len);
	auto it = g_modules.find(std::string(name, len));
	if (it == g_modules.end()) {
		lua_pushfstring(L, "\n\tno C module '%s'", name);
		return 1;
	}
	lua_pushcfunction(L, it->second);
	lua_pushvalue(L, 1);
	return 2;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_clibs(lua_State* L) {
	luaL_Reg lib[] = {
		{"init", init},
		{"all", all},
		{"searcher", searcher},
		{NULL, NULL},
	};
	luaL_newlib(L, lib);
	return 1;
}
