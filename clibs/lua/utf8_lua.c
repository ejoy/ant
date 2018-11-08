#define main(a, b) utf8_main(a, b)
#include "lua.c"
#undef main

#include "utf8_unicode.h"

int wmain(int argc, wchar_t **wargv) {
	char **argv = calloc(argc + 1, sizeof(char*));
	for (int i = 0; i < argc; ++i) {
		argv[i] = w2u(wargv[i]);
	}
	argv[argc] = 0;

	int ret = utf8_main(argc, argv);

	for (int i = 0; i < argc; ++i) {
		free(argv[i]);
	}
	free(argv);
	return ret;
}

#if defined(__MINGW32__)

#include <stdlib.h>

extern int _CRT_glob;
extern 
#ifdef __cplusplus
"C" 
#endif
void __wgetmainargs(int*,wchar_t***,wchar_t***,int,int*);

int main() {
	wchar_t **enpv, **argv;
	int argc, si = 0;
	__wgetmainargs(&argc, &argv, &enpv, _CRT_glob, &si);
	return wmain(argc, argv);
}

#endif
