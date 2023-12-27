#pragma once

#include <map>
#include <string>
#include <stdint.h>

struct shader {
    std::map<std::string, uint16_t> uniforms;

    int font;
    int font_outline;
    int font_shadow;
    int image;

    //with clip rect
    int font_cr;
    int font_outline_cr;
    int font_shadow_cr;
    int image_cr;
    int image_gray;
    int image_cr_gray;

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
    struct shader         shader;
    uint16_t              viewid;
    RmlContext(lua_State *L, int idx);
};
