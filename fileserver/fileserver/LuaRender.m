//
//  LuaRender.m
//  fileserver
//
//  Created by ejoy on 2018/5/24.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LuaRender.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

LUAMOD_API int luaopen_crypt(lua_State *L);
LUAMOD_API int luaopen_lsocket(lua_State *L);
LUAMOD_API int luaopen_bgfx(lua_State *L);
LUAMOD_API int luaopen_bgfx_util(lua_State *L);
LUAMOD_API int luaopen_bgfx_baselib(lua_State *L);
LUAMOD_API int luaopen_bgfx_terrain(lua_State *L);
LUAMOD_API int luaopen_bgfx_nuklear(lua_State *L);

LUAMOD_API int luaopen_math3d(lua_State *L);
LUAMOD_API int luaopen_lfs(lua_State *L);
LUAMOD_API int luaopen_lodepnglua(lua_State *L);
LUAMOD_API int luaopen_memoryfile (lua_State *L);
LUAMOD_API int luaopen_assimplua(lua_State *L);

LUAMOD_API int luaopen_debugger_hookmgr(lua_State *L);
LUAMOD_API int luaopen_debugger_backend(lua_State *L);
LUAMOD_API int luaopen_debugger_frontend(lua_State *L);
LUAMOD_API int luaopen_clonefunc(lua_State *L);
LUAMOD_API int luaopen_cjson_safe(lua_State *L);
LUAMOD_API int luaopen_preloadc(lua_State *L);

//LUAMOD_API int luaopen_cppfs(lua_State *L);

void luaopen_lanes_embedded( lua_State* L, lua_CFunction _luaopen_lanes);

static int default_luaopen_lanes( lua_State* L) {
    NSString *lanes_lua = [[NSBundle mainBundle] resourcePath];
    lanes_lua = [lanes_lua stringByAppendingString:@"/Common/lanes.lua"];
    int rc = luaL_loadfile( L, [lanes_lua UTF8String]) || lua_pcall( L, 0, 1, 0);
    if( rc != LUA_OK) {
        return luaL_error( L, "failed to initialize embedded Lanes");
    }
    return 1;
}

static int custom_on_state_create(lua_State *L) {
    lua_getglobal(L, "package");
    int top = lua_gettop(L);
    if(lua_istable(L, -1)) {
        lua_getfield(L, -1, "preload");
        
        top = lua_gettop(L);
        if(lua_istable(L, -1)) {
            lua_pushcfunction(L, luaopen_lsocket);
            lua_setfield(L, -2, "lsocket");
            //lua_pop(L, 1);
            
            lua_pushcfunction(L, luaopen_crypt);
            lua_setfield(L, -2, "crypt");
            
            lua_pushcfunction(L, luaopen_lfs);
            lua_setfield(L, -2, "winfile");
            lua_pop(L, 1);
        }
        
        top = lua_gettop(L);
        lua_getfield(L, -1, "path");
        if(lua_isstring(L, -1)) {
            const char* pkg_path = lua_tostring(L, -1);
            lua_pop(L, 1);
            
            NSString* path_string = [NSString stringWithUTF8String:pkg_path];
            path_string = [path_string stringByAppendingString:@";"];
            NSString *app_path = [[NSBundle mainBundle] resourcePath];
            path_string = [app_path stringByAppendingString:@"/Common/?.lua;"];
            path_string = [path_string stringByAppendingString:app_path];
            path_string = [path_string stringByAppendingString:@"/Client/?.lua"];
            lua_pushstring(L, [path_string UTF8String]);
            lua_setfield(L, -2, "path");
        }
    }
    top = lua_gettop(L);
    lua_pop(L, -1);
    
    return 0;
}

lua_State *L = nil;
static int error_handle(lua_State* L) {
    const char *msg = lua_tostring(L, -1);
    
    if(msg) {
        printf("------- error!!! -------- \n %s\n", msg);
        
        //send a log
        lua_getglobal(L, "sendlog");
        if(lua_isfunction(L, -1)) {
            lua_pushstring(L, "Device");
            lua_pushstring(L, msg);
            lua_pcall(L, 2, 0, 0);
        }
        
        luaL_traceback(L, L, msg, 1);
    }
    
    return 0;
}

NSMutableDictionary* local_file_path;

@implementation LuaRender
- (void) SelfUpdate{
    L = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_requiref(L, "preloadc", luaopen_preloadc, 0);
    luaopen_lanes_embedded(L, default_luaopen_lanes);
    
    custom_on_state_create(L);
    lua_pushcfunction(L, custom_on_state_create);
    lua_setglobal(L, "custom_on_state_create");
    
    NSString* app_dir = [[NSBundle mainBundle]resourcePath];
    NSString* sandbox_dir = NSHomeDirectory();
    
    NSString* script_dir = [app_dir stringByAppendingString:@"/Common/selfupdate.lua"];
    
    NSString* script_string = [NSString stringWithContentsOfFile:script_dir encoding:NSUTF8StringEncoding error:nil];
    
    luaL_dostring(L, [script_string UTF8String]);
    
#ifdef DEBUG
    lua_pushcfunction(L, error_handle);
#endif
    
    lua_getglobal(L, "SelfUpdate");
    if(lua_isfunction(L, -1)) {
        lua_pushstring(L, [sandbox_dir UTF8String]);
        
#ifdef DEBUG
        lua_pcall(L, 1, 1, -3);
#else
        lua_pcall(L, 1, 1, 0);
#endif
    }
    
    local_file_path = [[NSMutableDictionary alloc] initWithCapacity:6];
    
    //handle return value
    if(lua_istable(L, -1)){
        //get
        lua_getfield(L, -1, "appmain");
        NSString* appmain_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "pack");
        NSString* pack_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "filemanager");
        NSString* filemanager_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "lanes");
        NSString* lanes_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "fileprocess");
        NSString* fileprocess_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "client");
        NSString* client_path = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);
        
        [local_file_path setObject:appmain_path forKey:@"appmain"];
        [local_file_path setObject:pack_path forKey:@"path"];
        [local_file_path setObject:filemanager_path forKey:@"filemanager"];
        [local_file_path setObject:lanes_path forKey:@"lanes"];
        [local_file_path setObject:fileprocess_path forKey:@"fileprocess"];
        [local_file_path setObject:client_path forKey:@"client"];
        lua_pop(L, 1);
    }
    else {
        assert(false);
    }
    
    lua_close(L);
}


- (void) InitScript:(CALayer*)layer size:(CGSize)view_size {
    L = luaL_newstate();
    luaL_openlibs(L);
    
    //put file into package.preload()
    if (lua_getglobal(L, "package") != LUA_TTABLE) {
        luaL_error(L, "No package");
    }
    
    if(lua_getfield(L, -1, "preload") != LUA_TTABLE){
        luaL_error(L, "can't find package loaded");
    }
   // size_t loaded_length = lua_rawlen(L, -1);
    
    NSString* doc_path = [NSHomeDirectory() stringByAppendingString:@"/Documents/"];
    for(NSString* key in local_file_path) {
        if(![key isEqualToString:@"appmain"]) {
            NSString* real_path = [doc_path stringByAppendingString:local_file_path[key]];
            
            luaL_loadfile(L, [real_path UTF8String]);
            lua_setfield(L, -2, [key UTF8String]);
        }
    }
    
  
    lua_pop(L, 2);
//    int top = lua_gettop(L);
    luaL_requiref(L, "preloadc", luaopen_preloadc, 0);
//    luaL_requiref(L, "cppfs", luaopen_cppfs, 0);
    
    luaopen_lanes_embedded(L, default_luaopen_lanes);
    
    custom_on_state_create(L);
    lua_pushcfunction(L, custom_on_state_create);
    lua_setglobal(L, "custom_on_state_create");
    
    float width = view_size.width;
    float height = view_size.height;

    NSString *app_dir = [[NSBundle mainBundle] resourcePath];
    NSString *sandbox_dir = NSHomeDirectory();
    NSLog(app_dir, sandbox_dir);
    
    //NSString* appmain_local = [app_dir stringByAppendingString:@"/Client/appmain.lua"];
   
    //NSString* app_main_string = [NSString stringWithContentsOfFile:app_file_dir encoding:NSUTF8StringEncoding error:nil];

    NSString* appmain_local = [doc_path stringByAppendingString:local_file_path[@"appmain"]];
    
    //luaL_dostring(L, [app_main_string UTF8String]);
    luaL_dofile(L, [appmain_local UTF8String]);
    
#ifdef DEBUG
    lua_pushcfunction(L, error_handle);
#endif
    
    lua_getglobal(L, "init");
    if(lua_isfunction(L, -1)) {
        lua_pushlightuserdata(L, (__bridge void *)(layer));
        lua_pushnumber(L, width);
        lua_pushnumber(L, height);
        lua_pushstring(L, [app_dir UTF8String]);
        lua_pushstring(L, [sandbox_dir UTF8String]);
        
#ifdef DEBUG
        lua_pcall(L, 5, 0, -7);
#else
        lua_pcall(L, 5, 0, 0);
#endif
     
    }
    else {
        assert(false);
    }
    
    //init msg array
    self->MsgArray = [[NSMutableArray alloc] initWithCapacity:10];
}

- (void) Update {
    [self HandleInput];
    
#ifdef DEBUG
    lua_pushcfunction(L, error_handle);
#endif
    
    lua_getglobal(L, "mainloop");
    if(lua_isfunction(L, -1)) {
#ifdef DEBUG
        lua_pcall(L, 0, 0, -2);
#else
        lua_pcall(L, 0, 0, 0);
#endif
    }
}

- (void) Terminate {
#ifdef DEBUG
    lua_pushcfunction(L, error_handle);
#endif
    
    lua_getglobal(L, "terminate");
    if(lua_isfunction(L, -1)) {
#ifdef DEBUG
        lua_pcall(L, 0, 0, -2);
#else
        lua_pcall(L, 0, 0, 0);
#endif
    }
    
    lua_close(L);
}

- (void) HandleInput {
#ifdef DEBUG
    lua_pushcfunction(L, error_handle);
#endif
    if([self->MsgArray count] > 0) {
        lua_getglobal(L, "handle_input");
        if(lua_isfunction(L, -1)) {
            lua_newtable(L);
            for(NSInteger i = 0; i < [self->MsgArray count]; ++i) {
                lua_newtable(L);
                InputMsg* msg = self->MsgArray[i];
                lua_pushstring(L, [msg->msg UTF8String]);
                lua_setfield(L, -2, "msg");
                
                lua_pushnumber(L, msg->x_pos);
                lua_setfield(L, -2, "x");
                
                lua_pushnumber(L, msg->y_pos);
                lua_setfield(L, -2, "y");
                
                lua_seti(L, -2, i+1);
            }
#ifdef DEBUG
            lua_pcall(L, 1, 0, -3);
#else
            lua_pcall(L, 1, 0, 0);
#endif
        }
        
        [self->MsgArray removeAllObjects];
    }
}

- (void) AddInputMessage:(NSString *)msg x_pos:(CGFloat)x y_pos:(CGFloat)y {
    InputMsg* new_msg = [[InputMsg alloc] initWithArgs:msg x_pos:x y_pos:y];
    [MsgArray addObject:new_msg];
}
@end

@implementation InputMsg

-(id) initWithArgs:(NSString*)in_msg x_pos:(CGFloat)in_x y_pos:(CGFloat)in_y {
    if(self=[super init])
    {
        msg = in_msg;
        x_pos = in_x;
        y_pos = in_y;
    }
    return  self;
}

@end
