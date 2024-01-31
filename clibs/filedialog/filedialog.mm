#include <lua.hpp>
#include <Cocoa/Cocoa.h>

static NSString* lua_nsstring(lua_State* L, int idx) {
    return [NSString stringWithUTF8String:lua_tostring(L, idx)];
}

static void dlgSetTitle(lua_State* L, NSSavePanel* dialog, int idx) {
    if (LUA_TSTRING == lua_getfield(L, idx, "Title")) {
        [dialog setTitle:lua_nsstring(L, -1)];
    }
    lua_pop(L, 1);
}

static void dlgSetFileTypes(lua_State* L, NSSavePanel* dialog, int idx) {
    if (LUA_TTABLE != lua_getfield(L, idx, "FileTypes")) {
        return;
    }
    bool single = lua_geti(L, -1, 1) != LUA_TTABLE; lua_pop(L, 1);
    if (single) {
        lua_geti(L, -1, 2);
        NSString* type = lua_nsstring(L, -1);
        lua_pop(L, 1);
        [dialog setAllowedFileTypes:[NSArray arrayWithObject:type]];
    }
    else {
        lua_Integer n = luaL_len(L, -1);
        NSMutableArray* types = [[NSMutableArray alloc] init];
        for (lua_Integer i = 1; i <= n; ++i) {
            lua_geti(L, -1, i);
            luaL_checktype(L, -1, LUA_TTABLE);
            lua_geti(L, -1, 2);
            NSString* type = lua_nsstring(L, -1);
            [types addObject:type];
            lua_pop(L, 1);
            lua_pop(L, 1);
        }
        [dialog setAllowedFileTypes:types];
    }
    lua_pop(L, 1);
}

static int lcreate(lua_State* L, bool open_or_save) {
    luaL_checktype(L, 1, LUA_TTABLE);
    NSSavePanel* dialog;
    if (open_or_save) {
        NSOpenPanel* opendialog = [NSOpenPanel openPanel];
        [opendialog setCanChooseFiles:YES];
        [opendialog setCanChooseDirectories:YES];
        [opendialog setResolvesAliases:NO];
        [opendialog setAllowsMultipleSelection:NO];
        dialog = opendialog;
    }
    else {
        dialog = [NSSavePanel savePanel];
    }
    dlgSetTitle(L, dialog, 1);
    dlgSetFileTypes(L, dialog, 1);
    [dialog setShowsResizeIndicator:YES];
    [dialog setShowsHiddenFiles:YES];
    if ([dialog runModal] != NSModalResponseOK) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "Cancelled");
        return 2;
    }
    const char* path = [[[dialog URL] path] UTF8String];
    lua_pushboolean(L, 1);
    lua_newtable(L);
    lua_pushstring(L, path);
    lua_rawseti(L, -2, 1);
    return 2;
}

static int lopen(lua_State* L) {
    return lcreate(L, true);
}

static int lsave(lua_State* L) {
    return lcreate(L, false);
}

extern "C"
int luaopen_filedialog(lua_State* L) {
    static luaL_Reg lib[] = {
        { "open", lopen },
        { "save", lsave },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
