#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "runtime.h"

static void errfunc(const char* msg) {
    lua_writestringerror("%s\n", msg);
}

int main(int argc, char** argv) {
    runtime_main(argc, argv, errfunc);
    return 0;
}
