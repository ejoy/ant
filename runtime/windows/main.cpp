#include <fcntl.h>
#include <io.h>
#include <Windows.h>
#include "runtime.h"

void init_stdio() {
    int hCrt = _open_osfhandle((intptr_t)GetStdHandle(STD_OUTPUT_HANDLE), _O_TEXT);
    FILE *hf = _fdopen(hCrt, "w");
    *stdout = *hf;
    setvbuf(stdout, NULL, _IONBF, 0 );
    hCrt = _open_osfhandle((intptr_t)GetStdHandle(STD_ERROR_HANDLE), _O_TEXT);
    hf = _fdopen(hCrt, "w");
    *stderr = *hf;
    setvbuf(stderr, NULL, _IONBF, 0);
}

static void errfunc(const char* msg) {
    lua_writestringerror("%s\n", msg);
}

int wmain(int argc, wchar_t** argv) {
    init_stdio();
    runtime_main(argc, argv, errfunc);
    return 0;
}

#if defined(__MINGW32__)
#include "mingw_wmain.h"
#endif
