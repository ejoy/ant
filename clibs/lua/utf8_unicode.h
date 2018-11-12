#ifndef _LUAUTF8_UNICODE_H_
#define _LUAUTF8_UNICODE_H_

#include <wchar.h>

char* w2u(const wchar_t *str);
wchar_t* u2w(const char *str);

#endif
