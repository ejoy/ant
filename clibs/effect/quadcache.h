#pragma once
#include "singleton.h"

#include <bgfx/c99/bgfx.h>

class quad_cache{
public:
    struct vertex{
        glm::vec3   p;
        glm::vec2   uv;
        uint32_t    color;
    };
    using quad          = std::array<vertex, 4>;
    using quadvector    = std::vector<quad>;

    static void transform(quad_cache::quad &q, const glm::mat4 &trans);
    static void scale(quad_cache::quad &q, const glm::vec3 &s);
    static void rotate(quad_cache::quad &q, const glm::quat &r);
    static void translate(quad_cache::quad &q, const glm::vec3 &t);
public:
    quad_cache(bgfx_index_buffer_handle_t ib, const bgfx_vertex_layout_t* layout, uint32_t maxquad);
    ~quad_cache() = default;
private:
    quad_cache(quad_cache&) = delete;
    quad_cache& operator=(quad_cache&) = delete;
public:
    //void update();
    void submit(uint32_t offset, uint32_t num);

    quadvector mquads;
private:
    const bgfx_vertex_layout_t *mlayout;
    const bgfx_index_buffer_handle_t mib;
    const uint32_t  mmax_quad;
};