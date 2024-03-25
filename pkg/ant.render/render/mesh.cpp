#include "lua.hpp"

#include "mesh.h"
#include "node_container.h"

#include "ecs/world.h"
#include <cstdint>

#include <cassert>
#include <cstring>

static constexpr int MAX_MESH_NODE = 1024;

struct mesh_container : public node_container<mesh_node>{
    mesh_container() : node_container<mesh_node>(MAX_MESH_NODE){}
    inline mesh_node* fetch(int Midx) {
        return &nodes[Midx];
    }

    inline buffer_node* fetch_buffer(int Midx, uint8_t bidx) {
        return &(fetch(Midx)->buffers[bidx]);
    }

    inline void set(int Midx, uint8_t bidx, uint32_t start, uint32_t num, uint32_t handle){
        auto b = fetch_buffer(Midx, bidx);
        b->start = start;
        b->num = num;
        b->handle = handle;
    }

    inline void set_start(int Midx, uint8_t bidx, uint32_t start){
        auto b = fetch_buffer(Midx, bidx);
        b->start = start;
    }

    inline void set_num(int Midx, uint8_t bidx, uint32_t num){
        auto b = fetch_buffer(Midx, bidx);
        b->num = num;
    }

    inline void set_handle(int Midx, uint8_t bidx, uint32_t handle) {
        auto b = fetch_buffer(Midx, bidx);
        b->handle = handle;
    }
};

struct mesh_container* mesh_create(){
    return new mesh_container();
}
void mesh_destroy(struct mesh_container *MESH){
    delete MESH;
}

const struct mesh_node*
mesh_fetch(struct mesh_container* MESH, int Midx){
    if (MESH->isvalid(Midx)){
        return &(MESH->nodes[Midx]);
    }

    return nullptr;
}

static int
lmesh_dealloc(lua_State *L){
    auto w = getworld(L);
    const int Midx = (int)luaL_checkinteger(L, 1);
    w->MESH->dealloc(Midx);
    return 0;
}

static int
lmesh_alloc(lua_State *L){
    auto w = getworld(L);
    lua_pushinteger(L, w->MESH->alloc());
    return 1;
}

static BufferType ToBT(const char* buffertype) {
    if (strcmp(buffertype, "vb0") == 0){
        return BT_vertexbuffer0;
    } else if (strcmp(buffertype, "vb1") == 0){
        return BT_vertexbuffer1;
    } else if (strcmp(buffertype, "ib") == 0){
        return BT_indexbuffer;
    } else {
        return BT_count;
    }
}

template<typename OP>
static void mesh_op(lua_State *L, ecs_world *w, int Mindex, int Bufferindex, OP op){
    const int Midx = (int)luaL_checkinteger(L, 1);
    if (!w->MESH->isvalid(Midx)){
        luaL_error(L, "Invalid mesh index");
    }

    auto buffertype = luaL_checkstring(L, 2);
    const BufferType bt = ToBT(buffertype);
    if (bt == BT_count){
        luaL_error(L, "Invalid buffer type:%s", buffertype);
    }

    op(Midx, bt);
}

static int
lmesh_set(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        const uint32_t start = (uint32_t)luaL_checkinteger(L, 3);
        const uint32_t num = (uint32_t)luaL_checkinteger(L, 4);
        const uint32_t handle = (uint32_t)luaL_checkinteger(L, 5);

        w->MESH->set(Midx, bt, start, num, handle);
    });
    return 0;
}

static int
lmesh_set_start(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        const uint32_t start = (uint32_t)luaL_checkinteger(L, 3);
        w->MESH->set_start(Midx, bt, start);
    });

    return 0;
}

static int
lmesh_set_num(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        const uint32_t num = (uint32_t)luaL_checkinteger(L, 3);
        w->MESH->set_num(Midx, bt, num);
    });


    return 0;
}

static int
lmesh_set_handle(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        const uint16_t handle = (uint16_t)luaL_checkinteger(L, 3);
        w->MESH->set_handle(Midx, bt, handle);
    });
    return 0;
}

static int
lmesh_fetch_range(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        auto b = w->MESH->fetch_buffer(Midx, bt);
        lua_pushinteger(L, b->start);
        lua_pushinteger(L, b->num);
    });

    return 2;
}

static int
lmesh_fetch_handle(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        auto b = w->MESH->fetch_buffer(Midx, bt);
        lua_pushinteger(L, b->handle);
    });

    return 1;
}

static int
lmesh_fetch(lua_State *L){
    auto w = getworld(L);
    mesh_op(L, w, 1, 2, [L, w](int Midx, BufferType bt){
        auto b = w->MESH->fetch_buffer(Midx, bt);
        lua_pushinteger(L, b->start);
        lua_pushinteger(L, b->num);
        lua_pushinteger(L, b->handle);
    });
    return 3;
}

extern "C" int
luaopen_render_mesh(lua_State *L){
    luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "dealloc",lmesh_dealloc},
		{ "alloc",	lmesh_alloc},

		{ "set",	    lmesh_set},
        { "set_start",	lmesh_set_start},
        { "set_num",	lmesh_set_num},
        { "set_handle",	lmesh_set_handle},

        { "fetch_range",lmesh_fetch_range},
        { "fetch_handle",lmesh_fetch_handle},
        { "fetch",      lmesh_fetch},
        
		{ nullptr, 	nullptr },
	};
	luaL_newlibtable(L,l);
    lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
