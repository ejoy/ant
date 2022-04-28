#ifndef _LUAUTF8_UTF8_CRT_H_
#define _LUAUTF8_UTF8_CRT_H_

#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

FILE* __cdecl utf8_fopen(const char * filename, const char * mode);
FILE* __cdecl utf8_freopen(char const* filename, char const* mode, FILE* stream);
FILE*  __cdecl utf8_popen(const char * command, const char* type);
int __cdecl utf8_system(const char* command);
int __cdecl utf8_remove(const char* filename);
int __cdecl utf8_rename(const char* oldfilename, const char* newfilename);
char* __cdecl utf8_getenv(const char* varname);
char* __cdecl utf8_tmpnam(char* buffer);
void* __stdcall utf8_LoadLibraryExA(const char* filename, void* file, unsigned long flags);
unsigned long __stdcall utf8_GetModuleFileNameA(void* module, char* filename, unsigned long size);
unsigned long __stdcall utf8_FormatMessageA(
  unsigned long dwFlags,
  const void*   lpSource,
  unsigned long dwMessageId,
  unsigned long dwLanguageId,
  char*         lpBuffer,
  unsigned long nSize,
  va_list*      Arguments
);
void utf8_ConsoleWrite(const char* msg, int sz);
void utf8_ConsoleNewLine();
void utf8_ConsoleError(const char* fmt, const char* param);

wchar_t* u2w(const char *str);
char* w2u(const wchar_t *str);

#endif
