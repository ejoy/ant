//
//  Framework.m
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Framework.h"
#import "preload.h"

struct luavm* V;

int run_func_f;

@implementation FrameWork

-(void) InitFrameWork:(CALayer *)layer size:(CGSize)view_size {
    NSString* app_path = [[NSBundle mainBundle] resourcePath] ;
    NSString* sand_box = NSHomeDirectory();
    
    const char* app_path_char = [app_path UTF8String];
    const char* sand_box_path = [sand_box UTF8String];
    
    //only used for self updating
    struct luavm* su_v = luavm_new();
    NSString* fw_su_path = [app_path stringByAppendingString:@"/fw/fw_selfupdate.lua"];
    NSString* su_string = [NSString stringWithContentsOfFile:fw_su_path encoding:NSUTF8StringEncoding error:nil];
    const char* err_msg = luavm_init(su_v, [su_string UTF8String], "fss", get_cfuncs, app_path_char, sand_box_path);
    if(err_msg){
        printf("self update error: %s\n", err_msg);
        return;
    }
    
    luavm_close(su_v);

    V = luavm_new();
    const char* init_script =
    "local log, cfuncs, pkg_dir, sand_box_dir = ..." "\n"
    "f_table = cfuncs()""\n"
    "f_table.preloadc()""\n"
    "RUN_FUNC = nil  --the function currently running""\n"
    "RUN_FUNC_NAME = nil --the name of the running function""\n"
    "package.path = package.path .. [[;]] .. pkg_dir .. [[/?.lua;]]""\n"
    "local vfs = require [[firmware.vfs]]""\n"
    "client_repo = vfs.new(pkg_dir, sand_box_dir .. [[/Documents]])""\n"
    "local init_f, hash = client_repo:open([[/fw/fw_init.lua]])""\n"
    "if not init_f then""\n"
    "   assert(false, [[cannot find init file]]..tostring(hash))""\n"
    "end""\n"
    "local init_content = init_f:read([[a]])""\n"
    "init_f:close()""\n"
    "local init_func = load(init_content, [[=init_f]])""\n"
    "print([[init framework]], pcall(init_func, log, pkg_dir, sand_box_dir))""\n"
    ;
    
    //init stuff
    err_msg = luavm_init(V, init_script, "fss", get_cfuncs, app_path_char, sand_box_path);
    if(err_msg) {
        printf("init error: %s\n", err_msg);
        return;
    }
    
    //register function
    const char* run_script =
    "return function(...)""\n"
    "   local args = {...}""\n"
    "   local file_path = args[1]""\n"
    "   --print([[file path is: ]]..tostring(file_path))""\n"
    "   table.remove(args, 1)"
    "   if RUN_FUNC_NAME == file_path then""\n"
    "       pcall(RUN_FUNC, table.unpack(args))""\n"
    "       return""\n"
    "   end""\n"
    
    "   local f, hash = client_repo:open(file_path)""\n"
    "   if not f then""\n"
    "       assert(false, [[cannot find file: ]] .. file_path)""\n"
    "   end""\n"
    
    "   local content = f:read([[a]])""\n"
    "   f:close()""\n"
    "   local run_func = load(content, [[@file_path]])""\n"
    "   local err, result = pcall(run_func, args)""\n"
    "   if not err then" "\n"
    "       print([[run file ]]..file_path..[[ error: ]] .. tostring(result))""\n"
    "       return nil""\n"
    "   end""\n"
    
    "   RUN_FUNC_NAME = file_path""\n"
    "   RUN_FUNC = result""\n"
    "   pcall(RUN_FUNC, table.unpack(args))""\n"
    "end""\n"
    ;
    
    err_msg = luavm_register(V, run_script, "=runfile", &run_func_f);
    if(err_msg){
        printf("register run function error: %s\n", err_msg);
        return;
    }
    
    err_msg = luavm_call(V, run_func_f, "spnnss", "fw/fw_start.lua", layer, view_size.width, view_size.height, app_path_char, sand_box_path);
    if(err_msg){
        printf("call init function error: %s\n", err_msg);
        return;
    }
}

-(void) Update {
    //call registed update function
    const char* err_msg = luavm_call(V, run_func_f, "s", "fw/fw_update.lua");
    if(err_msg){
        printf("call update function error: %s\n", err_msg);
        return;
    }
    
}

-(void) Terminate {
    //call registed terminate function
    const char* err_msg = luavm_call(V, run_func_f, "s", "fw/fw_terminate.lua");
    if(err_msg){
        printf("call terminate function error: %s\n", err_msg);
        return;
    }
    
    if(V) {
        luavm_close(V);
    }
}


@end
