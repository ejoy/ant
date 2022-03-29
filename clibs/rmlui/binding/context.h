#pragma once

#include <bgfx/c99/bgfx.h>
#include <core/Element.h>
#include <core/Plugin.h>
#include <string>
#include "luaplugin.h"

struct font_namager;

struct texture_desc{
    int width, height;
    uint32_t texid;
};

struct Rect {
    int x, y, w, h;
    bool isVaild() const {
        return !(x == 0 && y == 0 && w == 0 && h == 0);
    }
};

class FileInterface2;
class FontInterface;
class Renderer;
class System;

struct shader_info {
    struct uniforms {
        uint32_t    handle;
        std::string name;
    };
    uint32_t prog;
    std::vector<uniforms> uniforms;

    uint16_t find_uniform(const char*name) const {
        for(auto it:uniforms){
            if (it.name == name)
                return (uint16_t)it.handle;
        }

        return UINT16_MAX;
    }
};

struct shader {
    float font_mask;
    float font_range;
    
    enum ShaderType{
        ST_font = 0,
        ST_font_outline,
        ST_font_shadow,
        ST_image,

        ST_font_cr,
        ST_font_outline_cr,
        ST_font_shadow_cr,
        ST_image_cr,
        ST_count,
    };
    shader_info font;
    shader_info font_outline;
    shader_info font_shadow;
    shader_info image;

    //with clip rect
    shader_info font_cr;
    shader_info font_outline_cr;
    shader_info font_shadow_cr;
    shader_info image_cr;

    #ifdef _DEBUG
    shader_info debug_draw;
    #endif //_DEBUG

    const shader_info& get_shader(ShaderType type) const {
        switch (type){
        case ST_font: return font;
        case ST_font_outline: return font_outline;
        case ST_font_shadow: return font_shadow;
        case ST_image: return image;
        case ST_font_cr: return font_cr;
        case ST_font_outline_cr: return font_outline_cr;
        case ST_font_shadow_cr: return font_shadow_cr;
        case ST_image_cr: return image_cr;
        default: assert(false && "invalid type"); return font;
        }
    }
};

struct lua_State;
struct RmlContext {
    struct font_manager*  font_mgr;
    shader                shader;
    texture_desc          default_tex;
    texture_desc          font_tex;
    uint16_t              viewid;
    bgfx_vertex_layout_t* layout;
    RmlContext(lua_State *L, int idx);
};
