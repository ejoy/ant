#include <fcntl.h>
#include <io.h>
#include <Windows.h>
#include <bee/win/cwtf8.h>
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

extern "C"
int utf8_main(int argc, char** argv) {
    init_stdio();
    runtime_main(argc, argv, errfunc);
    return 0;
}

static char** utf8_create_args(int argc, wchar_t** wargv) {
    char** argv = (char**)malloc((argc + 1) * sizeof(char*));
    if (!argv) {
        return NULL;
    }
    for (int i = 0; i < argc; ++i) {
        size_t wlen = wcslen(wargv[i]);
        size_t len  = wtf8_from_utf16_length(wargv[i], wlen);
        argv[i]     = (char*)malloc((len + 1) * sizeof(char));

        if (!argv[i]) {
            for (int j = 0; j < i; ++j) {
                free(argv[j]);
            }
            free(argv);
            return NULL;
        }
        wtf8_from_utf16(wargv[i], wlen, argv[i], len);
        argv[i][len] = '\0';
    }
    argv[argc] = NULL;
    return argv;
}

static void utf8_free_args(int argc, char** argv) {
    for (int i = 0; i < argc; ++i) {
        free(argv[i]);
    }
    free(argv);
}


extern "C"
int wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR lpCmdLine, int nShowCmd) {
    int argc;
    wchar_t** wargv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
    char** argv = utf8_create_args(argc, wargv);
    if (AttachConsole(ATTACH_PARENT_PROCESS)) {
        FILE* new_file;
        freopen_s(&new_file, "CONIN$", "r", stdin);
        freopen_s(&new_file, "CONOUT$", "w", stdout);
        freopen_s(&new_file, "CONOUT$", "w", stderr);
        init_stdio();
    }
    runtime_main(argc, argv, errfunc);
    utf8_free_args(argc, argv);
    LocalFree(wargv);
    return 0;
}
