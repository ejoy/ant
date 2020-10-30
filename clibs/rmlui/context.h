#pragma once

#include <bgfx/c99/bgfx.h>
#include <RmlUi/Core.h>
#include <string>

using file_dictionaries = std::unordered_map<Rml::String, Rml::String>;

struct font_namager;

struct texture_desc{
    int width, height;
    uint32_t texid;
};

struct Rect {
    int x, y, w, h;
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
    shader_info font;
    shader_info font_outline;
    shader_info font_shadow;
    shader_info font_glow;
    shader_info image;
};

struct lua_State;
struct rml_context {
    Rml::String         contextname = "main";
    Rml::Vector2i       contextdim;
    struct font_manager* font_mgr;
    shader              shader;
    file_dictionaries   file_dict;
    texture_desc        default_tex;
    texture_desc        font_tex;

    uint16_t            viewid;
    Rect                viewrect;
    bgfx_vertex_layout_t* layout;

    void unpack(lua_State *L);
};
