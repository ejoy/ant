#include <lua.hpp>

#if defined (_WIN32)

#include <Windows.h>

static unsigned long utf8_GetModuleFileNameA(void* module, char* filename, unsigned long size) {
    wchar_t* tmp = (wchar_t*)calloc(size, sizeof(wchar_t));
    unsigned long tmplen = GetModuleFileNameW((HMODULE)module, tmp, size);
    unsigned long ret = WideCharToMultiByte(CP_UTF8, 0, tmp, tmplen + 1, filename, size, NULL, NULL);
    free(tmp);
    return ret - 1;
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
