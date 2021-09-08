#include "set_current.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <Foundation/Foundation.h>

#define MKDIR_OPTION (S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH)

static const wchar_t hex[] = L"0123456789abcdef";

const char* appdata_path() {
    NSArray *array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([array count] > 0) {
        return [[array objectAtIndex:0] fileSystemRepresentation];
    }
    fprintf(stderr, "NSSearchPathForDirectoriesInDomains failed.");
    abort();
}

int runtime_setcurrent(lua_State* L) {
    chdir(appdata_path());
    mkdir("./ant/", MKDIR_OPTION);
    mkdir("./ant/runtime/", MKDIR_OPTION);
    mkdir("./ant/runtime/.repo/", MKDIR_OPTION);
    char dir[] = "./ant/runtime/.repo/00/";
    size_t sz = sizeof("./ant/runtime/.repo");
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            dir[sz+0] = hex[i];
            dir[sz+1] = hex[j];
            mkdir(dir, MKDIR_OPTION);
        }
    }
    chdir("./ant/runtime/");
    return 0;
}
