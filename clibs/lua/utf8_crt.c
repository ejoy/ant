#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif
#include "utf8_crt.h"
#include "utf8_unicode.h"
#include <malloc.h>
#include <Windows.h>

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
	static char* ret = NULL;
	if (ret) {
		free(ret);
	}
	ret = w2u(wret);
	return ret;
}

char* __cdecl utf8_tmpnam(char* buffer)
{
	wchar_t tmp[L_tmpnam];
	static char tmpbuf[L_tmpnam];
	if (!_wtmpnam(tmp)) {
		return NULL;
	}
	if (!buffer) {
		buffer = tmpbuf;
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
