#include <lua.hpp>
#include <string_view>

using namespace std::literals;

static constexpr std::string_view initscript = R"(
__ANT_RUNTIME__ = ...
local vfs = {}
local fastio = require "fastio"
if __ANT_RUNTIME__ then
    local fw = require "firmware"
    function vfs.read(path)
        assert(path:sub(1, 17) == "/engine/firmware/")
        local data = fw.readall_v(path:sub(18))
        return data, path
    end
else
    function vfs.read(path)
        assert(path:sub(1, 1) == "/")
        local lpath = path:sub(2)
        local data = fastio.readall_v(lpath, path)
        return data, lpath
    end
end
function loadfile(path)
    local mem, symbol = vfs.read(path)
    if not mem then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    return fastio.loadlua(mem, symbol)
end
function dofile(path)
    local func, err = loadfile(path)
    if not func then
        error(err)
    end
    return func()
end
local PATH = "/engine/?.lua"
local function searcher_lua(name)
    local filename = name:gsub('%.', '/')
    local path = PATH:gsub('%?', filename)
    local mem, symbol = vfs.read(path)
    if mem then
        local func, err = fastio.loadlua(mem, symbol)
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err))
        end
        return func
    end
    return "no file '"..path.."'"
end
package = {
    loaded = package.loaded,
    preload = package.preload,
    searchers = {
        package.searchers[1],
        searcher_lua,
    },

    -- compatible debugger
    config = package.config,
    loadlib = package.loadlib,
}
return vfs
)"sv;

#if defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__) || defined(__ANDROID__)
static bool __ANT_RUNTIME__ = true;
#elif defined(_WIN32)
#include <windows.h>
static bool GET_ANT_RUNTIME() {
    int argc;
    wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
    if (argv && argc >= 2) {
        if (wcscmp(argv[1], L"-rt") == 0) {
            LocalFree(argv);
            return true;
        }
    }
    size_t prog_sz = wcslen(argv[0]);
    bool is_rt = true;
    if (prog_sz >=7 && wcscmp(argv[0] + prog_sz - 7, L"ant.exe") == 0) {
        is_rt = false;
    } else if (prog_sz >=3 && wcscmp(argv[0] + prog_sz - 3, L"ant") == 0) {
        is_rt = false;
    }
    LocalFree(argv);
    return is_rt;
}
static bool __ANT_RUNTIME__ = GET_ANT_RUNTIME();
#elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#include <crt_externs.h>
static bool GET_ANT_RUNTIME() {
    int argc = *_NSGetArgc();
    char** argv = *_NSGetArgv();
    if (argv && argc >= 2) {
        if (strcmp(argv[1], "-rt") == 0) {
            return true;
        }
    }
    size_t prog_sz = strlen(argv[0]);
    bool is_rt = true;
    if (prog_sz >=7 && strcmp(argv[0] + prog_sz - 7, "ant.exe") == 0) {
        is_rt = false;
    } else if (prog_sz >=3 && strcmp(argv[0] + prog_sz - 3, "ant") == 0) {
        is_rt = false;
    }
    return false;
}
static bool __ANT_RUNTIME__ = GET_ANT_RUNTIME();
#else
static bool __ANT_RUNTIME__ = false;
#endif

extern "C"
int luaopen_vfs(lua_State* L) {
    if (luaL_loadbuffer(L, initscript.data(), initscript.size(), "=(vfs)") != LUA_OK) {
        return lua_error(L);
    }
    lua_pushboolean(L, __ANT_RUNTIME__);
    lua_call(L, 1, 1);
    return 1;
}
