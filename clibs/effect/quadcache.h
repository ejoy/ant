#pragma once
#include "singleton.h"

#include <bgfx/c99/bgfx.h>

struct quad_vertex{
    glm::vec3   p;
    glm::vec2   uv;
    glm::vec2   subuv;
    uint32_t    color;
};

inline uint8_t to_color_channel(float c){
    return uint8_t(std::min(255.f, c * 255.f));
}

inline float to_color_channel(uint8_t c){
    return float(std::min(1.f, c / 255.f));
}

inline uint32_t to_color(const glm::vec4 &c){
    uint8_t rgba[4];
    for (int ii=0; ii<4; ++ii)
        rgba[ii] = to_color_channel(c[ii]);
    return *(uint32_t*)rgba;
}

struct quaddata {
    quaddata() = default;
    quaddata& operator=(const quaddata &rhs){
        memcpy(v, rhs.v, sizeof(quaddata));
        return *this;
    }
    quad_vertex& operator[](uint32_t ii){ return v[ii]; }
    const quad_vertex& operator[](uint32_t ii) const { return v[ii]; }
    quad_vertex v[4];
    void reset();
    
    void transform(const glm::mat4 &trans);
    void scale(const glm::vec3 &s);
    void rotate(const glm::quat &r);
    void translate(const glm::vec3 &t);

    static const quaddata& default_quad();
};
using quadvector    = std::vector<quaddata>;

class quad_buffer{
public:
    void alloc(uint32_t numquad, bgfx_transient_vertex_buffer_t &tvb);
    void submit(const bgfx_transient_vertex_buffer_t &tvb);
    const bgfx_vertex_layout_t *layout;
    bgfx_index_buffer_handle_t ib;
};

class quad_cache{
public:
public:
    quad_cache(){}
    ~quad_cache() = default;
private:
    quad_cache(quad_cache&) = delete;
    quad_cache& operator=(quad_cache&) = delete;
public:
    //void update();
    void submit(uint32_t offset, uint32_t num);

    quadvector mquads;
    quad_buffer mqb;

};