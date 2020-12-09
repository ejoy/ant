#pragma once
#include "singleton.h"

#include <bgfx/c99/bgfx.h>

struct quad_vertex{
    glm::vec3   p;
    glm::vec2   uv;
    uint32_t    color;
};

inline uint8_t to_color_channel(float c){
    return uint8_t(std::min(255.f, c * 255.f));
}

inline uint32_t to_color(const glm::vec4 &c){
    uint8_t rgba[4];
    for (int ii=0; ii<4; ++ii)
        rgba[ii] = to_color_channel(c[ii]);
    return *(uint32_t*)rgba;
}

struct quaddata {
    quaddata();
    quad_vertex& operator[](uint32_t ii){ return v[ii]; }
    quad_vertex v[4];

    void transform(const glm::mat4 &trans);
    void scale(const glm::vec3 &s);
    void rotate(const glm::quat &r);
    void translate(const glm::vec3 &t);
};
using quadvector    = std::vector<quaddata>;

class quad_buffer{
public:
    void submit(const quadvector &quads);
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