#pragma once
#include "singleton.h"

#include <bgfx/c99/bgfx.h>
struct quad_vertex{
    glm::vec3   p;
    glm::vec2   uv;
    uint32_t    color;
};

class quad_cache : public singletonT<quad_cache>{
    friend class singletonT<quad_cache>;
private:
    quad_cache(bgfx_index_buffer_handle_t ib, const bgfx_vertex_layout_t* layout, uint32_t maxvertices);
    quad_cache(quad_cache&) = delete;
    quad_cache& operator=(quad_cache&) = delete;
public:
    ~quad_cache();

    const bgfx_dynamic_vertex_buffer_handle_t get_vb() const { return mdyn_vb;}
    const bgfx_index_buffer_handle_t get_ib() const {return mib; }
    uint32_t alloc(uint32_t num){
        if (moffset + num > mquadsize){
            return UINT32_MAX;
        }
        auto o = moffset;
        moffset += num;
        return o;
    }

    //
    const quad_vertex& get_vertex(uint32_t quadidx, uint32_t vidx) const;
    quad_vertex& get_vertex(uint32_t quadidx, uint32_t vidx);

    void reset_quad(uint32_t start, uint32_t num);
    void set_pos(uint32_t quadidx, uint32_t vidx, const glm::vec3 &p);
    void set_uv(uint32_t quadidx, uint32_t vidx, const glm::vec2 &uv);
    void set_color(uint32_t quadidx, uint32_t vidx, uint32_t c);

    void set(uint32_t quadidx, uint32_t vidx, const quad_vertex &v);
    void set(uint32_t start, uint32_t num, const quad_vertex *vv);

    void init_transform(uint32_t quadidx);
    void transform(uint32_t quadidx, const glm::mat4 &trans);
    void rotate(uint32_t quadidx, const glm::quat &q);
    void scale(uint32_t quadidx, const glm::vec3 &s);
    void translate(uint32_t quadidx, const glm::vec3 &t);

    void update();

    void submit(uint32_t offset, uint32_t num);
private:
    const bgfx_vertex_layout_t *mlayout;
    const bgfx_index_buffer_handle_t mib;
    const bgfx_dynamic_vertex_buffer_handle_t mdyn_vb;
    const uint32_t  mquadsize;
    quad_vertex*    mvertiecs;
    uint32_t moffset;
};