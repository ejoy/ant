#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <luabgfx.h>

struct buffer{
    uint32_t start;
    uint32_t num;
    union {
        const bgfx_transient_vertex_buffer_t* tvb;
        const bgfx_transient_index_buffer_t*  tib;

        bgfx_vertex_buffer_handle_t     vbh;
        bgfx_index_buffer_handle_t      ibh;

        bgfx_dynamic_vertex_buffer_handle_t dvbh;
        bgfx_dynamic_index_buffer_handle_t dibh;
    };
    uint8_t type;
};

struct mesh {
    uint16_t next;
    struct buffer b;
};

struct encoder_holder {
    bgfx_encoder_t *encoder;
};

struct mesh_arena {
    bgfx_interface_vtbl_t *bgfx_;
    struct encoder_holder *eh_;

    uint32_t cap;
    uint32_t n;
    uint16_t freelist;
    struct mesh *m;
};

#define INVALID_MESH    UINT16_MAX

static inline struct mesh_arena*
arena_new(lua_State *L, bgfx_interface_vtbl_t *b, struct encoder_holder *e){
    struct mesh_arena* arena = (struct mesh_arena*)lua_newuserdatauv(L, sizeof(*arena), 0);
    arena->bgfx_ = b;
    arena->eh_ = e;
    arena->cap = arena->n;
    arena->freelist = INVALID_MESH;
    arena->m = NULL;
    return arena;
}

static int
lcobject_new(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
	if (lua_getfield(L, 1, "bgfx") != LUA_TLIGHTUSERDATA)
		return luaL_error(L, "Need bgfx api");
	bgfx_interface_vtbl_t *bgfx = lua_touserdata(L, -1);
	lua_pop(L, 1);
	if (lua_getfield(L, 1, "encoder") != LUA_TLIGHTUSERDATA)
		return luaL_error(L, "Need encoder holder");
	struct encoder_holder *eh = lua_touserdata(L, -1);
	lua_pop(L, 1);

    arena_new(L, bgfx, eh);
    return 1;
}

LUAMOD_API int
luaopen_mesh(lua_State *L) {
    luaL_Reg l[] = {
        {"cobject_new", lcobject_new},
        {NULL, NULL},
    };
    return 1;
}