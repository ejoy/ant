#include "lua.hpp"

#include "lua2struct.h"
#include "luabgfx.h"
#include "bgfx_interface.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

struct mesh {
    enum buffer_type : uint8_t{
        BT_static = 0,
        BT_dynamic,
        BT_transient,
        BT_none,
    };
    struct vb {
        uint32_t start;
        uint32_t num;
        union {
            bgfx_vertex_buffer_handle_t         s;
            bgfx_dynamic_vertex_buffer_handle_t d;
            bgfx_transient_vertex_buffer_t *    t;
        };
        buffer_type type;
    };
    
    struct ib {
        uint32_t start;
        uint32_t num;
        union {
            bgfx_index_buffer_handle_t          s;
            bgfx_dynamic_index_buffer_handle_t  d;
            bgfx_transient_index_buffer_t *     t;
        };
        buffer_type type;
    };

    struct vb vb;
    struct ib ib;
};

namespace lua_struct {
    template <class Type>
    inline void unpack_buffer(lua_State *L, int idx, Type &v){
        luaL_checktype(L, idx, LUA_TTABLE);
        unpack_field(L, idx, "start", v.start);
        unpack_field(L, idx, "num", v.num);
        const auto type = lua_getfield(L, idx, "handle");
        if (type == LUA_TUSERDATA){
            v.type = mesh::BT_transient;
            v.t = decltype(v.t)(lua_touserdata(L, -1));
        } else if (type == LUA_TNUMBER){
            const auto handle = (uint32_t)lua_tointeger(L, -1);
            auto subtype = BGFX_LUAHANDLE_SUBTYPE(handle);
            if (subtype == BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER ||
                subtype == BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS || 
                subtype == BGFX_HANDLE_DYNAMIC_INDEX_BUFFER || 
                subtype == BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32){
                v.type = mesh::BT_dynamic;
                v.d.idx = (uint16_t)handle;
            } else if (subtype = BGFX_HANDLE_VERTEX_BUFFER || subtype == BGFX_HANDLE_INDEX_BUFFER){
                v.type = mesh::BT_static;
                v.s.idx = (uint16_t)handle;
            } else {
                luaL_error(L, "Invalid vertex buffer handle:%d", subtype);
            }
        } else {
            luaL_error(L, "Invalid handle type");
        }
        lua_pop(L, 1);
    }
    template <>
    inline void unpack<struct mesh::vb>(lua_State* L, int idx, struct mesh::vb& v, void*) {
        unpack_buffer(L, idx, v);
    }

    template <>
    inline void unpack<struct mesh::ib>(lua_State* L, int idx, struct mesh::ib& v, void*) {
        unpack_buffer(L, idx, v);
    }

    template<>
    inline void unpack<struct mesh>(lua_State* L, int idx, struct mesh& v, void*) {
        unpack_field(L, idx, "vb", v.vb);

        v.ib.type = mesh::BT_none;
        unpack_field_opt(L, idx, "ib", v.ib);
    }
}

static void
mesh_submit(struct mesh*m, bgfx_encoder_t *encoder){
    if (m->vb.num > 0){
        assert(m->vb.start < m->vb.num);
        if (m->vb.type == mesh::BT_transient){
            BGFX(encoder_set_transient_vertex_buffer)(encoder, 0, m->vb.t, m->vb.start, m->vb.num);
        } else if (m->vb.type == mesh::BT_static){
            BGFX(encoder_set_vertex_buffer)(encoder, 0, m->vb.s, m->vb.start, m->vb.num);
        } else if (m->vb.type == mesh::BT_dynamic){
            BGFX(encoder_set_dynamic_vertex_buffer)(encoder, 0, m->vb.d, m->vb.start, m->vb.num);
        }
    }

    if (m->ib.type != mesh::BT_none && m->ib.num > 0){
        assert(m->vb.start < m->vb.num);
        if (m->ib.type == mesh::BT_transient){
            BGFX(encoder_set_transient_index_buffer)(encoder, m->ib.t, m->ib.start, m->ib.num);
        } else if (m->ib.type == mesh::BT_static){
            BGFX(encoder_set_index_buffer)(encoder, m->ib.s, m->ib.start, m->ib.num);
        } else if (m->ib.type == mesh::BT_dynamic){
            BGFX(encoder_set_dynamic_index_buffer)(encoder, m->ib.d, m->ib.start, m->ib.num);
        }
    }
}

static inline struct mesh*
to_mesh(lua_State *L, int idx){
    return (struct mesh*)luaL_checkudata(L, idx, "ANT_MESH");
}

static int
lmesh_submit(lua_State *L){
    auto m = to_mesh(L, 1);
    auto holder = (encoder_holder*)lua_touserdata(L, 2);
    mesh_submit(m, holder->encoder);
    return 0;
}

static int
lmesh_set_vb_range(lua_State *L){
    auto m = to_mesh(L, 1);
    lua_struct::unpack(L, 2, m->vb.start);
    lua_struct::unpack(L, 3, m->vb.num);
    return 0;
}

static int
lmesh_set_ib_range(lua_State *L){
    auto m = to_mesh(L, 1);
    if (m->ib.type != mesh::BT_none){
        lua_struct::unpack(L, 2, m->vb.start);
        lua_struct::unpack(L, 3, m->vb.num);
    } else {
        luaL_error(L, "mesh index buffer is empty");
    }

    return 0;
}

static int
lnew_mesh(lua_State *L){
    auto m = (struct mesh*)lua_newuserdatauv(L, sizeof(struct mesh), 0);
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_struct::unpack(L, 1, *m);

    if (luaL_newmetatable(L, "ANT_MESH")){
        luaL_Reg l[] = {
            { "submit", lmesh_submit},
            { "set_vb_range", lmesh_set_vb_range},
            { "set_ib_range", lmesh_set_ib_range},
			{ nullptr, nullptr },
		};

		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

extern "C" int
luaopen_mesh(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
        { "mesh",   lnew_mesh},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}
