#include <lua.hpp>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

static int get(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSObject* value = [defaults objectForKey:[NSString stringWithUTF8String:key]];
    if (!value) {
        return 0;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString* v = (NSString*)value;
        lua_pushstring(L, [v UTF8String]);
        return 1;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber* v = (NSNumber*)value;
        if ([v isEqual:@(YES)]) {
            lua_pushboolean(L, 1);
            return 1;
        }
        if ([v isEqual:@(NO)]) {
            lua_pushboolean(L, 0);
            return 1;
        }
        //TODO integer
        lua_pushnumber(L, [v doubleValue]);
        return 1;
    }
    return luaL_error(L, "invalid setting type");
}

static int set(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    NSObject* value;
    switch (lua_type(L, 2)) {
    case LUA_TSTRING:
        value = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
        break;
    case LUA_TBOOLEAN:
        if (lua_toboolean(L, 2)) {
            value = @(YES);
        }
        else {
            value = @(NO);
        }
        break;
    default:
        return luaL_error(L, "invalid setting type");
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:[NSString stringWithUTF8String:key]];
    [defaults synchronize];
    return 0;
}

int lsetting(lua_State* L) {
    if (lua_gettop(L) == 1) {
        return get(L);
    }
    return set(L);
}

static int lbundle(lua_State* L) {
    lua_pushstring(L, [[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
    return 1;
}

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
        { "bundle", lbundle },
        { "directory", ldirectory },
        { "setting", lsetting },
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
