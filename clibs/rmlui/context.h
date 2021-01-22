#pragma once

#include <bgfx/c99/bgfx.h>
#include <RmlUi/Element.h>
#include <RmlUi/Plugin.h>
#include <RmlUi/Context.h>
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
        Rml::String name;
    };
    uint32_t prog;
    Rml::Vector<uniforms> uniforms;

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

        ST_font_cp,
        ST_font_outline_cp,
        ST_font_shadow_cp,
        ST_image_cp,
        ST_count,
    };
    shader_info font;
    shader_info font_outline;
    shader_info font_shadow;
    shader_info image;

    //with distance planes
    shader_info font_cp;
    shader_info font_outline_cp;
    shader_info font_shadow_cp;
    shader_info image_cp;

    const shader_info& get_shader(ShaderType type) const {
        switch (type){
        case ST_font: return font;
        case ST_font_outline: return font_outline;
        case ST_font_shadow: return font_shadow;
        case ST_image: return image;
        case ST_font_cp: return font_cp;
        case ST_font_outline_cp: return font_outline_cp;
        case ST_font_shadow_cp: return font_shadow_cp;
        case ST_image_cp: return image_cp;
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
    Rect                  viewrect;
    bgfx_vertex_layout_t* layout;
    std::string           bootstrap;

    lua_plugin*           plugin = nullptr;

    RmlContext(lua_State *L, int idx);
};
