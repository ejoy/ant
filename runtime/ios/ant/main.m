#include "ios_window.h"
#include "ios_error.h"
#include <lua.hpp>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "runtime.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        ios_error_handler();
        runtime_main(argc, argv, ios_error_display);
        return 0;
    }
}
