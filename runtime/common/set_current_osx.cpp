#include "set_current.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#define MKDIR_OPTION (S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH)

static const wchar_t hex[] = L"0123456789abcdef";

int runtime_setcurrent(lua_State* L) {
    const char* home = getenv("HOME");
    chdir(home);
    
    mkdir("./Documents/ant/", MKDIR_OPTION);
    mkdir("./Documents/ant/runtime/", MKDIR_OPTION);
    mkdir("./Documents/ant/runtime/.repo/", MKDIR_OPTION);
    char dir[] = "./Documents/ant/runtime/.repo/00/";
    size_t sz = sizeof("./Documents/ant/runtime/.repo");
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            dir[sz+0] = hex[i];
            dir[sz+1] = hex[j];
            mkdir(dir, MKDIR_OPTION);
        }
    }
    chdir("./Documents/ant/runtime/");
    return 0;
}
