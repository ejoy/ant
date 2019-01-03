#include <lua.hpp>
#include "binding.h"
#include "file.h"
#include "file_helper.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <utime.h>
#include <errno.h>
#include <dlfcn.h>

namespace ant::lua_posixfs {

    const char* dll_path(void* module_handle) {
        ::Dl_info dl_info;
        dl_info.dli_fname = 0;
        int const ret = ::dladdr(module_handle, &dl_info);
        if (0 != ret && dl_info.dli_fname != NULL) {
            return dl_info.dli_fname;
        }
        return 0;
    }

    static int lgetcwd(lua_State* L) {
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        size_t size = 256; 
        for (;;) {
            char* path = luaL_prepbuffsize(&b, size);
            if (getcwd(path, size) != NULL) {
                lua_pushstring(L, path);
                return 1;
            }
            if (errno != ERANGE) {
                lua_pushstring(L, "getcwd() failed");
                return lua_error(L);
            }
            size *= 2;
        }
    }

    static int lstat(lua_State* L) {
        struct stat info;
        if (stat(luaL_checkstring(L, 1), &info)) {
            return 0;
        }
        if (S_ISDIR(info.st_mode)) {
            lua_pushstring(L, "dir");
            return 1;
        }
        if (S_ISREG(info.st_mode)) {
            lua_pushstring(L, "file");
            return 1;
        }
        lua_pushstring(L, "unknown");
        return 1;
    }

#define PERMS_MASK (S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IWOTH | S_IXOTH)

    static int lpermissions(lua_State* L) {
        if (lua_isnoneornil(L, 2)) {
            struct stat info;
            if (stat(luaL_checkstring(L, 1), &info)) {
                return 0;
            }
            lua_pushinteger(L, info.st_mode & PERMS_MASK);
            return 1;
        }
        int res = chmod(luaL_checkstring(L, 1), PERMS_MASK & luaL_checkinteger(L, 2));
        lua_pushboolean(L, res == 0);
        return 1;
    }

    static int llast_write_time(lua_State* L) {
        if (lua_isnoneornil(L, 2)) {
            struct stat info;
            if (stat(luaL_checkstring(L, 1), &info)) {
                return 0;
            }
            lua_pushinteger(L, info.st_mtime);
            return 1;
        }
        struct stat info;
        if (stat(luaL_checkstring(L, 1), &info)) {
            lua_pushboolean(L, 0);
            return 1;
        }
        utimbuf buf;
        buf.actime = info.st_atime;
        buf.modtime = luaL_checkinteger(L, 2);
        if (utime(luaL_checkstring(L, 1), &buf)) {
            lua_pushboolean(L, 0);
            return 1;
        }
        lua_pushboolean(L, 1);
        return 1;
    }

    static int lmkdir(lua_State* L) {
        int res = mkdir(luaL_checkstring(L, 1), S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH);
        lua_pushboolean(L, res == 0);
        return 1;
    }

    struct dirIter {
        int  closed;
        DIR* dir;
    };

    static int ldirnext(lua_State* L) {
        dirIter* d = (dirIter*)(lua_touserdata(L, lua_upvalueindex(1)));
        luaL_argcheck(L, d->closed == 0, 1, "closed directory");
        struct dirent* entry;
        if ((entry = readdir(d->dir)) != NULL) {
            lua_pushstring(L, entry->d_name);
            return 1;
        }
        else {
            closedir(d->dir);
            d->closed = 1;
            return 0;
        }
    }

    static int ldirclose (lua_State* L) {
        dirIter* d = (dirIter*)lua_touserdata(L, 1);
        if (!d->closed && d->dir) {
            closedir(d->dir);
        }
        d->closed = 1;
        return 0;
    }

    static int ldir(lua_State* L) {
        const char* path = luaL_checkstring (L, 1);
        dirIter* d = (dirIter*)lua_newuserdata(L, sizeof(dirIter));
        lua_newtable(L);
        lua_pushcclosure(L, ldirclose, 0);
        lua_setfield(L, -2, "__gc");
        lua_setmetatable(L, -2);
        lua_pushcclosure(L, ldirnext, 1);
        d->closed = 0;
        d->dir = opendir(path);
        if (d->dir == NULL) {
            luaL_error(L, "cannot open %s: %s", path, strerror(errno));
        }
        return 1;
    }

    static int lexe_path(lua_State* L)  {
        const char* path = dll_path((void*)&lua_newstate);
        if (!path) {
            return 0;
        }
        lua_pushstring(L, path);
        return 1;
    }

    static int ldll_path(lua_State* L)  {
        const char* path = dll_path((void*)&ldll_path);
        if (!path) {
            return 0;
        }
        lua_pushstring(L, path);
        return 1;
    }

    static int lfilelock(lua_State* L) {
        file::handle fd = file::lock(luaL_checkstring(L, 1));
        if (!fd) {
            lua_pushnil(L);
            lua_pushstring(L, make_syserror().what());
            return 2;
        }
        FILE* f = file::open(fd, file::mode::eWrite);
        if (!f) {
            lua_pushnil(L);
            lua_pushstring(L, make_crterror().what());
            return 2;
        }
        lua::newfile(L, f);
        return 1;
    }

    int luaopen(lua_State* L) {
        static luaL_Reg lib[] = {
            { "getcwd", lgetcwd },
            { "stat", lstat },
            { "permissions", lpermissions },
            { "last_write_time", llast_write_time },
            { "mkdir", lmkdir },
            { "dir", ldir },
            { "exe_path", lexe_path },
            { "dll_path", ldll_path },
            { "filelock", lfilelock },
            { NULL, NULL }
        };
        luaL_newlib(L, lib);
        return 1;
    }
}

ANT_LUA_API
int luaopen_filesystem_posix(lua_State* L) {
    return ant::lua_filesystem::luaopen(L);
}
