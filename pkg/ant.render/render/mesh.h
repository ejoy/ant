#pragma once

#include <cstdint>

struct buffer_node {
    uint32_t start;
    uint32_t num;
    uint32_t handle;
    void clear(){
        start = num = 0;
        handle = 0xffffffff;
    }

    bool isvalid() const {
        return handle != 0xffffffff;
    }
};

enum BufferType : uint8_t {
    BT_vertexbuffer0 = 0,
    BT_vertexbuffer1,
    BT_indexbuffer,
    BT_count,
};

struct mesh_node {
    buffer_node buffers[BT_count];
    void clear() {
        for (auto &b :buffers){
            b.clear();
        }
    }
};

struct mesh_container;
struct mesh_container* mesh_create();
void mesh_destroy(struct mesh_container *MESH);
const struct mesh_node* mesh_fetch(struct mesh_container* MESH, int Midx);