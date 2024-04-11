#include <lua.hpp>

#if defined (_WIN32)

#include <Windows.h>
#include <bee/platform/win/cwtf8.h>

static unsigned long __stdcall utf8_GetModuleFileNameA(HMODULE module, char* filename, unsigned long size) {
    wchar_t* tmp = (wchar_t*)calloc(size, sizeof(wchar_t));
    if (!tmp) {
        SetLastError(ERROR_NOT_ENOUGH_MEMORY);
        return 0;
    }
    DWORD tmplen = GetModuleFileNameW(module, tmp, size);
    if (tmplen == 0) {
        free(tmp);
        return 0;
    }
    size_t len = wtf8_from_utf16_length(tmp, tmplen);
    if (len > size) {
        free(tmp);
        SetLastError(ERROR_NOT_ENOUGH_MEMORY);
        return 0;
    }
    wtf8_from_utf16(tmp, tmplen, filename, len);
    free(tmp);
    filename[len] = '\0';
    return (unsigned long)len;
}

void pushprogdir(lua_State *L) {
    char buff[MAX_PATH + 1];
    char *lb;
    DWORD nsize = sizeof(buff) / sizeof(char);
    DWORD n = utf8_GetModuleFileNameA(NULL, buff, nsize);  /* get exec. name */
    if (n == 0 || n == nsize || (lb = strrchr(buff, '\\')) == NULL)
        luaL_error(L, "unable to get progdir");
    else {
        lua_pushlstring(L, buff, lb - buff + 1);
    }
}

#elif defined(__APPLE__)

#include <mach-o/dyld.h>
#include <stdlib.h>
#include <string.h>

void pushprogdir(lua_State *L) {
    uint32_t bufsize = 0;
    _NSGetExecutablePath(0, &bufsize);
    if (bufsize <= 1) {
        luaL_error(L, "unable to get progdir");
        return;
    }
    char* linkname = (char*)malloc(bufsize+1);
    int rv = _NSGetExecutablePath(linkname, &bufsize);
    if (rv != 0) {
        free(linkname);
        luaL_error(L, "unable to get progdir");
        return;
    }
    linkname[bufsize-1] = '\0';
    const char* lb = strrchr(linkname, '/');
    if (lb) {
        lua_pushlstring(L, linkname, lb - linkname + 1);
    }
    else {
        lua_pushstring(L, linkname);
    }
    free(linkname);
}

#elif defined(__linux__)

#include <unistd.h>
#include <memory.h>

void pushprogdir(lua_State *L) {
    char linkname[1024];
    ssize_t r = readlink("/proc/self/exe", linkname, sizeof(linkname)-1);
    if (r < 0 || r == sizeof(linkname)-1) {
        luaL_error(L, "unable to get progdir");
        return;
    }
    linkname[r] = '\0';
    const char* lb = strrchr(linkname, '/');
    if (lb) {
        lua_pushlstring(L, linkname, lb - linkname + 1);
    }
    else {
        lua_pushstring(L, linkname);
    }
}
#else
void pushprogdir(lua_State *L) {
    luaL_error(L, "unable to get progdir");
}
#endif
