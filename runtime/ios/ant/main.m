#include "ios_window.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <ant.h>

static void testLua() {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    ant_searcher_init(L, false);
    NSString* nsMainLua = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"main.lua"];
    //NSString* nsPersonPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    //NSString* nsMainLua = [nsPersonPath stringByAppendingPathComponent:@"main.lua"];
    if (luaL_dofile(L, [nsMainLua cStringUsingEncoding:NSUTF8StringEncoding]) != LUA_OK) {
        fprintf(stderr, "%s\n", lua_tostring(L, -1));
    }
}


int main(int argc, char * argv[]) {
    testLua();
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
