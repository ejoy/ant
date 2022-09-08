#ifndef __IMAGEFONT_H__
#define __IMAGEFONT_H__

#include <stdint.h>
#include <lua.h>
#include <lauxlib.h>
#include <assert.h>

#include "font_define.h"

struct image_font {
	uint16_t handle;
	uint16_t w;
    uint16_t h;
    uint16_t itemsize;

    float scale;
    float descent;
    float linegap;
    float underline_thickness;
};

#define IMAGE_FONT              "IMAGE_FONT"
#define IMAGE_FONT_IMPORT       "IMPORT"
#define IMAGE_FONT_IMG_INFO     "IMG_INFO"
#define IMAGE_FONT_CODEPOINT    "CODEPOINT"
#define IMAGE_FONT_NAME         "NAME"



static inline float
imgfont_scale(float scale, uint16_t itemsize, int size){
    return scale * (float)size / (float)itemsize;
}

static inline void
push_func(lua_State *L, const char* filed){
    if (lua_getfield(L, LUA_REGISTRYINDEX, IMAGE_FONT) != LUA_TTABLE){
        luaL_error(L, "Invalid IMAGE_FONT in register");
    }

    if (lua_getfield(L, -1, filed) != LUA_TFUNCTION){
        luaL_error(L, "IMAGE_FONT_IMG_INFO in IMAGE_FONT regiter table is not a lua function");
    }
}

static inline struct image_font*
image_font_info(lua_State *L, struct image_font *imgfonts, int fontid){
    const int idx = font_index(fontid);
    struct image_font* imgf = imgfonts+idx;
    if (imgf->handle != UINT16_MAX){
        return imgf;
    }

    push_func(L, IMAGE_FONT_IMG_INFO);

    lua_pushinteger(L, fontid);
    if (lua_pcall(L, 2, 1, 0) != LUA_OK){
        printf("get image info failed\n");
		lua_pop(L, 1);
    }
    size_t bufsize = 0;
    const struct image_font* newimgf = (const struct image_font*)lua_tolstring(L, -1, &bufsize);

    if (bufsize != sizeof(struct image_font)){
        luaL_error(L, "Invalid image info return");
    }

    *imgf = *newimgf;

    lua_pop(L, 1);  //IMAGE_FONT
    return imgf;
}


static inline int
imgfont_codepoint_glyph(lua_State *L, int fontid, int codepoint, struct font_glyph *glyph){
    assert(is_imgfont(fontid));
    push_func(L, IMAGE_FONT_CODEPOINT);

    lua_pushinteger(L, fontid);
    lua_pushinteger(L, codepoint);

    if (lua_pcall(L, 2, 1, 0) != LUA_OK){
        printf("Get codepoint glyph failed:%d, %d", fontid, codepoint);
        return 0;
    }

    size_t sz;
    const struct font_glyph* g = (const struct font_glyph*)luaL_checklstring(L, -1, &sz);
    if (sz != sizeof(struct font_glyph)){
        return luaL_error(L, "Invalid glyph from codepoint");
    }

    *glyph = *g;
    lua_pop(L, 1);  //IMAGE_FONT
    return 1;
}

static inline void
image_font_import(lua_State *L, const char* name, const char* imgdata){
    push_func(L, IMAGE_FONT_IMPORT);

    lua_pushstring(L, name); 
    lua_pushlstring(L, imgdata, sizeof(struct image_font));   //use light userdata to void copy string??
    if (lua_pcall(L, 2, 0, 0) != LUA_OK){
        printf("Import image data failed!\n");
    }
    lua_pop(L, 1);  //IMAGE_FONT
}

static inline int
image_font_name(lua_State *L, const char* name){
    push_func(L, IMAGE_FONT_NAME);

    lua_pushstring(L, name);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK){
        printf("Fetch Image font from name:%s failed!", IMAGE_FONT_NAME);
    }

    const int fontid = (int)luaL_checkinteger(L, -1);
    lua_pop(L, 1); //IMAGE_FONT
    return fontid;
}

#endif //__IMAGEFONT_H__