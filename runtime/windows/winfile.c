#include "winfile.h"

#include <windows.h>
#include <Shlobj.h>
#include <sys/stat.h>

#include <stdio.h>
#include <string.h>

static int
utf8_filename(const wchar_t * winfilename, int wsz, char *utf8buffer, int sz) {
	sz = WideCharToMultiByte(CP_UTF8, 0, winfilename, wsz, utf8buffer, sz, NULL, NULL);
	return sz;
}

static int
windows_filename(const char * utf8filename, int usz, wchar_t * winbuffer, int wsz) {
	wsz = MultiByteToWideChar(CP_UTF8, 0, utf8filename, usz, winbuffer, wsz);
	return wsz;
}

int
wfile_personaldir(char *utf8path, int sz) {
	wchar_t document[MAX_PATH] = {0};
	LPITEMIDLIST pidl = NULL;
	SHGetSpecialFolderLocation(NULL, CSIDL_PERSONAL, &pidl);
	if (pidl && SHGetPathFromIDListW(pidl, document)) {
		size_t wsz = wcsnlen(document, MAX_PATH);
		sz = utf8_filename(document, wsz, utf8path, sz);
		if (sz > 0) {
			utf8path[sz] = '\0';
		}
		return sz;
	}
	return 0;
}

static int
strip_slash(const char * path) {
	int sz = strlen(path);
	if (path[sz-1] == '/' || path[sz-1] == '\\') {
		--sz;
	}
	return sz;
}

int
wfile_concat(char *utf8path, int sz, const char *path) {
	int s1 = strip_slash(utf8path);
	int s2 = strip_slash(path);
	if (s1 == 0) {
		if (s2 >= sz)
			return 0;
		memcpy(utf8path, path, s2);
		utf8path[s2] = '\0';
		return s2;
	}

	int new_sz = s1 + s2 + 1;
	if (new_sz >= sz) {
		return 0;
	}
	utf8path[s1] = '\\';
	memcpy(utf8path + s1 + 1, path, s2);
	utf8path[new_sz] = '\0';
	return new_sz;
}

#define STAT_STRUCT struct _stati64
#define STAT_FUNC _wstati64
#ifndef S_ISDIR
#define S_ISDIR(mode)  (mode&_S_IFDIR)
#endif
#ifndef S_ISREG
#define S_ISREG(mode)  (mode&_S_IFREG)
#endif

int
wfile_type(const char *utf8path) {
	int sz = strlen(utf8path);
	if (sz >= MAX_PATH)
		return WFILE_UNKNOWN;
	wchar_t path[MAX_PATH];

	int winsz = windows_filename(utf8path, sz, path, sz);
	if (winsz == 0)
		return WFILE_UNKNOWN;
	path[winsz] = 0;
	STAT_STRUCT info;

	if (STAT_FUNC(path,	&info))	{
		return WFILE_NONE;
	}
	if (S_ISDIR(info.st_mode)) {
		return WFILE_DIR;
	}
	if (S_ISREG(info.st_mode)) {
		return WFILE_FILE;
	}
	return WFILE_UNKNOWN;
}

int
wfile_mkdir(const char *utf8path) {
	int sz = strlen(utf8path);
	if (sz >= MAX_PATH)
		return 0;
	wchar_t path[MAX_PATH];
	int winsz = windows_filename(utf8path, sz, path, sz);
	path[winsz] = 0;
	if (!CreateDirectoryW(path, NULL)) {
		return 0;
	}
	return 1;
}

FILE *
wfile_open(const char *filename, const char *mode) {
	int sz = strlen(filename);
	if (sz >= MAX_PATH)
		return NULL;
	wchar_t path[MAX_PATH];
	int winsz = windows_filename(filename, sz, path, sz);
	path[winsz] = 0;

	int n = strlen(mode);
	if (n >= MAX_PATH)
		return NULL;
	wchar_t wmode[MAX_PATH];
	n = windows_filename(mode, n, wmode, n);
	wmode[n] = 0;
	FILE *f = _wfopen(path, wmode);
	return f;
}
