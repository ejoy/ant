#include <lua.hpp>
#include <Foundation/Foundation.h>

static int ldirectory(lua_State* L) {
    auto dir = (NSSearchPathDirectory)(NSUInteger)luaL_checkinteger(L, 1);
    NSArray* array = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);
    if ([array count] <= 0) {
        return luaL_error(L, "NSSearchPathForDirectoriesInDomains failed.");
    }
    lua_pushstring(L, [[array objectAtIndex:0] fileSystemRepresentation]);
    return 1;
}

extern "C"
int luaopen_ios(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "directory", ldirectory },
        { NULL, NULL },
    };
    luaL_newlibtable(L, l);
    luaL_setfuncs(L, l, 0);

#define ENUM(name) \
    lua_pushinteger(L, name); \
    lua_setfield(L, -2, #name)

    ENUM(NSApplicationDirectory);
    ENUM(NSDemoApplicationDirectory);
    ENUM(NSDeveloperApplicationDirectory);
    ENUM(NSAdminApplicationDirectory);
    ENUM(NSLibraryDirectory);
    ENUM(NSDeveloperDirectory);
    ENUM(NSUserDirectory);
    ENUM(NSDocumentationDirectory);
    ENUM(NSDocumentDirectory);
    ENUM(NSCoreServiceDirectory);
    ENUM(NSAutosavedInformationDirectory);
    ENUM(NSDesktopDirectory);
    ENUM(NSCachesDirectory);
    ENUM(NSApplicationSupportDirectory);
    ENUM(NSDownloadsDirectory);
    ENUM(NSInputMethodsDirectory);
    ENUM(NSMoviesDirectory);
    ENUM(NSMusicDirectory);
    ENUM(NSPicturesDirectory);
    ENUM(NSPrinterDescriptionDirectory);
    ENUM(NSSharedPublicDirectory);
    ENUM(NSPreferencePanesDirectory);
    //ENUM(NSApplicationScriptsDirectory);
    ENUM(NSItemReplacementDirectory);
    ENUM(NSAllApplicationsDirectory);
    ENUM(NSAllLibrariesDirectory);
    ENUM(NSTrashDirectory);

#undef ENUM
    return 1;
}
