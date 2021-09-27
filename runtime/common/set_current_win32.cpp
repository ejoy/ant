#include "set_current.h"
#include <shlobj.h>
#include <shlwapi.h>

static const wchar_t hex[] = L"0123456789abcdef";

static void repo_setup(wchar_t* dir) {
    PathAppendW(dir, L".repo");
    CreateDirectoryW(dir, NULL);
    size_t sz = wcslen(dir);
    dir[sz] = L'\\';
    dir[sz+3] = L'\0';
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            dir[sz+1] = hex[i];
            dir[sz+2] = hex[j];
            CreateDirectoryW(dir, NULL);
        }
    }
    dir[sz] = L'\0';
}

wchar_t* appdata_path() {
    wchar_t* path;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path))) {
        return path;
    }
    fprintf(stderr, "::SHGetKnownFolderPath failed.");
    abort();
}

int runtime_setcurrent(lua_State* L) {
    wchar_t dir[MAX_PATH];
    wchar_t* path = appdata_path();
    wcsncpy(dir, path, MAX_PATH);
    CoTaskMemFree(path);
    PathAppendW(dir, L"ant");
    CreateDirectoryW(dir, NULL);
    PathAppendW(dir, L"runtime");
    CreateDirectoryW(dir, NULL);
    SetCurrentDirectoryW(dir);
    repo_setup(dir);
    return 0;
}

int runtime_args(lua_State* L) {
    return 0;
}
