#ifndef _LUAUTF8_UNICODE_H_
#define _LUAUTF8_UNICODE_H_

#include <wchar.h>

wchar_t* u2w(const char *str);
char* w2u(const wchar_t *str);

#endif
