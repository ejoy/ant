#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>

#include <windows.h>
#include <Shlobj.h>
#include <sys/stat.h>
#include <wchar.h>

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
		char tmp[n * 3];
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
	wchar_t winname[sz + 1];
	int wsz = windows_filename(L, filename, sz, winname, sz);
	winname[wsz] = 0;
	wchar_t shortname[sz + 1];
	DWORD ssz = GetShortPathNameW(winname, shortname, sz);
	if (ssz == 0) {
		return error_return(L);
	}
	char tmp[ssz * 3];
	int s = utf8_filename(L, shortname, ssz, tmp, ssz*3);
	lua_pushlstring(L, tmp, s);
	return 1;
}

static void
push_filename(lua_State *L, WIN32_FIND_DATAW *data) {
	size_t wlen = wcsnlen(data->cFileName, MAX_PATH);
	char firstname[wlen*3];
	int ulen = utf8_filename(L, data->cFileName, wlen, firstname, wlen*3);

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
	wchar_t winname[sz+3];
	int winsz = windows_filename(L, pathname, sz, winname, sz);
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
		int sz = utf8_filename(L, document, wsz, utf8path, MAX_PATH*3);
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
	int usz = utf8_filename(L, path, wsz, utf8path, MAX_PATH*3);
	lua_pushlstring(L, utf8path, usz);
	return 1;
}

static int
lchdir(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path, sz);
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
	wchar_t path[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path, sz);
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
	wchar_t path[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path, sz);
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
	wchar_t path[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path, sz);
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
	wchar_t file[sz+1];
	int winsz = windows_filename(L, utf8path, sz, file, sz);
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

static int
lremove(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path, sz);
	path[winsz] = 0;
	if (!DeleteFileW(path)) {
		return error_return(L);
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
lrename(lua_State *L) {
	size_t sz;
	const char * utf8path = luaL_checklstring(L, 1, &sz);
	wchar_t path1[sz+1];
	int winsz = windows_filename(L, utf8path, sz, path1, sz);
	path1[winsz] = 0;

	utf8path = luaL_checklstring(L, 2, &sz);
	wchar_t path2[sz+1];
	winsz = windows_filename(L, utf8path, sz, path2, sz);
	path2[winsz] = 0;

	if (!MoveFileW(path1, path2)) {
		return error_return(L);
	}
	lua_pushboolean(L, 1);
	return 1;
}

typedef struct LoadF {
	int n;  /* number of pre-read characters */
	FILE *f;  /* file being read */
	char buff[BUFSIZ];  /* area for reading file */
} LoadF;

static const char *
getF (lua_State *L, void *ud, size_t *size) {
	LoadF *lf = (LoadF *)ud;
	(void)L;  /* not used */
	if (lf->n > 0) {  /* are there pre-read characters to be read? */
		*size = lf->n;  /* return them (chars already in buffer) */
		lf->n = 0;  /* no more pre-read characters */
	}
	else {  /* read a block from file */
		/* 'fread' can return > 0 *and* set the EOF flag. If next call to
		   'getF' called 'fread', it might still wait for user input.
		   The next check avoids this problem. */
	if (feof(lf->f)) return NULL;
		*size = fread(lf->buff, 1, sizeof(lf->buff), lf->f);  /* read block */
	}
	return lf->buff;
}

static int errfile (lua_State *L, const char *what, int fnameindex) {
	const char *serr = strerror(errno);
	const char *filename = lua_tostring(L, fnameindex) + 1;
	lua_pushfstring(L, "cannot %s %s: %s", what, filename, serr);
	lua_remove(L, fnameindex);
	return LUA_ERRFILE;
}

static int skipBOM (LoadF *lf) {
	const char *p = "\xEF\xBB\xBF";  /* UTF-8 BOM mark */
	int c;
	lf->n = 0;
	do {
		c = getc(lf->f);
		if (c == EOF || c != *(const unsigned char *)p++) return c;
		lf->buff[lf->n++] = c;  /* to be read by the parser */
	} while (*p != '\0');
	lf->n = 0;  /* prefix matched; discard it */
	return getc(lf->f);  /* return next character */
}

/*
** reads the first character of file 'f' and skips an optional BOM mark
** in its beginning plus its first line if it starts with '#'. Returns
** true if it skipped the first line.  In any case, '*cp' has the
** first "valid" character of the file (after the optional BOM and
** a first-line comment).
*/
static int skipcomment (LoadF *lf, int *cp) {
	int c = *cp = skipBOM(lf);
	if (c == '#') {  /* first line is a comment (Unix exec. file)? */
		do {  /* skip first line */
			c = getc(lf->f);
		} while (c != EOF && c != '\n');
		*cp = getc(lf->f);  /* skip end-of-line, if present */
		return 1;  /* there was a comment */
	}
	else return 0;  /* no comment */
}

static int
wloadfilex (lua_State *L, const wchar_t *filename, const char *mode) {
	LoadF lf;
	int status, readstatus;
	int c;
	int fnameindex = lua_gettop(L) + 1;  /* index of filename on the stack */
	if (filename == NULL) {
		lua_pushliteral(L, "=stdin");
		lf.f = stdin;
	}
	else {
		lua_pushfstring(L, "@%s", filename);
		lf.f = _wfopen(filename, (const wchar_t *)"r\0\0");
		if (lf.f ==	NULL) return errfile(L,	"open",	fnameindex);
	}
	if (skipcomment(&lf, &c))	 /*	read initial portion */
		lf.buff[lf.n++]	= '\n';	 /*	add	line to	correct	line numbers */
	if (c	== LUA_SIGNATURE[0]	&& filename) {	/* binary file?	*/
		lf.f = _wfreopen(filename, (const wchar_t *)"r\0b\0\0", lf.f);  /* reopen in	binary mode	*/
	if (lf.f ==	NULL) return errfile(L,	"reopen", fnameindex);
		skipcomment(&lf, &c);  /* re-read initial portion */
	}
	if (c	!= EOF)
		lf.buff[lf.n++]	= c;  /* 'c' is	the	first character	of the stream */
	status = lua_load(L, getF, &lf, lua_tostring(L, -1), mode);
	readstatus = ferror(lf.f);
	if (filename)	fclose(lf.f);  /* close	file (even in case of errors) */
	if (readstatus) {
		lua_settop(L, fnameindex);	/* ignore results from 'lua_load' */
		return errfile(L, "read", fnameindex);
	}
	lua_remove(L,	fnameindex);
	return status;
}

static int load_aux (lua_State *L, int status, int envidx) {
	if (status == LUA_OK) {
		if (envidx != 0) {  /* 'env' parameter? */
			lua_pushvalue(L, envidx);  /* environment for loaded function */
			if (!lua_setupvalue(L, -2, 1))  /* set it as 1st upvalue */
				lua_pop(L, 1);  /* remove 'env' if not used by previous call */
		}
		return 1;
	}
	else {  /* error (message is on top of the stack) */
		lua_pushnil(L);
		lua_insert(L, -2);  /* put before error message */
		return 2;  /* return nil plus error message */
	}
}

static int
lloadfile(lua_State *L) {
	size_t sz;
	const char *fname = luaL_optlstring(L, 1, NULL, &sz);
	const char *mode = luaL_optstring(L, 2, NULL);
	int env = (!lua_isnone(L, 3) ? 3 : 0);  /* 'env' index or 0 if no 'env' */
	int status;

	if (fname) {
		wchar_t path[sz+1];
		int winsz = windows_filename(L, fname, sz, path, sz);
		path[winsz] = 0;
		status = wloadfilex(L, path, mode);
	} else {
		status = wloadfilex(L, NULL, mode);
	}
	return load_aux(L, status, env);
}

static int dofilecont (lua_State *L, int d1, lua_KContext d2) {
	(void)d1;  (void)d2;  /* only to match 'lua_Kfunction' prototype */
	return lua_gettop(L) - 1;
}

static int ldofile (lua_State *L) {
	size_t sz;
	const char *fname = luaL_optlstring(L, 1, NULL, &sz);
	wchar_t path[sz+1];
	lua_settop(L, 1);

	if (fname) {
		int winsz = windows_filename(L, fname, sz, path, sz);
		path[winsz] = 0;
		if (wloadfilex(L, path, NULL) != LUA_OK)
			return lua_error(L);
	} else {
		if (wloadfilex(L, NULL, NULL) != LUA_OK)
			return lua_error(L);
	}

	lua_callk(L, 0, LUA_MULTRET, 0, dofilecont);
	return dofilecont(L, 0, 0);
}

#define tolstream(L)	((LStream *)luaL_checkudata(L, 1, LUA_FILEHANDLE))

typedef luaL_Stream LStream;

/*
** function to close regular files
*/
static int io_fclose (lua_State *L) {
	LStream *p = tolstream(L);
	int res = fclose(p->f);
	return luaL_fileresult(L, (res == 0), NULL);
}

/*
** When creating file handles, always creates a 'closed' file handle
** before opening the actual file; so, if there is a memory error, the
** handle is in a consistent state.
*/
static LStream *newprefile (lua_State *L) {
	LStream *p = (LStream *)lua_newuserdata(L, sizeof(LStream));
	p->closef = NULL;  /* mark file handle as 'closed' */
	luaL_setmetatable(L, LUA_FILEHANDLE);
	return p;
}

static LStream *newfile (lua_State *L) {
	LStream *p = newprefile(L);
	p->f = NULL;
	p->closef = &io_fclose;
	return p;
}

static int
lopen(lua_State *L) {
	size_t sz;
	const char *filename = luaL_checklstring(L, 1, &sz);
	wchar_t path[sz+1];
	int winsz = windows_filename(L, filename, sz, path, sz);
	path[winsz] = 0;

	const char *mode = luaL_optstring(L, 2, "r");
	LStream *p = newfile(L);

	const char *md = mode;  /* to traverse/check mode */
	int n = strlen(md);
	wchar_t wmode[n+1];
	n = windows_filename(L, md, n, wmode, n);
	wmode[n] = 0;
	p->f = _wfopen(path, wmode);
	return (p->f == NULL) ? luaL_fileresult(L, 0, filename) : 1;
}

static int io_pclose (lua_State *L) {
	LStream *p = tolstream(L);
	return luaL_execresult(L, _pclose(p->f));
}

static int
lpopen(lua_State *L) {
	size_t sz;
	const char *filename = luaL_checklstring(L, 1, &sz);
	wchar_t path[sz+1];
	int winsz = windows_filename(L, filename, sz, path, sz);
	path[winsz] = 0;

	const char *mode = luaL_optstring(L, 2, "r");
	LStream *p = newprefile(L);

	const char *md = mode;
	int n = strlen(md);
	wchar_t wmode[n+1];
	n = windows_filename(L, md, n, wmode, n);
	wmode[n] = 0;

	p->f = _wpopen(path, wmode);
	p->closef = &io_pclose;
	return (p->f == NULL) ? luaL_fileresult(L, 0, filename) : 1;
}

static int
lexecute(lua_State *L) {
	size_t sz;
	const char *cmd = luaL_optlstring(L, 1, NULL, &sz);
	int stat;
	if (cmd) {
		wchar_t wcmd[sz+1];
		sz = windows_filename(L, cmd, sz, wcmd, sz);
		wcmd[sz] = 0;
		stat = _wsystem(wcmd);
	} else {
		stat = _wsystem(NULL);
	}
	if (cmd != NULL)
		return luaL_execresult(L, stat);
	else {
		lua_pushboolean(L, stat);  /* true if there is a shell */
		return 1;
	}
}

static int
lgetenv(lua_State *L) {
	size_t sz;
	const char * name = luaL_checklstring(L, 1, &sz);
	wchar_t wname[sz+1];
	sz = windows_filename(L, name, sz, wname, sz);
	wname[sz] = 0;
	const wchar_t * result = _wgetenv(wname);
	if (result == NULL)
		lua_pushnil(L);
	else {
		sz = wcslen(result);
		char tmp[sz * 3 + 1];
		sz = utf8_filename(L, result, sz, tmp, sz * 3);
		tmp[sz] = 0;
		lua_pushlstring(L, tmp, sz);
	}
	return 1;
}

LUAMOD_API int
luaopen_winfile(lua_State *L) {
	luaL_checkversion(L);
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
		{ "remove", lremove },
		{ "rename", lrename },
		{ "loadfile", lloadfile },
		{ "dofile", ldofile },
		{ "open", lopen },
		{ "execute", lexecute },
		{ "getenv", lgetenv },
		{ "popen", lpopen },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
