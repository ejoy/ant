#define LUA_LIB

#include "lua.h"
#include "lauxlib.h"
#include "zlib-ng.h"
#include "mz_compat.h"
#include "luazip.h"
#include "memfile.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <bee/win/cwtf8.h>

#define ZLIB_UTF8_FLAG (1<<11)
#define FILECHUNK (4096 * 4)

static int
lcompress(lua_State *L) {
	size_t sz;
	const char * src = luaL_checklstring(L, 1, &sz);
	size_t len = zng_compressBound(sz);
	char * buf = (char *) malloc(len + 1);
	if (buf == NULL) {
		return luaL_error(L, "Compress OOM");
	}
	if (zng_compress((void *)(buf + 1), &len, (void *)src, sz) != Z_OK) {
		free(buf);
		return luaL_error(L, "Compress error");
	}
	int idx = 0;
	size_t tmp = len;
	while (sz > tmp) {
		++idx;
		tmp *= 2;
	}
	// 0 : the same size
	// 1 : 2x size
	// 2...n : (1<<n)x size
	buf[0] = idx;
	lua_pushlstring(L, buf, len + 1);
	free(buf);
	return 1;
}

static int
luncompress(lua_State *L) {
	size_t sz;
	const char *src = luaL_checklstring(L, 1, &sz);
	int idx = src[0];
	size_t dsz = (1ull << idx) * (sz - 1);
	void *buf = malloc(dsz);
	if (buf == NULL)
		return luaL_error(L, "Uncompress OOM");
	int r = zng_uncompress(buf, &dsz, (void *)(src + 1), sz - 1);
	if (r == Z_OK) {
		lua_pushlstring(L, buf, dsz);
		free(buf);
		return 1;
	}
	free(buf);
	switch (r) {
	case Z_DATA_ERROR:
		return luaL_error(L, "Uncompress data corrupted");
	case Z_BUF_ERROR:
		return luaL_error(L, "Uncompress not enough buffer");
	default:
		return luaL_error(L, "Uncompress error");
	}
	return 0;
}

static zipFile
zip_open(lua_State *L, const char *filename, int append) {
	return zipOpen(filename, append ? APPEND_STATUS_ADDINZIP : 0);
}

static unzFile
unzip_open(lua_State *L, const char *filename) {
	return unzOpen2(filename, 0);
}

#ifdef _WIN32

#include <windows.h>

static const wchar_t* u2w(const char* str) {
	if (!str) {
		return NULL;
	}
	size_t len  = strlen(str);
	size_t wlen = wtf8_to_utf16_length(str, len);
	if (wlen == (size_t)-1) {
		return NULL;
	}
	wchar_t* wresult = (wchar_t*)calloc(wlen + 1, sizeof(wchar_t));
	if (!wresult) {
		return NULL;
	}
	wtf8_to_utf16(str, len, wresult, wlen);
	return wresult;
}

static FILE *
file_open(lua_State *L, const char *filename, const char *mode) {
	const wchar_t* wfilename = u2w(filename);
	WCHAR m[32];
	int i;
	for (i=0; mode[i]; i++) {
		if (i == 31) {
			if (L == NULL)
				return NULL;
			luaL_error(L, "Invalid mode %s", mode);
		}
		m[i] = mode[i];
	}
	m[i] = 0;
	FILE* f = _wfopen(wfilename, m);
	free((void*)wfilename);
	return f;
}

#else

struct filename_convert {};

static FILE *
file_open(lua_State *L, const char *filename, const char *mode) {
	return fopen(filename, mode);
}

#endif

struct ziphandle {
	zipFile h;
};

struct zipraw {
	int method;
	int level;
};

static zipFile
open_new(lua_State *L, int index, const struct zipraw *raw, int level) {
	const char *filename = luaL_checkstring(L, index);
	struct ziphandle *z = (struct ziphandle *)luaL_checkudata(L, 1, "ZIP_WRITE");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE)
		luaL_error(L, "Invalid zip userdata");
	int cache = lua_gettop(L);
	lua_pushvalue(L, index);
	if (lua_rawget(L, cache) != LUA_TNIL) {
		luaL_error(L, "Error: %s exist", filename);
	}
	int err = zipOpenNewFileInZip4(z->h, filename, NULL, NULL, 0, NULL, 0, NULL,
		raw ? raw->method : Z_DEFLATED,
		raw ? raw->level : level,
		raw != NULL,
		-MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
		NULL, 0, 0,
		ZLIB_UTF8_FLAG
	);
	if (err != ZIP_OK) {
		luaL_error(L, "Error: open in file");
	}
	lua_pushvalue(L, 2);
	lua_pushboolean(L, 1);
	lua_rawset(L, cache);
	lua_settop(L, cache - 1);
	return z->h;
}

static inline void
close_inzip(lua_State *L, zipFile zf) {
	if (zipCloseFileInZip(zf) != ZIP_OK) {
		luaL_error(L, "Error: close in file");
	}
}

static int
zipwrite_add(lua_State *L) {
	int level = luaL_optinteger(L, 4, Z_DEFAULT_COMPRESSION);
	zipFile zf = open_new(L, 2, NULL, level);
	size_t sz;
	const char * content = luaL_checklstring(L, 3, &sz);
	int err = zipWriteInFileInZip(zf, content, sz);
	if (err != ZIP_OK) {
		return luaL_error(L, "Error: write in file");
	}
	close_inzip(L, zf);
	return 0;
}

static int
zipwrite_addfile(lua_State *L) {
	int level = luaL_optinteger(L, 4, Z_DEFAULT_COMPRESSION);
	zipFile zf = open_new(L, 2, NULL, level);
	const char * addfile = luaL_checkstring(L, 3);
	FILE *f = file_open(L, addfile, "rb");
	if (f == NULL)
		return luaL_error(L, "Can't open %s", addfile);
	char buf[FILECHUNK];
	for (;;) {
		int bytes = fread(buf, 1, FILECHUNK, f);
		if (bytes <= 0) {
			if (bytes == 0)
				break;
			return luaL_error(L, "Error: read file %s", addfile);
		}
		int err = zipWriteInFileInZip(zf, buf, bytes);
		if (err != ZIP_OK) {
			fclose(f);
			return luaL_error(L, "Error: write in file");
		}
		if (bytes < FILECHUNK)
			break;
	}
	fclose(f);
	close_inzip(L, zf);
	return 0;
}

static int
zipwrite_open(lua_State *L) {
	int level = luaL_optinteger(L, 3, Z_DEFAULT_COMPRESSION);
	open_new(L, 2, NULL, level);
	return 0;
}

static int
zipwrite_close(lua_State *L) {
	struct ziphandle *z = (struct ziphandle *)luaL_checkudata(L, 1, "ZIP_WRITE");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	close_inzip(L, z->h);
	return 0;
}

static int
zipwrite_closezip(lua_State *L) {
	struct ziphandle *z = (struct ziphandle *)luaL_checkudata(L, 1, "ZIP_WRITE");
	if (z->h == NULL)
		return 0;
	int err = zipClose(z->h, NULL);
	z->h = NULL;
	if (err != Z_OK)
		return luaL_error(L, "Error: close");
	return 0;
}

static int
zipwrite_write(lua_State *L) {
	struct ziphandle *z = (struct ziphandle *)luaL_checkudata(L, 1, "ZIP_WRITE");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	size_t sz;
	const char *content = luaL_checklstring(L, 2, &sz);
	int err = zipWriteInFileInZip(z->h, content, sz);
	if (err != ZIP_OK) {
		return luaL_error(L, "Error: write in file");
	}
	return 0;
}

struct unzhandle {
	unzFile h;
};

static int
zipread_closezip(lua_State *L) {
	struct unzhandle *z = (struct unzhandle *)luaL_checkudata(L, 1, "ZIP_READ");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	int err = unzClose(z->h);
	z->h = NULL;
	if (err != UNZ_OK)
		return luaL_error(L, "Error: close");
	return 0;
}

static inline lua_Integer
file_pos_to_luaint(const unz_file_pos *pos) {
	uint64_t p = pos->pos_in_zip_directory;
	uint64_t n = pos->num_of_file;
	return (lua_Integer)(p << 32 | n);
}

static inline unz_file_pos *
luaint_to_file_pos(lua_Integer v, unz_file_pos *pos) {
	pos->pos_in_zip_directory = (uint64_t)v >> 32;
	pos->num_of_file = v & 0xffffffff;
	return pos;
}

static void
get_filelist(lua_State *L, unzFile zf) {
	lua_newtable(L);
	int err = unzGoToFirstFile(zf);
	if (err != UNZ_OK)
		luaL_error(L, "Error: goto first file");
	char filename[4096];
	for (;;) {
		unz_file_pos pos;
		unzGetFilePos(zf, &pos);
		int err = unzGetCurrentFileInfo(zf, NULL, filename, sizeof(filename), NULL, 0, NULL, 0);
		if (err != UNZ_OK)
			luaL_error(L, "Error: get file info %d", pos.num_of_file);
		lua_pushinteger(L, file_pos_to_luaint(&pos));
		lua_setfield(L, -2, filename);
		err = unzGoToNextFile(zf);
		if (err != UNZ_OK) {
			if (err == UNZ_END_OF_LIST_OF_FILE)
				break;
			luaL_error(L, "Error: goto next file %d", pos.num_of_file);
		}
	}
}

static int
zipread_list(lua_State *L) {
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE)
		return luaL_error(L, "Invalid zip userdata");
	int t = lua_gettop(L);
	lua_newtable(L);
	int r = t+1;
	lua_pushnil(L);
	while (lua_next(L, t) != 0) {
		if (lua_type(L, -1) == LUA_TNUMBER) {
			int n = luaL_checkinteger(L, -1);
			lua_pop(L, 1);
			lua_pushvalue(L, -1);
			lua_rawseti(L, r, n+1);
		} else {
			// filename
			lua_pop(L, 1);
		}
	}
	return 1;
}

static void
locate_file(lua_State *L, unzFile zf, lua_Integer pos) {
	unz_file_pos tmp;
	int err = unzGoToFilePos(zf, luaint_to_file_pos(pos, &tmp));
	if (err != UNZ_OK)
		luaL_error(L, "Error: unzGoToFilePos");
}

static int
zipread_exist(lua_State *L) {
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
		luaL_error(L, "Invalid zip userdata");
	}
	lua_pushvalue(L, 2);	// filename
	int exist = (lua_rawget(L, -2) == LUA_TNUMBER);
	lua_pushboolean(L, exist);
	return 1;
}

static unzFile
open_file(lua_State *L, int rzip, int filename, struct zipraw *raw) {
	if (lua_getiuservalue(L, rzip, 1) != LUA_TTABLE) {
		luaL_error(L, "Invalid zip userdata");
	}
	lua_pushvalue(L, filename);	// filename
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		lua_pop(L, 1);
		return NULL;
	}
	lua_Integer pos = luaL_checkinteger(L, -1);
	lua_pop(L, 2);

	struct unzhandle *z = (struct unzhandle *)luaL_checkudata(L, rzip, "ZIP_READ");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");

	locate_file(L, z->h, pos);
	int err;
	if (raw) {
		err = unzOpenCurrentFile2(z->h, &raw->method, &raw->level, 1);
	} else {
		err = unzOpenCurrentFile(z->h);
	}
	if (err != UNZ_OK)
		luaL_error(L, "Error: open file %s (%d)", lua_tostring(L, filename), err);
	return z->h;
}

static void
close_file(lua_State *L, unzFile zf) {
	int err = unzCloseCurrentFile(zf);
	if (err != UNZ_OK) {
		if (err == UNZ_CRCERROR)
			luaL_error(L, "Error: CRC");
		else
			luaL_error(L, "Error: close file");
	}
}

static int
zipread_readfile(lua_State *L) {
	unzFile zf = open_file(L, 1, 2, NULL);
	if (zf == NULL)
		return 0;
	unz_file_info info;
	int err = unzGetCurrentFileInfo(zf, &info, NULL, 0, NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		close_file(L, zf);
		luaL_error(L, "Error: get file info %s", lua_tostring(L, 2));
	}
	void *buf = malloc(info.uncompressed_size);
	if (buf == NULL) {
		close_file(L, zf);
		luaL_error(L, "Error: out of memory");
	}
	if (info.uncompressed_size != 0) {
		int bytes = unzReadCurrentFile(zf, buf, info.uncompressed_size);
		if (bytes != info.uncompressed_size) {
			free(buf);
			close_file(L, zf);
			luaL_error(L, "Error: read file %s (%d != %d)", lua_tostring(L, 2), bytes, (int)info.uncompressed_size);
		}
	}
	lua_pushlstring(L, buf, info.uncompressed_size);
	free(buf);
	close_file(L, zf);
	return 1;
}

static int
zipread_size(lua_State *L) {
	unzFile zf = open_file(L, 1, 2, NULL);
	if (zf == NULL)
		return 0;
	unz_file_info info;
	int err = unzGetCurrentFileInfo(zf, &info, NULL, 0, NULL, 0, NULL, 0);
	if (err != UNZ_OK)
		luaL_error(L, "Error: get file info %s", lua_tostring(L, 2));
	lua_pushinteger(L, info.uncompressed_size);
	return 1;
}

static int
zipread_extract(lua_State *L) {
	unzFile zf = open_file(L, 1, 2, NULL);
	if (zf == NULL)
		return luaL_error(L, "Error: no file %s", lua_tostring(L, 2));
	const char * filename = luaL_checkstring(L, 3);
	FILE *f = file_open(L, filename, "wb");
	if (f == NULL) {
		close_file(L, zf);
		return luaL_error(L, "Error: open %s", filename);
	}
	char buf[FILECHUNK];
	int bytes = 0;
	do {
		bytes = unzReadCurrentFile(zf, buf, sizeof(buf));
		if (bytes < 0) {
			close_file(L, zf);
			return luaL_error(L, "Error: read %s", lua_tostring(L, 2));
		}
		if (bytes > 0 && fwrite(buf, 1, bytes, f) != bytes) {
			close_file(L, zf);
			return luaL_error(L, "Error: write %s", filename);
		}
	} while (bytes == sizeof(buf));
	fclose(f);
	close_file(L, zf);
	return 0;
}

static int
zipread_openfile(lua_State *L) {
	open_file(L, 1, 2, NULL);
	return 0;
}

static int
zipread_closefile(lua_State *L) {
	struct unzhandle *z = (struct unzhandle *)luaL_checkudata(L, 1, "ZIP_READ");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	close_file(L, z->h);
	return 0;	
}

static int
zipread_read(lua_State *L) {
	struct unzhandle *z = (struct unzhandle *)luaL_checkudata(L, 1, "ZIP_READ");
	if (z->h == NULL)
		luaL_error(L, "Error: closed");
	int n = luaL_checkinteger(L, 2);
	if (n <= 0)
		return luaL_error(L, "Error: read size = %d", n);
	void *buf = malloc(n);
	if (buf == NULL)
		return luaL_error(L, "Error: out of memory");
	int bytes = unzReadCurrentFile(z->h, buf, n);
	if (bytes <= 0) {
		free(buf);
		if (bytes == 0)
			return 0;
		luaL_error(L, "Error: read file");
	}
	lua_pushlstring(L, (const char *)buf, bytes);
	free(buf);
	return 1;
}

// 2: filename
// 3: readzip (userdata)
// 4: opt: altername
static int
zipwrite_copyfrom(lua_State *L) {
	int filename = lua_isnoneornil(L, 4) ? 2 : 4;
	struct zipraw raw;
	unzFile rd = open_file(L, 3, filename, &raw);
	if (rd == NULL)
		return luaL_error(L, "Error: open %s", lua_tostring(L, filename));
	zipFile zf = open_new(L, 2, &raw, raw.level);
	if (zf == NULL) {
		close_file(L, rd);
		return luaL_error(L, "Error: open %s", lua_tostring(L, 2));
	}

	// copy file from rd to zf
	// todo : zipCloseFileInZipRaw on error

	unz_file_info info;
	int err = unzGetCurrentFileInfo(rd, &info, NULL, 0, NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		close_file(L, rd);
		luaL_error(L, "Error: get file info %s", lua_tostring(L, filename));
	}

	char buf[FILECHUNK];
	int bytes;
	do {
		bytes = unzReadCurrentFile(rd, buf, sizeof(buf));
		if (bytes < 0) {
			close_file(L, rd);
			return luaL_error(L, "Error: read %s", lua_tostring(L, filename));
		}
		if (bytes > 0 && zipWriteInFileInZip(zf, buf, bytes) != ZIP_OK) {
			close_file(L, rd);
			return luaL_error(L, "Error: write %s", lua_tostring(L, 2));
		}
	} while (bytes == sizeof(buf));
	close_file(L, rd);

	if (zipCloseFileInZipRaw(zf, info.uncompressed_size, info.crc) != ZIP_OK)
		return luaL_error(L, "Error: close %s", 2);

	return 0;
}

static int
zipread_filename(lua_State *L) {
	const int rzip = 1;
	const int filename = 2;
	if (lua_getiuservalue(L, rzip, 1) != LUA_TTABLE) {
		luaL_error(L, "Invalid zip userdata");
	}
	lua_pushvalue(L, filename);	// filename
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		return 0;
	}
	lua_Integer v = luaL_checkinteger(L, -1);
	lua_pop(L, 1);
	unz_file_pos pos;
	luaint_to_file_pos(v, &pos);
	if (lua_rawgeti(L, -1, 0) != LUA_TSTRING) {
		return luaL_error(L, "No zip filename");
	}
	lua_pushfstring(L, "%s|%d", lua_tostring(L, -1), pos.num_of_file);
	return 1;
}

static int
unzip(lua_State *L, const char *filename) {
	unzFile zf = unzip_open(L, filename);
	if (zf == NULL)
		return 0;
	struct unzhandle *z = (struct unzhandle *)lua_newuserdatauv(L, sizeof(*z), 1);
	get_filelist(L, zf);
	lua_pushstring(L, filename);
	lua_rawseti(L, -2, 0);
	lua_setiuservalue(L, -2, 1);
	z->h = zf;
	if (luaL_newmetatable(L, "ZIP_READ")) {
		luaL_Reg l[] = {
			{ "__index", NULL },
			{ "__gc", zipread_closezip },
			{ "close", zipread_closezip },
			{ "list", zipread_list },
			{ "extract", zipread_extract },
			{ "readfile", zipread_readfile },
			{ "exist", zipread_exist },
			{ "openfile", zipread_openfile },
			{ "closefile", zipread_closefile },
			{ "read", zipread_read },
			{ "size", zipread_size },
			{ "filename", zipread_filename },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
zip(lua_State *L, const char *filename, int append) {
	if (append) {
		unzFile uzf = unzip_open(L, filename);
		if (uzf == NULL)
			return 0;
		get_filelist(L, uzf);
		unzClose(uzf);
	} else {
		lua_newtable(L);	// cache filenames
	}
	zipFile zf = zip_open(L, filename, append);
	if (zf == NULL)
		return 0;
	struct ziphandle *z = (struct ziphandle *)lua_newuserdatauv(L, sizeof(*z), 1);
	lua_insert(L, -2);
	lua_setiuservalue(L, -2, 1);
	z->h = zf;
	if (luaL_newmetatable(L, "ZIP_WRITE")) {
		luaL_Reg l[] = {
			{ "__index", NULL },
			{ "__gc", zipwrite_closezip },
			{ "copyfrom", zipwrite_copyfrom },
			{ "addfile", zipwrite_addfile },
			{ "add", zipwrite_add },
			{ "openfile", zipwrite_open },
			{ "closefile", zipwrite_close },
			{ "write", zipwrite_write },
			{ "close", zipwrite_closezip },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lzip(lua_State *L) {
	const char * filename = luaL_checkstring(L, 1);
	const char * mode = luaL_checkstring(L, 2);
	switch (mode[0]) {
	case 'w':
		return zip(L, filename, 0);
	case 'r':
		return unzip(L, filename);
	case 'a':
		return zip(L, filename, 1);
	default:
		return luaL_error(L, "Invalid Mode %s", mode);
	}
}

// 4M
#define READER_DEFAULT_CACHESIZE (1024 * 1024 * 4)
#define READER_MIN_CACHESIZE 4096

struct zip_reader_cache {
	size_t size;
	uint8_t active;
	char buffer[7];
};

static inline struct zip_reader_cache *
advance_ptr(struct zip_reader_cache *C, size_t sz) {
	return (struct zip_reader_cache*)((char *)C + sz);
}

static void
split_cache(lua_State *L, struct zip_reader_cache *C, size_t sz) {
	struct zip_reader_cache *next = advance_ptr(C, sz);
	size_t next_sz = C->size - sz;
	if (next_sz >= sizeof(*C)) {
		next->size = C->size - sz;
		next->active = 0;
		C->size = sz;
	} else {
		next = advance_ptr(C, C->size);
		size_t len = lua_rawlen(L, 1);
		struct zip_reader_cache * beginptr = (struct zip_reader_cache *)lua_touserdata(L, 1);
		struct zip_reader_cache * endptr = advance_ptr(beginptr, len);
		if (next >= endptr)
			next = beginptr; // rewind ring buffer
	}
	lua_pushlightuserdata(L, next);
	lua_setiuservalue(L, 1, 2);
}

static void
merge_cache(lua_State *L, struct zip_reader_cache *C, struct zip_reader_cache *endptr) {
	struct zip_reader_cache *next = advance_ptr(C, C->size);
	while (next < endptr) {
		if (next->active)
			break;
		next = advance_ptr(next, next->size);
	}
	C->size = (size_t)((char *)next - (char *)C);
}

static struct zip_reader_cache *
find_cache(lua_State *L, struct zip_reader_cache *C, struct zip_reader_cache *endptr, size_t sz) {
	while (C < endptr) {
		if (!C->active)
			break;
		C = advance_ptr(C, C->size);
	}
	if (advance_ptr(C, sz) > endptr)
		return NULL;
	if (sz <= C->size) {
		split_cache(L, C, sz);
	} else {
		merge_cache(L, C, endptr);
		if (sz <= C->size) {
			split_cache(L, C, sz);
		} else {
			return find_cache(L, advance_ptr(C, C->size), endptr, sz);
		}
	}
	return C;
}

static size_t
need_size(size_t sz) {
	sz += offsetof(struct zip_reader_cache, buffer);
	sz = (sz + 7) & ~7;	// align to size_t
	return sz;
}

static struct zip_reader_cache *
alloc_cache(lua_State *L, size_t sz) {
	lua_getiuservalue(L, 1, 2);	// cache ptr
	struct zip_reader_cache *C = (struct zip_reader_cache *)lua_touserdata(L, -1);
	sz = need_size(sz);
	if (!C->active && C->size >= sz) {
		split_cache(L, C, sz);
	} else {
		size_t len = lua_rawlen(L, 1);
		struct zip_reader_cache * beginptr = (struct zip_reader_cache *)lua_touserdata(L, 1);
		struct zip_reader_cache * endptr = advance_ptr(beginptr, len);
		C = find_cache(L, C, endptr, sz);
		if (C == NULL) {
			C = find_cache(L, beginptr, endptr, sz);
			if (C == NULL) {
				return NULL;
			}
		}
		split_cache(L, C, sz);
	}
	return C;
}

static void
close_cache(void *ud) {
	struct zip_reader_cache * C = (struct zip_reader_cache *)ud;
	C->active = 0;
}

static struct memory_file *
new_from_cache(lua_State *L, size_t sz) {
	size_t fullsz = sz + sizeof(struct memory_file);
	struct zip_reader_cache * C = alloc_cache(L, fullsz);
	if (C == NULL) {
		// not enough space
		return memory_file_alloc(sz);
	} else {
		C->active = 1;
		struct memory_file *mf = (struct memory_file *)(C->buffer);
		mf->ud = (void *)C;
		mf->data = (const char *)(mf + 1);
		mf->sz = sz;
		mf->close = close_cache;
		return mf;
	}
}

static int
zipreader_handle(lua_State *L) {
	lua_settop(L, 3);
	lua_getiuservalue(L, 1, 1);	// zip read
	unzFile zf = open_file(L, 4, 2, NULL);
	if (zf == NULL) {
		return 0;
	}
	unz_file_info info;
	int err = unzGetCurrentFileInfo(zf, &info, NULL, 0, NULL, 0, NULL, 0);
	if (err != UNZ_OK)
		luaL_error(L, "Error: get file info %s", lua_tostring(L, 2));
	size_t sz = info.uncompressed_size;
	struct memory_file *mf = new_from_cache(L, sz);
	if (mf == NULL) {
		close_file(L, zf);
		return luaL_error(L, "Out of memory for file %s", lua_tostring(L, 2));
	}
	if (sz != 0) {
		int bytes = unzReadCurrentFile(zf, (char *)mf->data, sz);
		if (bytes != sz) {
			close_file(L, zf);
			luaL_error(L, "Error: read file %s (%d != %d)", lua_tostring(L, 2), bytes, (int)sz);
		}
	}
	close_file(L, zf);
	lua_pushlightuserdata(L, mf);
	return 1;
}

static int
lreader(lua_State *L) {
	luaL_checkudata(L, 1, "ZIP_READ");
	lua_Integer sz = luaL_optinteger(L, 2, READER_DEFAULT_CACHESIZE);
	if (sz < READER_MIN_CACHESIZE)
		sz = READER_MIN_CACHESIZE;
	struct zip_reader_cache *C = (struct zip_reader_cache *)lua_newuserdatauv(L, sz, 2);
	C->size = sz;
	C->active = 0;
	lua_pushvalue(L, 1);
	lua_setiuservalue(L, -2, 1);
	lua_pushlightuserdata(L, C);
	lua_setiuservalue(L, -2, 2);
	if (luaL_newmetatable(L, "ZIP_READER")) {
		luaL_Reg l[] = {
			{ "__call", zipreader_handle },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lreader_consume(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	struct memory_file *mf = (struct memory_file *)lua_touserdata(L, 1);
	lua_pushlstring(L, mf->data, mf->sz);
	memory_file_close(mf);
	return 1;
}

static int
lreader_dump(lua_State *L) {
	luaL_Buffer b;
	luaL_buffinit(L, &b);
	struct zip_reader_cache *C = (struct zip_reader_cache *)luaL_checkudata(L, 1, "ZIP_READER");
	lua_getiuservalue(L, 1, 2);
	struct zip_reader_cache *head = (struct zip_reader_cache *)lua_touserdata(L, -1);
	size_t len = lua_rawlen(L, 1);
	struct zip_reader_cache * endptr = advance_ptr(C, len);
	while (C < endptr) {
		lua_pushfstring(L, "%p (size = %I%s) %s\n", C, C->size, C->active ? " *" : "", (C == head) ? "<=" : "");
		luaL_addvalue(&b);
		C = advance_ptr(C, C->size);
	}
	luaL_pushresult(&b);
	return 1;
}

LUAMOD_API int
luaopen_zip(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "compress", lcompress },
		{ "uncompress", luncompress },
		{ "open", lzip },
		{ "reader", lreader },
		{ "reader_consume", lreader_consume },
		{ "reader_dump", lreader_dump },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

