//
//  lodepnglua.c
//  lodepng
//
//  Created by ejoy on 2018/5/30.
//  Copyright © 2018年 ejoy. All rights reserved.
//
extern "C"
{
    #include <lua.h>
    #include <lualib.h>
    #include <lauxlib.h>
}

#include <stdio.h>
#include <string.h>
#include "lodepng.h"

static int EncodePng(lua_State *L)
{
    const char* data = nullptr;
    size_t data_length = 0;
    unsigned int width = 0;
    unsigned int height = 0;
    //inputs are image raw data, width, height
    if(lua_isnumber(L, -1))
    {
        height = lua_tonumber(L, -1);
        //printf("height %d\n", height);
        lua_pop(L, 1);
    }
    
    if(lua_isnumber(L, -1))
    {
        width = lua_tonumber(L, -1);
        lua_pop(L, 1);
        //printf("width %d\n",width);
    }
    
    if(lua_isstring(L, -1))
    {
        //data = lua_tostring(L, -1);
        data = lua_tolstring(L, -1, &data_length);
        
        lua_pop(L, 1);
    }

    const std::vector<unsigned char> png_in(data, data + data_length);
    std::vector<unsigned char> png_out;
    
    unsigned error = lodepng::encode(png_out, png_in, width, height);
  
    if(error)
    {
        printf("png encode error: %d\n", error);
        lua_pushnumber(L, 0);
    }
    else
    {
        std::string out_data(png_out.begin(), png_out.end());
        lua_pushlstring(L, out_data.data(), out_data.size());
    }
    
    return 1;
}

static int DecodePng(lua_State *L)
{
    const char* png_data;
    size_t data_length;
    if(lua_isstring(L, -1))
    {
        png_data = lua_tolstring(L, -1, &data_length);
        lua_pop(L, 1);
    }
    
    std::vector<unsigned char> png_vec(png_data, png_data+data_length);
    std::vector<unsigned char> raw_pixels;
    
    unsigned width, height;
    unsigned error = lodepng::decode(raw_pixels, width, height, png_vec);
    
	printf("decode error code : %d %d\n", error, raw_pixels.size());

	//bgfx screenshot format is bgra, we need rgba to display
	//for now, just put it here
	for (int i = 0; i < raw_pixels.size(); i += 4)
	{
		char b = raw_pixels[i];
		raw_pixels[i] = raw_pixels[i + 2];
		raw_pixels[i + 2] = b;
	}

    std::string pixel_string(raw_pixels.begin(), raw_pixels.end());
    
    lua_pushlstring(L, pixel_string.data(), pixel_string.size());
    lua_pushnumber(L, width);
    lua_pushnumber(L, height);
    
    return 3;
}

static const struct luaL_Reg lib[] = {
    {"encode_png", EncodePng},
    {"decode_png", DecodePng},
    {NULL, NULL},
};

extern "C"
{
    LUAMOD_API int luaopen_lodepnglua(lua_State *L)
    {
        luaL_newlib(L, lib);
        return 1;
    }
}
