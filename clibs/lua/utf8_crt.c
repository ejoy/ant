#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif
#include "utf8_crt.h"
#include <malloc.h>
#include <assert.h>
#include <Windows.h>
#include <io.h>

#if defined(__GNUC__)
#   define thread_local __thread
#elif defined(_MSC_VER)
#   define thread_local __declspec(thread)
#else
#   error Cannot define thread_local
#endif

wchar_t* u2w(const char *str) {
    int len = 0;
    int out_len = 0;
    wchar_t *buf = NULL;
    if (!str) {
        return NULL;
    }
    len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (!len) {
        return NULL;
    }
    buf = (wchar_t*)calloc(len, sizeof(wchar_t));
    if (!buf) {
        return NULL;
    }
    out_len = MultiByteToWideChar(CP_UTF8, 0, str, -1, buf, len);
    if (out_len < 0) {
        free(buf);
        return NULL;
    }
    return buf;
}

char* w2u(const wchar_t *str)
{
    int len = 0;
    int out_len = 0;
    char *buf = NULL;
    if (!str) {
        return NULL;
    }
    len = WideCharToMultiByte(CP_UTF8, 0, str, -1, NULL, 0, NULL, NULL);
    if (!len) {
            return NULL;
    }
    buf = (char*)calloc(len, sizeof(char));
    if (!buf) {
        return NULL;
    }
    out_len = WideCharToMultiByte(CP_UTF8, 0, str, -1, buf, len, NULL, NULL);
    if (out_len < 0) {
        free(buf);
        return NULL;
    }
    return buf;
}

FILE* __cdecl utf8_fopen(const char * filename, const char * mode)
{
	wchar_t* wfilename = u2w(filename);
	wchar_t* wmode = u2w(mode);
	FILE* ret = _wfopen(wfilename, wmode);
	free(wfilename);
	free(wmode);
	return ret;
}

FILE* __cdecl utf8_freopen(char const* filename, char const* mode, FILE* stream)
{
	wchar_t* wfilename = u2w(filename);
	wchar_t* wmode = u2w(mode);
	FILE* ret = _wfreopen(wfilename, wmode, stream);
	free(wfilename);
	free(wmode);
	return ret;
}

FILE*  __cdecl utf8_popen(const char * command, const char* type)
{
	wchar_t* wcommand = u2w(command);
	wchar_t* wtype = u2w(type);
	FILE* ret = _wpopen(wcommand, wtype);
	free(wcommand);
	free(wtype);
	return ret;
}

int __cdecl utf8_system(const char* command)
{
	wchar_t* wcommand = u2w(command);
	int ret = _wsystem(wcommand);
	free(wcommand);
	return ret;
}

int __cdecl utf8_remove(const char* filename)
{
	wchar_t* wfilename = u2w(filename);
	int ret = _wremove(wfilename);
	free(wfilename);
	return ret;
}

int __cdecl utf8_rename(const char* oldfilename, const char* newfilename)
{
	wchar_t* woldfilename = u2w(oldfilename);
	wchar_t* wnewfilename = u2w(newfilename);
	int ret = _wrename(woldfilename, wnewfilename);
	free(woldfilename);
	free(wnewfilename);
	return ret;
}

char* __cdecl utf8_getenv(const char* varname)
{
	wchar_t* wvarname = u2w(varname);
	wchar_t* wret = _wgetenv(wvarname);
	free(wvarname);
	if (!wret) {
		return NULL;
	}
	static thread_local char* ret = NULL;
	if (ret) {
		free(ret);
	}
	ret = w2u(wret);
	return ret;
}

char* __cdecl utf8_tmpnam(char* buffer)
{
    assert(buffer);
	wchar_t tmp[L_tmpnam];
	if (!_wtmpnam(tmp)) {
		return NULL;
	}
    unsigned long ret = WideCharToMultiByte(CP_UTF8, 0, tmp, -1, buffer, L_tmpnam, NULL, NULL);
	if (ret == 0) {
		return NULL;
	}
	return buffer;
}

void* __stdcall utf8_LoadLibraryExA(const char* filename, void* file, unsigned long flags)
{
	wchar_t* wfilename = u2w(filename);
	void* ret = LoadLibraryExW(wfilename, file, flags);
	free(wfilename);
	return ret;
}


unsigned long __stdcall utf8_GetModuleFileNameA(void* module, char* filename, unsigned long size)
{
	wchar_t* tmp = calloc(size, sizeof(wchar_t));
	if (!tmp) {
		SetLastError(ERROR_NOT_ENOUGH_MEMORY);
		return 0;
	}
	unsigned long tmplen = GetModuleFileNameW(module, tmp, size);
	unsigned long ret = WideCharToMultiByte(CP_UTF8, 0, tmp, tmplen + 1, filename, size, NULL, NULL);
	free(tmp);
	return ret - 1;
}

unsigned long __stdcall utf8_FormatMessageA(
	unsigned long dwFlags,
	const void*   lpSource,
	unsigned long dwMessageId,
	unsigned long dwLanguageId,
	char*         lpBuffer,
	unsigned long nSize,
	va_list*      Arguments
)
{
	wchar_t* tmp = calloc(nSize, sizeof(wchar_t));
	if (!tmp) {
		SetLastError(ERROR_NOT_ENOUGH_MEMORY);
		return 0;
	}
	int res = FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId, tmp, nSize, Arguments);
	if (!res) {
		free(tmp);
		return res;
	}
	int ret = WideCharToMultiByte(CP_UTF8, 0, tmp, -1, lpBuffer, nSize, NULL, NULL);
	free(tmp);
	return ret;
}

static UINT GetOutputCP(FILE* stream) {
	HANDLE handle = (HANDLE)_get_osfhandle(_fileno(stream));
	switch (GetFileType(handle)) {
	case FILE_TYPE_DISK:
		return CP_UTF8;
	case FILE_TYPE_CHAR: {
		DWORD mode;
		if (GetConsoleMode(handle, &mode)) {
			return GetConsoleOutputCP();
		}
		return CP_UTF8;
	}
	case FILE_TYPE_PIPE:
	default:
		return CP_UTF8;
	}
}

static void ConsoleWrite(FILE* stream, const char* s, int l) {
	UINT cp = GetOutputCP(stream);
	if (cp == CP_UTF8) {
		fwrite(s, sizeof(char), l, stream);
		return;
	}
	wchar_t* wmsg = NULL;
	int wsz = MultiByteToWideChar(CP_UTF8, 0, s, l, NULL, 0);
	if (wsz) {
		wmsg = (wchar_t*)calloc(wsz, sizeof(wchar_t));
		if (!wmsg) {
			return;
		}
		wsz = MultiByteToWideChar(CP_UTF8, 0, s, l, wmsg, wsz);
		if (wsz < 0) {
			free(wmsg);
			return;
		}
	}
	char* msg = NULL;
	int sz = WideCharToMultiByte(cp, 0, wmsg, wsz, NULL, 0, NULL, NULL);
	if (sz) {
		msg = (char*)calloc(sz, sizeof(char));
		if (!msg) {
			free(wmsg);
			return;
		}
		sz = WideCharToMultiByte(cp, 0, wmsg, wsz, msg, sz, NULL, NULL);
	}
	fwrite(msg, sizeof(char), sz, stream);
	free(msg);
	free(wmsg);
}

void utf8_ConsoleWrite(const char* s, int l) {
	ConsoleWrite(stdout, s, l);
}
void utf8_ConsoleNewLine() {
	fwrite("\n", sizeof(char), 1, stdout);
	fflush(stdout);
}
void utf8_ConsoleError(const char* fmt, const char* param) {
	int l = snprintf(NULL, 0, fmt, param);
	char* s = (char*)calloc(l, sizeof(char));
	if (!s) {
		return;
	}
	snprintf(s, l, fmt, param);
	ConsoleWrite(stderr, s, l);
	fflush(stderr);
	free(s);
}
