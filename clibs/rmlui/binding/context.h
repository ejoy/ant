#pragma once

#include <map>
#include <string>
#include <stdint.h>
#include <bgfx/c99/bgfx.h>

struct font_namager;

struct texture_desc {
    int width, height;
    uint32_t texid;
};

struct shader {
    std::map<std::string, uint16_t> uniforms;

    uint16_t font;
    uint16_t font_outline;
    uint16_t font_shadow;
    uint16_t image;

    //with clip rect
    uint16_t font_cr;
    uint16_t font_outline_cr;
    uint16_t font_shadow_cr;
    uint16_t image_cr;

    #ifdef _DEBUG
    uint16_t debug_draw;
    #endif //_DEBUG

    uint16_t find_uniform(const char* name) const {
        auto iter = uniforms.find(name);
        if (iter != uniforms.end()) {
            return iter->second;
        }
        return UINT16_MAX;
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
