#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>

#include <windows.h>
#include <Shlobj.h>
#include <sys/stat.h>
#include <wchar.h>

#if _MSC_VER > 0
#include <malloc.h>
#include <io.h>	// for access
#ifdef access
#undef access
#endif
#define access _access

#	ifdef USING_ALLOCA_FOR_VLA
#		define VLA(_TYPE, _VAR, _SIZE)	_TYPE _VAR = (_TYPE*)_alloca(sizeof(_TYPE) * (_SIZE))
#	else//!USING_ALLOCA_FOR_VLA
#		define V(_SIZE)	4096
#	endif //USING_ALLOCA_FOR_VLA
#else //!(_MSC_VER > 0)
#	ifdef USING_ALLOCA_FOR_VLA
#		define VLA(_TYPE, _VAR, _SIZE) _TYPE _VAR[(_SIZE)]
#	else //!USING_ALLOCA_FOR_VLA
#		define V(_SIZE)	(_SIZE)
#	endif //USING_ALLOCA_FOR_VLA

#endif //_MSC_VER > 0


#define STAT_STRUCT struct _stati64
#define STAT_FUNC _wstati64

#ifndef S_ISDIR
#define S_ISDIR(mode)  (mode&_S_IFDIR)
#endif
#ifndef S_ISREG
#define S_ISREG(mode)  (mode&_S_IFREG)
#endif
#ifndef S_ISLNK
#define S_ISLNK(mode)  (0)
#endif
#ifndef S_ISSOCK
#define S_ISSOCK(mode)  (0)
#endif
#ifndef S_ISFIFO
#define S_ISFIFO(mode)  (0)
#endif
#ifndef S_ISCHR
#define S_ISCHR(mode)  (mode&_S_IFCHR)
#endif
#ifndef S_ISBLK
#define S_ISBLK(mode)  (0)
#endif

static int
utf8_filename(lua_State *L, const wchar_t * winfilename, int wsz, char *utf8buffer, int sz) {
	sz = WideCharToMultiByte(CP_UTF8, 0, winfilename, wsz, utf8buffer, sz, NULL, NULL);
	if (sz == 0)
		return luaL_error(L, "convert to utf-8 filename fail");
	return sz;
}

#define DIR_METATABLE "WINFILE_DIR"

struct dir_data {
	HANDLE findfile;
	int closed;
};

static int
windows_filename(lua_State *L, const char * utf8filename, int usz, wchar_t * winbuffer, int wsz) {
	wsz = MultiByteToWideChar(CP_UTF8, 0, utf8filename, usz, winbuffer, wsz);
	if (wsz == 0)
		return luaL_error(L, "convert to windows utf-16 filename fail");
	return wsz;
}

static void
system_error(lua_State *L, DWORD errcode) {
	wchar_t * errormsg;
	DWORD n = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		errcode, 0,
		(void *)&errormsg, sizeof(errormsg),
		NULL);
	if (n == 0) {
		lua_pushfstring(L, "Unknown error %04X", errcode);
	} else {
		int i;
		for (i=n;i>=0;i--) {
			if (errormsg[i] == 0 || errormsg[i] == '\n' || errormsg[i] == '\r')
				--n;
			else {
				break;
			}
		}
		char tmp[V(n * 3)];
		int len = utf8_filename(L, errormsg, n, tmp, n*3);
		lua_pushlstring(L, tmp, len);
		HeapFree(GetProcessHeap(), 0, errormsg);
	}
}

static int
error_return(lua_State *L) {
	lua_pushnil(L);
	system_error(L, GetLastError());
	return 2;
}

static int
lshortname(lua_State *L) {
	size_t sz;
	const char * filename = luaL_checklstring(L, 1, &sz);
	wchar_t winname[V(sz + 1)];
	int wsz = windows_filename(L, filename, (int)sz, winname, (int)sz);
	winname[wsz] = 0;
	wchar_t shortname[V(sz + 1)];
	DWORD ssz = GetShortPathNameW(winname, shortname, (DWORD)sz);
	if (ssz == 0) {
		return error_return(L);
	}

	char tmp[V(ssz * 3)];
	int s = utf8_filename(L, shortname, ssz, tmp, ssz*3);
	lua_pushlstring(L, tmp, s);
	return 1;
}

static void
push_filename(lua_State *L, WIN32_FIND_DATAW *data) {
	size_t wlen = wcsnlen(data->cFileName, MAX_PATH);
	char firstname[V(wlen*3)];
	int ulen = utf8_filename(L, data->cFileName, (int)wlen, firstname, (int)(wlen*3));

	lua_pushlstring(L, firstname, ulen);
}

static int
dir_iter(lua_State *L) {
	struct dir_data *d = luaL_checkudata(L, 1, DIR_METATABLE);
	luaL_argcheck (L, d->closed == 0, 1, "closed directory");
	if (d->findfile == INVALID_HANDLE_VALUE) {
		// no find found
		d->closed = 1;
		return 0;
	}
	if (lua_getuservalue(L, 1) == LUA_TSTRING) {
		// find time
		lua_pushnil(L);
		lua_setuservalue(L, 1);
		return 1;
	} else {
		WIN32_FIND_DATAW data;
		if (FindNextFileW(d->findfile, &data)) {
			push_filename(L, &data);
			return 1;
		} else {
			DWORD errcode = GetLastError();
			FindClose(d->findfile);
			d->findfile = INVALID_HANDLE_VALUE;
			d->closed = 1;
			if (errcode == ERROR_NO_MORE_FILES)
				return 0;
			lua_pushnil(L);
			system_error(L, errcode);
			return 2;
		}
	}
}

static int
dir_close(lua_State *L) {
	struct dir_data *d = luaL_checkudata(L, 1, DIR_METATABLE);
	if (d->findfile != INVALID_HANDLE_VALUE) {
		FindClose(d->findfile);
		d->findfile = INVALID_HANDLE_VALUE;
	}
	d->closed = 1;
	return 0;
}

static int
ldir(lua_State *L) {
	size_t sz;
	const char * pathname = luaL_checklstring(L, 1, &sz);
	wchar_t winname[V(sz+3)];
	int winsz = windows_filename(L, pathname, (int)sz, winname, (int)sz);
	winname[winsz] = '\\';
	winname[winsz+1] = '*';
	winname[winsz+2] = 0;
	WIN32_FIND_DATAW data;
	HANDLE findfile = FindFirstFileW(winname, &data);
	lua_pushcfunction(L, dir_iter);
	if (findfile == INVALID_HANDLE_VALUE) {
		DWORD errcode = GetLastError();
		if (errcode == ERROR_FILE_NOT_FOUND) {
			struct dir_data *d = lua_newuserdata(L, sizeof(*d));
			d->findfile = INVALID_HANDLE_VALUE;
			d->closed = 0;
		} else {
			system_error(L, errcode);
			return lua_error(L);
		}
	} else {
		struct dir_data *d = lua_newuserdata(L, sizeof(*d));
		d->findfile = findfile;
		d->closed = 0;
		push_filename(L, &data);
		lua_setuservalue(L, -2);	// set firstname
	}

	if (luaL_newmetatable(L, DIR_METATABLE)) {
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");

		lua_pushcfunction (L, dir_iter);
		lua_setfield(L, -2, "next");
		lua_pushcfunction (L, dir_close);
		lua_setfield(L, -2, "close");
		lua_pushcfunction (L, dir_close);
		lua_setfield (L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	return 2;
}

static int
lpersonaldir(lua_State *L) {
	wchar_t document[MAX_PATH] = {0};
	LPITEMIDLIST pidl = NULL;
	SHGetSpecialFolderLocation(NULL, CSIDL_PERSONAL, &pidl);
	if (pidl && SHGetPathFromIDListW(pidl, document)) {
		size_t wsz = wcsnlen(document, MAX_PATH);
		char utf8path[MAX_PATH * 3];
		int sz = utf8_filename(L, document, (int)wsz, utf8path, MAX_PATH*3);
		lua_pushlstring(L, utf8path, sz);
		return 1;
	} else {
		return error_return(L);
	}
}

static int
lcurrentdir(lua_State *L) {
	wchar_t path[MAX_PATH];
	char utf8path[MAX_PATH * 3];
	DWORD sz = GetCurrentDirectoryW(MAX_PATH, path);
	if (sz == 0) {
		return error_return(L);
	}
	size_t wsz = wcsnlen(path, MAX_PATH);
	int usz = utf8_filename(L, path, (int)wsz, utf8path, MAX_PATH*3);
	lua_pushlstring(L, utf8path, usz);
	return 1;
}

static int
lchdir(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[V(sz+1)];
	int winsz = windows_filename(L, utf8path, (int)sz, path, (int)sz);
	path[winsz] = 0;
	if (SetCurrentDirectoryW(path) == 0) {
		return error_return(L);
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
ltouch(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[V(sz+1)];
	int winsz = windows_filename(L, utf8path, (int)sz, path, (int)sz);
	path[winsz] = 0;

	HANDLE file = CreateFileW(path, FILE_WRITE_ATTRIBUTES, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (file == INVALID_HANDLE_VALUE) {
		return error_return(L);
	}

	if (lua_gettop(L) == 1) {
		SYSTEMTIME st;
		FILETIME ft;
		GetSystemTime(&st);
		if (!SystemTimeToFileTime(&st, &ft)) {
			error_return(L);
			CloseHandle(file);
			return 2;
		}
		if (!SetFileTime(file, NULL, &ft, &ft)) {
			error_return(L);
			CloseHandle(file);
			return 2;
		}
	} else {
		time_t atime = luaL_checkinteger(L, 2);
		time_t mtime = luaL_optinteger(L, 3, atime);
		FILETIME at, mt;
		at.dwLowDateTime = (DWORD)(atime & 0xffffffff);
		at.dwHighDateTime = (DWORD)(atime >> 32);
		mt.dwLowDateTime = (DWORD)(mtime & 0xffffffff);
		mt.dwHighDateTime = (DWORD)(mtime >> 32);
		if (!SetFileTime(file, NULL, &at, &mt)) {
			error_return(L);
			CloseHandle(file);
			return 2;
		}
	}
	CloseHandle(file);
	lua_pushboolean(L, 1);
	return 1;
}

static int
lmkdir(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[V(sz+1)];
	int winsz = windows_filename(L, utf8path, (int)sz, path, (int)sz);
	path[winsz] = 0;
	if (!CreateDirectoryW(path, NULL)) {
		return error_return(L);
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
lrmdir(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[V(sz+1)];
	int winsz = windows_filename(L, utf8path, (int)sz, path, (int)sz);
	path[winsz] = 0;
	if (!RemoveDirectoryW(path)) {
		return error_return(L);
	}
	lua_pushboolean(L, 1);
	return 1;
}

static const char *
mode2string (unsigned short mode) {
	if ( S_ISREG(mode) )
		return "file";
	else if ( S_ISDIR(mode) )
		return "directory";
	else if ( S_ISLNK(mode) )
		return "link";
	else if ( S_ISSOCK(mode) )
		return "socket";
	else if ( S_ISFIFO(mode) )
		return "named pipe";
	else if ( S_ISCHR(mode) )
		return "char device";
	else if ( S_ISBLK(mode) )
		return "block device";
	else
		return "other";
}

/* inode protection mode */
static void push_st_mode (lua_State *L, STAT_STRUCT *info) {
	lua_pushstring (L, mode2string (info->st_mode));
}
/* device inode resides on */
static void push_st_dev (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_dev);
}
/* inode's number */
static void push_st_ino (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_ino);
}
/* number of hard links to the file */
static void push_st_nlink (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer)info->st_nlink);
}
/* user-id of owner */
static void push_st_uid (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer)info->st_uid);
}
/* group-id of owner */
static void push_st_gid (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer)info->st_gid);
}
/* device type, for special file inode */
static void push_st_rdev (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_rdev);
}
/* time of last access */
static void push_st_atime (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_atime);
}
/* time of last data modification */
static void push_st_mtime (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_mtime);
}
/* time of last file status change */
static void push_st_ctime (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer) info->st_ctime);
}
/* file size, in bytes */
static void push_st_size (lua_State *L, STAT_STRUCT *info) {
	lua_pushinteger (L, (lua_Integer)info->st_size);
}

static const char *perm2string (unsigned short mode) {
	static char perms[10] = "---------";
	int i;
	for (i=0;i<9;i++) perms[i]='-';
	if (mode  & _S_IREAD)
		{ perms[0] = 'r'; perms[3] = 'r'; perms[6] = 'r'; }
	if (mode  & _S_IWRITE)
		{ perms[1] = 'w'; perms[4] = 'w'; perms[7] = 'w'; }
	if (mode  & _S_IEXEC)
		{ perms[2] = 'x'; perms[5] = 'x'; perms[8] = 'x'; }
	return perms;
}

/* permssions string */
static void push_st_perm (lua_State *L, STAT_STRUCT *info) {
	lua_pushstring (L, perm2string (info->st_mode));
}

typedef void (*_push_function) (lua_State *L, STAT_STRUCT *info);

struct _stat_members {
	const char *name;
	_push_function push;
};

struct _stat_members members[] = {
	{ "mode",         push_st_mode },
	{ "dev",          push_st_dev },
	{ "ino",          push_st_ino },
	{ "nlink",        push_st_nlink },
	{ "uid",          push_st_uid },
	{ "gid",          push_st_gid },
	{ "rdev",         push_st_rdev },
	{ "access",       push_st_atime },
	{ "modification", push_st_mtime },
	{ "change",       push_st_ctime },
	{ "size",         push_st_size },
	{ "permissions",  push_st_perm },
	{ NULL, NULL }
};

/*
** Get file or symbolic link information
*/
static int
file_info (lua_State *L) {
	STAT_STRUCT info;
	size_t sz;
	int i;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t file[V(sz+1)];
	int winsz = windows_filename(L, utf8path, (int)sz, file, (int)sz);
	file[winsz] = 0;

	if (STAT_FUNC(file,	&info))	{
			lua_pushnil(L);
			lua_pushfstring(L, "cannot obtain information from file	'%s': %s", file, strerror(errno));
			lua_pushinteger(L, errno);
			return 3;
	}
	if (lua_isstring (L, 2)) {
			const char *member = lua_tostring (L, 2);
			for	(i = 0;	members[i].name; i++) {
					if (strcmp(members[i].name,	member)	== 0) {
							/* push	member value and return	*/
							members[i].push	(L,	&info);
							return 1;
					}
			}
			/* member not found	*/
			return luaL_error(L, "invalid attribute	name '%s'",	member);
	}
	/* creates a table if none is given, removes extra arguments */
	lua_settop(L, 2);
	if (!lua_istable (L, 2)) {
			lua_newtable (L);
	}
	/* stores all members in table on top of the stack */
	for	(i = 0;	members[i].name; i++) {
			lua_pushstring (L, members[i].name);
			members[i].push	(L,	&info);
			lua_rawset (L, -3);
	}
	return 1;
}

static void
get_vol_names(lua_State *L, int index) {
	lua_geti(L, -1, index);
	size_t sz;
	const char * root = lua_tolstring(L, -1, &sz);
	wchar_t tmp[V(sz+1)];
	windows_filename(L, root, (int)(sz+1), tmp, (int)(sz+1));
	wchar_t volname[MAX_PATH] = {0};
	if (!GetVolumeInformationW(tmp, volname, MAX_PATH, NULL, NULL, NULL, NULL, 0)) {
		system_error(L, GetLastError());
		lua_error(L);
	}
	size_t wlen = wcsnlen(volname, MAX_PATH);
	if (wlen) {
		char name[V(wlen*3)];
		int name_sz = utf8_filename(L, volname, (int)wlen, name, (int)(wlen*3));
		lua_pushlstring(L, name, name_sz);
		lua_settable(L, -3);
	} else {
		lua_pop(L, 1);
	}
}

static int
ldrives(lua_State *L) {
	DWORD sz = GetLogicalDriveStringsW(0,NULL);
	wchar_t wbuffer[V(sz)];
	char buffer[V(sz*3)];
	sz = GetLogicalDriveStringsW(sz, wbuffer);
	int usz = utf8_filename(L, wbuffer, sz, buffer, sz*3);
	int i;
	int from=0;
	int index = 1;
	lua_newtable(L);
	for (i=0;i<usz;i++) {
		if (buffer[i] == ' ' || buffer[i] == '\0') {
			lua_pushlstring(L, &buffer[from], i-from);
			lua_seti(L, -2, index);
			from = i+1;
			index++;
		}
	}
	for (i=1;i<index;i++) {
		get_vol_names(L, i);
	}
	return 1;
}

static int 
lexist(lua_State *L){
	const char* name = lua_tostring(L, -1);
#ifdef _MSC_VER
	#define F_OK 0
	#define R_OK 0x2
	#define W_OK 0x4	
#endif //_MSC_VER

	lua_pushboolean(L, access(name, F_OK) == 0);
	return 1;
}

#define LOCK_METATABLE "lock metatable"

typedef struct lfs_Lock {
  HANDLE fd;
} lfs_Lock;
static int lfs_lock_dir(lua_State *L) {
  size_t pathl; HANDLE fd;
  lfs_Lock *lock;
  wchar_t *ln;

  const char *lockfile = "/lockfile.lfs";
  const char *path = luaL_checklstring(L, 1, &pathl);
  ln = (wchar_t*)malloc((pathl + strlen(lockfile) + 1) * sizeof(wchar_t));
  if(!ln) {
    lua_pushnil(L); lua_pushstring(L, strerror(errno)); return 2;
  }
  int winsz = windows_filename(L, path, (int)pathl, ln, (int)pathl);
  int lsz = (int)strlen(lockfile);
  winsz += windows_filename(L, lockfile, lsz, ln+winsz, lsz);
  ln[winsz] = 0;

  if((fd = CreateFileW(ln, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_DELETE_ON_CLOSE, NULL)) == INVALID_HANDLE_VALUE) {
        int en = GetLastError();
        free(ln); lua_pushnil(L);
        if(en == ERROR_FILE_EXISTS || en == ERROR_SHARING_VIOLATION)
                lua_pushstring(L, "File exists");
        else
                lua_pushstring(L, strerror(en));
        return 2;
  }
  free(ln);
  lock = (lfs_Lock*)lua_newuserdata(L, sizeof(lfs_Lock));
  lock->fd = fd;
  luaL_getmetatable (L, LOCK_METATABLE);
  lua_setmetatable (L, -2);
  return 1;
}
static int lfs_unlock_dir(lua_State *L) {
  lfs_Lock *lock = (lfs_Lock *)luaL_checkudata(L, 1, LOCK_METATABLE);
  if(lock->fd != INVALID_HANDLE_VALUE) {    
    CloseHandle(lock->fd);
    lock->fd=INVALID_HANDLE_VALUE;
  }
  return 0;
}

/*
** Creates lock metatable.
*/
static int lock_create_meta (lua_State *L) {
        luaL_newmetatable (L, LOCK_METATABLE);

        /* Method table */
        lua_newtable(L);
        lua_pushcfunction(L, lfs_unlock_dir);
        lua_setfield(L, -2, "free");

        /* Metamethods */
        lua_setfield(L, -2, "__index");
        lua_pushcfunction(L, lfs_unlock_dir);
        lua_setfield(L, -2, "__gc");
        return 1;
}

LUAMOD_API int
luaopen_lfs(lua_State *L) {
	luaL_checkversion(L);
	lock_create_meta (L);
	luaL_Reg l[] = {
		{ "shortname", lshortname },
		{ "personaldir" , lpersonaldir },
		{ "dir", ldir },
		{ "currentdir", lcurrentdir },
		{ "chdir", lchdir },
		{ "touch", ltouch },
		{ "mkdir", lmkdir },
		{ "rmdir", lrmdir },
		{ "attributes", file_info },	// the same with lfs, but support utf-8 filename
		{ "drives", ldrives },
		{ "exist", lexist },
		{ "lock_dir", lfs_lock_dir },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
