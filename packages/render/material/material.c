#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <luabgfx.h>

#define INVALID_ATTRIB 0xffff
#define DEFAULT_ARENA_SIZE 256

#define MAX_ATTRIB_NUM 256

#define ATTRIB_UNIFORM	0
#define ATTRIB_SAMPLER	1
#define ATTRIB_IMAGE	2
#define ATTRIB_BUFFER	3
#define ATTRIB_REF		4
// #define ATTRIB_DISABLE 4

struct attrib {
	uint16_t type;
	uint16_t next;
	union {
		// vec4/mat4/texture
		struct uniform
		{
			bgfx_uniform_handle_t handle;
			union {
				int64_t m;
				struct {
					uint32_t handle;
					uint8_t stage;
				} t;
			};
		}u;

		// image/buffer
		struct resource{
			uint32_t handle;
			uint8_t stage;
			uint8_t access;
			uint8_t mip;
		}r;

		uint16_t ref;
	};
};

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

// uv1: system attribs
// uv2: material invalid attrib list
struct attrib_arena {
	bgfx_interface_vtbl_t *bgfx;
	struct math3d_api *math;
	struct encoder_holder* eh;
	uint16_t cap;
	uint16_t n;
	uint16_t freelist;
	struct attrib *a;
};

//uv1: lookup table, [name: id]
struct system_attribs {
	uint16_t attrib;
};

//uv1: material instance metatable
//uv2: cobject
//uv3: lookup table, [name: id]
struct material {
	uint64_t state;
	uint32_t rgba;
	uint16_t attrib;
};

//TODO: patch attrib list should include world matrix
struct material_instance {
	uint16_t patch_attrib;
};

static inline void
init_attrib(struct attrib *a){
	a->next = a->type = INVALID_ATTRIB;
	a->u.m = 0;
}

struct attrib_arena *
arena_new(lua_State *L, bgfx_interface_vtbl_t *bgfx, struct math3d_api *mapi, struct encoder_holder *h) {
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), 2);
	a->bgfx = bgfx;
	a->math = mapi;
	a->eh = h;
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
	//invalid material attrib list
	lua_newtable(L);
	lua_setiuservalue(L, -2, 2);
	return a;
}

struct attrib *
arena_alloc(lua_State *L, int idx) {
	struct attrib_arena * a = (struct attrib_arena *)lua_touserdata(L, idx);
	struct attrib *ret;
	if (a->freelist != INVALID_ATTRIB) {
		ret = &a->a[a->freelist];
		a->freelist = ret->next;
	} else if (a->n < a->cap) {
		ret = &a->a[a->n];
		a->n++;
	} else if (a->cap == 0) {
		// new arena
		struct attrib * arena = (struct attrib *)lua_newuserdatauv(L, sizeof(struct attrib) * DEFAULT_ARENA_SIZE, 0);
		lua_setiuservalue(L, idx, 1);
		a->a = arena;
		a->cap = DEFAULT_ARENA_SIZE;
		a->n = 1;
		ret = a->a;
	} else {
		// resize arena
		int newcap = a->cap * 2;
		if (newcap > INVALID_ATTRIB)
			luaL_error(L, "Too many attribs");
		struct attrib * arena = (struct attrib *)lua_newuserdatauv(L, sizeof(struct attrib) * newcap, 0);
		memcpy(arena, a->a, sizeof(struct attrib) * a->n);
		a->a = arena;
		lua_setiuservalue(L, idx, 1);
		ret = &a->a[a->n++];
	}
	ret->next = INVALID_ATTRIB;
	ret->u.handle.idx = UINT16_MAX;
	return ret;
}

static void
arena_return(struct attrib_arena * arena, struct attrib *a) {
	uint16_t id = (uint16_t)(a - arena->a);
	a->next = arena->freelist;
	arena->freelist = id;
}

static inline uint16_t
clear_attrib(struct attrib_arena *arena, uint16_t id) {
	struct attrib *a = &arena->a[id];
	if (a->type == ATTRIB_UNIFORM) {
		math3d_unmark_id(arena->math, a->u.m);
		a->u.m = 0;
	}
	id = a->next;
	arena_return(arena, a);
	return id;
}

static void
clear_unused_attribs(lua_State *L, struct attrib_arena *arena, int n) {
	int i;
	for (i=0;i<n;i++) {
		lua_rawgeti(L, -1, i+1);
		uint16_t id = (uint16_t)luaL_checkinteger(L, -1);
		lua_pop(L, 1);
		lua_pushnil(L);
		lua_rawseti(L, -2, i+1);
		do {
			id = clear_attrib(arena, id);
		} while (id != INVALID_ATTRIB);
	}
}

static inline struct attrib_arena *
get_cobject(lua_State *L, int idx) {
	struct attrib_arena *api = (struct attrib_arena *)lua_touserdata(L, idx);
	if (api == NULL)
		luaL_error(L, "Invalid C API");
	return api;
}

#define CAPI_INIT(L, idx) struct attrib_arena * cobject_ = get_cobject(L, idx);
#define CAPI_ARENA cobject_
#define CAPI_MATH3D cobject_->math
#define BGFX(api) cobject_->bgfx->api
#define BGFX_INVALID(h) (h.idx == UINT16_MAX)
#define BGFX_EQUAL(a,b) (a.idx == b.idx)

static void
uniform_value(lua_State *L, struct attrib *a) {
	switch (a->type){
		case ATTRIB_UNIFORM:
			lua_pushlightuserdata(L, (void *)a->u.m);
			break;
		case ATTRIB_SAMPLER:
			lua_pushfstring(L, "s%d:%x", a->u.t.stage, a->u.t.handle);
			break;
		default:
			luaL_error(L, "Invalid uniform attribute type:%d, image|buffer is not uniform attrib", a->type);
			break;
	}
}

// 1: material
static int
lmaterial_attribs(lua_State *L) {
	struct material *mat = (struct material *)luaL_checkudata(L, 1, "ANT_MATERIAL");
	lua_settop(L, 1);
	int t = lua_getiuservalue(L, 1, 2);
	CAPI_INIT(L, 2);
	struct attrib_arena *arena = CAPI_ARENA;
	lua_newtable(L);
	int result_index = lua_gettop(L);
	uint16_t attrib_id = mat->attrib;
	while (attrib_id != INVALID_ATTRIB) {
		struct attrib * a = &arena->a[attrib_id];
		switch(a->type){
			case ATTRIB_UNIFORM:
			case ATTRIB_SAMPLER:{
				bgfx_uniform_info_t info;
				BGFX(get_uniform_info)(a->u.handle, &info);
			
				if (info.num == 1) {
					uniform_value(L, a);
				} else {
					lua_createtable(L, info.num, 0);
					int i;
					for (i=0;i<info.num;i++) {
						if (a == NULL)
							return luaL_error(L, "Invalid multiple uniform");
						uniform_value(L, a);
						lua_rawseti(L, -2, i+1);
						attrib_id = a->next;
						a = (attrib_id == INVALID_ATTRIB) ? NULL : &arena->a[attrib_id];
					}
				}
				lua_setfield(L, result_index, info.name);
			}
			break;
			case ATTRIB_IMAGE:
				lua_pushfstring(L, "i%d:%x:%d:%d", a->r.stage, a->r.handle, a->r.mip, a->r.access);
				break;
			case ATTRIB_BUFFER:
				lua_pushfstring(L, "b%d:%x:%d", a->r.stage, a->r.handle, a->r.access);
				break;
			case ATTRIB_REF:
				lua_pushfstring(L, "r%d", a->ref);
			default:
				luaL_error(L, "Invalid Attrib type");
				break;
		}
		attrib_id = a->next;
	}
	return 1;
}

static int inline
hex2n(lua_State *L, char c) {
	if (c>='0' && c<='9')
		return c-'0';
	else if (c>='A' && c<='F')
		return c-'A' + 10;
	else if (c>='a' && c<='f')
		return c-'a' + 10;
	return luaL_error(L, "Invalid state %c", c);
}

static inline void
get_state(lua_State *L, int idx, uint64_t *pstate, uint32_t *prgba) {
	size_t sz;
	const uint8_t * data = (const uint8_t *)luaL_checklstring(L, idx, &sz);
	if (sz != 16 && sz != 24) {
		luaL_error(L, "Invalid state length %d", sz);
	}
	uint64_t state = 0;
	uint32_t rgba = 0;
	int i;
	for (i=0;i<15;i++) {
		state |= hex2n(L,data[i]);
		state <<= 4;
	}
	state |= hex2n(L,data[15]);
	if (sz == 24) {
		for (i=0;i<7;i++) {
			rgba |= hex2n(L,data[16+i]);
			rgba <<= 4;
		}
		rgba |= hex2n(L,data[23]);
	}
	*pstate = state;
	*prgba = rgba;
}

static inline uint8_t
to_attrib_type(lua_State *L, int index){
	const int lt = lua_getfield(L, index, "type");
	if (lt != LUA_TSTRING){
		lua_pop(L, 1);
		luaL_error(L, "Invalid attrib value, 'type' filed:%s, is not string", lua_typename(L, lt));
	}
	const char  c = lua_tostring(L, -1)[0];
	lua_pop(L, 1);

	switch (c){
		case 't': return ATTRIB_SAMPLER;
		case 'i': return ATTRIB_IMAGE;
		case 'b': return ATTRIB_BUFFER;
		case 'u':
		case '\0':
		// could not be ATTRIB_REF
		default: return ATTRIB_UNIFORM;
	}
}

static inline uint16_t
attrib_id(struct attrib_arena *arena, struct attrib *a) {
	return (uint16_t)(a - arena->a);
}

static inline int
is_uniform_attrib(struct attrib *a){
	return a->type == ATTRIB_UNIFORM || a->type == ATTRIB_SAMPLER;
}

// 1: material
static int
lmaterial_instance(lua_State *L) {
	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), 0);
	mi->patch_attrib = INVALID_ATTRIB;
	lua_getiuservalue(L, 1, 1);		// push material instance metatable
	int n = (int)lua_rawlen(L, -1);	// free instance attrib
	if (n > 0) {
		lua_getfield(L, -1, "__gc");
		if (lua_getupvalue(L, -1, 2) == NULL)
			return luaL_error(L, "Invalid material metatable");
		struct attrib_arena * arena = lua_touserdata(L, -1);
		lua_pop(L, 2);
		clear_unused_attribs(L, arena, n);
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
count_attrib_num(lua_State *L, struct attrib_arena *arena, struct attrib* a) {
	int c = 1;
	if (is_uniform_attrib(a)){
		const bgfx_uniform_handle_t h = a->u.handle;
		const uint16_t type = a->type;
		struct attrib* na = a;
		while(na->next != INVALID_ATTRIB){
			na = arena->a + na->next;
			if (type != na->type || !BGFX_EQUAL(h, na->u.handle)){
				break;
			}
			++c;
		}
	}
	return c;
}

static uint16_t *
find_patch_attrib(struct material_instance *mi, struct attrib_arena *arena, struct attrib* a) {
	if (!is_uniform_attrib(a))
		return NULL;

	uint16_t *ret = &mi->patch_attrib;
	while (*ret != INVALID_ATTRIB) {
		struct attrib * ra = arena->a+ *ret;
		assert(is_uniform_attrib(ra));
		if (BGFX_EQUAL(a->u.handle, ra->u.handle))
			return ret;
		ret = &ra->next;
	}
	return NULL;
}

static void
unset_instance_attrib(struct material_instance *mi, struct attrib_arena *arena, struct attrib *a, int n) {
	uint16_t * ref = find_patch_attrib(mi, arena, a);
	if (ref){
		int i;
		uint16_t id = *ref;
		for (i=0;i<n;i++) {
			id = clear_attrib(arena, id);
		}
		*ref = id;
	}
}

static void
update_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int index) {
	switch (a->type){
		case ATTRIB_UNIFORM:{
			const int datatype = lua_type(L, index);
			if (datatype == LUA_TTABLE){
				lua_getfield(L, index, "value");
				math3d_unmark_id(arena->math, a->u.m);
				a->u.m = math3d_mark_id(L, arena->math, -1);
				lua_pop(L, 1);
			} else if (datatype == LUA_TLIGHTUSERDATA || datatype == LUA_TUSERDATA){
				math3d_unmark_id(arena->math, a->u.m);
				a->u.m = math3d_mark_id(L, arena->math, index);
			} else {
				luaL_error(L, "Invalid data for 'uniform' value, type:%s, should be table with 'value' field, or math3d value", lua_typename(L, datatype));
			}
		}
			break;
		case ATTRIB_SAMPLER:
			const int datatype = lua_type(L, index);
			if (datatype == LUA_TTABLE){
				lua_getfield(L, index, "stage");
				a->r.stage = (uint8_t)lua_tointeger(L, -1);
				lua_pop(L, 1);	// stage

				lua_getfield(L, index, "value");
				a->u.t.handle = (uint32_t)luaL_optinteger(L, index, UINT16_MAX);
				lua_pop(L, 1);
			} else if (datatype == LUA_TNUMBER) {
				a->u.t.handle = (uint32_t)luaL_checkinteger(L, index);
			} else {
				luaL_error(L, "Invalid data for 'texture' value, type:%s, should be table with 'value' field, or bgfx texture handle", lua_typename(L, datatype));
			}
			break;
		case ATTRIB_IMAGE:
			luaL_checktype(L, index, LUA_TTABLE);
			lua_getfield(L, index, "mip");
			a->r.mip = (uint8_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		//walk through
		case ATTRIB_BUFFER: {
			luaL_checktype(L, index, LUA_TTABLE);
			lua_getfield(L, index, "access");
			const char* access = lua_tostring(L, -1);
			if (strcmp(access, "w") == 0){
				a->r.access = BGFX_ACCESS_WRITE;
			} else if (strcmp(access, "r") == 0){
				a->r.access = BGFX_ACCESS_READ;
			} else if (strcmp(access, "rw") == 0){
				a->r.access = BGFX_ACCESS_READWRITE;
			} else {
				luaL_error(L, "Invalid access type:%s", access);
			}
			lua_pop(L, 1);	// access

			lua_getfield(L, index, "stage");
			a->r.stage = (uint8_t)lua_tointeger(L, -1);
			lua_pop(L, 1);	// stage

			lua_getfield(L, index, "value");
			a->r.handle = (uint32_t)luaL_optinteger(L, -1, UINT16_MAX);
			lua_pop(L, 1); // handle
		}
			break;
		default:
			luaL_error(L, "Invalid attribute type:%d", a->type);
			break;
	}
}

static inline int
is_uniform_array(lua_State *L, uint16_t uniformtype, int data_index){
	if ((uniformtype == ATTRIB_UNIFORM || uniformtype == ATTRIB_SAMPLER) && (LUA_TTABLE == lua_type(L, data_index))){
		int n = 0;
		if (LUA_TTABLE == lua_getfield(L, data_index, "value")){
			n = (int)lua_rawlen(L, data_index);
		}
		lua_pop(L, 1);
		return n;
	}

	return 0;
}

static struct attrib*
new_attrib(lua_State *L, int arena_index, int data_index, uint16_t attribtype, struct attrib * prev){
	struct attrib* a = arena_alloc(L, arena_index);
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_index);

	init_attrib(a, attribtype);
	update_attrib(L, arena, a, data_index);
	if (prev){
		prev->next = attrib_id(arena, a);
	}

	return a;
}

static struct attrib*
gen_attrib(lua_State *L, int arena_index, int data_index){;
	const uint16_t type = to_attrib_type(L, data_index);
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, arena_index);
	
	if (type == ATTRIB_UNIFORM || type == ATTRIB_SAMPLER){
		lua_getfield(L, data_index, "value");
		const int n = (int)lua_rawlen(L, -1);
		if (n > 0){
			struct attrib * prev = NULL;
			for (int i=0; i<n; ++i){
				lua_geti(L, -1, i+1);
				prev = new_attrib(L, arena_index, -1, type, prev);
				lua_pop(L, 1);
			}
			lua_pop(L, 1);
			return prev;
		}
		lua_pop(L, 1);
	}

	return new_attrib(L, arena_index, data_index, type, NULL);
}

static inline struct attrib*
next_attrib(struct attrib_arena *arena, struct attrib *a){
	return (a->next == INVALID_ATTRIB) ? NULL : &arena->a[a->next];
}

static void
replace_instance_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int value_index, int n) {
	if (n == 1) {
		update_attrib(L, arena, a, value_index);
	} else {
		int i;
		for (i=0;i<n;i++) {
			if (a == NULL)
				luaL_error(L, "Replace attrib error");
			lua_geti(L, value_index, i+1);
			update_attrib(L, arena, a, -1);
			lua_pop(L, 1);
			a = next_attrib(arena, a);
		}
	}
}

static struct attrib *
new_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, int cobject_index, struct attrib *a, int value_index) {
	struct attrib * new_attrib = arena_alloc(L, cobject_index);
	init_attrib(new_attrib);
	new_attrib->type = a->type;
	update_attrib(L, arena, new_attrib, value_index);
	return new_attrib;
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, struct attrib * a, int value_index, int n) {
	uint16_t * ref = find_patch_attrib(mi, arena, a);
	if (ref == NULL) {
		if (n == 1) {
			struct attrib * na = new_instance_attrib(L, mi, arena, lua_upvalueindex(3), a, value_index);
			mi->patch_attrib = attrib_id(arena, na);
		} else {
			int i;
			uint16_t last_id = mi->patch_attrib;
			luaL_checktype(L, value_index, LUA_TTABLE);
			for (i=0;i<n;i++) {
				lua_geti(L, value_index, i+1);
				if (a == NULL)
					luaL_error(L, "Invalid material attrib");
				struct attrib * na = new_instance_attrib(L, mi, arena, lua_upvalueindex(3), a, -1);
				na->next = last_id;
				last_id = attrib_id(arena, na);
				lua_pop(L, 1);
				a = next_attrib(arena, a);
			}
			mi->patch_attrib = last_id;
		}
	} else {
		replace_instance_attrib(L, arena, &arena->a[*ref], value_index, n);
	}
}

// upvalue 1: material
// upvalue 2: cobject
// 1: material_instance
// 2: uniform name
// 3: value
static int
lset_attrib(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, lua_upvalueindex(2));
	lua_pushvalue(L, 2);
	if (lua_rawget(L, lua_upvalueindex(3)) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, 2, NULL));
	}
	const int id = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);

	struct attrib * a = arena->a + id;
	if (!is_uniform_attrib(a)){
		return luaL_error(L, "only uniform & sampler attrib can modify");
	}

	const int n = count_attrib_num(L, arena, a);
	if (lua_type(L, 3) == LUA_TNIL) {
		unset_instance_attrib(mi, arena, a, n);
	} else {
		set_instance_attrib(L, mi, arena, a, 3, n);
	}
	return 0;
}

static int
lmaterial_gc(lua_State *L) {
	struct material *mat = (struct material *)lua_touserdata(L, 1);
	// material_instance metatable
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
		return 0;
	}
	int free_instance = (int)lua_rawlen(L, -1);
	int instance_index = lua_gettop(L);
	if (lua_getfield(L, -1, "__gc") != LUA_TFUNCTION) {
		return 0;
	}
	lua_getupvalue(L, -1, 2);	// cobject
	lua_getiuservalue(L, -1, 2);// material invalid attrib list table
	int n = (int)lua_rawlen(L, -1);
	if (mat->attrib != INVALID_ATTRIB) {
		lua_pushinteger(L, mat->attrib);
		lua_rawseti(L, -2, ++n);
		mat->attrib = INVALID_ATTRIB;
	}
	lua_pop(L, 2);				// cobject, material invalid attrib list

	//push material instance invalid attrib list to material invalid attrib list table
	int i;
	for (i=0;i<free_instance;i++) {
		lua_rawgeti(L, instance_index, i+1);
		lua_rawseti(L, -2, ++n);
	}
	return 0;
}

static int
lcollect_attrib(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
	if (mi->patch_attrib != INVALID_ATTRIB) {
		lua_getmetatable(L, 1);
		int n = (int)lua_rawlen(L, -1);
		lua_pushinteger(L, mi->patch_attrib);
		lua_rawseti(L, -2, n + 1);
		mi->patch_attrib = INVALID_ATTRIB;
	}

	return 0;
}

#define MAX_UNIFORM_NUM 1024

static inline struct attrib*
next_uniform_attrib(struct attrib_arena* arena, struct attrib* a){
	if (a->next == INVALID_ATTRIB)
		return NULL;
	
	struct attrib* na = &arena->a[a->next];
	if (!is_uniform_attrib(na))
		return NULL;
	
	return BGFX_EQUAL(a->u.handle, na->u.handle) ? na : NULL;
}

static uint16_t
apply_attrib(lua_State *L, struct attrib_arena * cobject_, struct attrib *a, int texture_index) {
	if (a->type == ATTRIB_REF){
		struct attrib *ra = &cobject_->a[a->ref];
		apply_attrib(L, cobject_, ra, texture_index);
		return a->next;
	}
	if (a->type == ATTRIB_SAMPLER || a->type == ATTRIB_IMAGE) {
		bgfx_texture_handle_t tex;
		lua_geti(L, texture_index, a->u.t.handle);
		tex.idx = luaL_optinteger(L, -1, a->u.t.handle) & 0xffff;
		lua_pop(L, 1);
		if (a->type == ATTRIB_SAMPLER){
			BGFX(encoder_set_texture)(cobject_->eh->encoder, a->u.t.stage, a->u.handle, tex, UINT32_MAX);
		} else {
			BGFX(encoder_set_image)(cobject_->eh->encoder, a->r.stage, tex, a->r.mip, a->r.access, BGFX_TEXTURE_FORMAT_UNKNOWN);
		}
		return a->next;
	}

	if (a->type == ATTRIB_BUFFER){
		const uint16_t id = a->r.handle & 0xffff;
		const uint16_t type = a->r.handle >> 16;
		switch(type) {
		case BGFX_HANDLE_VERTEX_BUFFER: {
			bgfx_vertex_buffer_handle_t handle = { id };
			BGFX(encoder_set_compute_vertex_buffer)(cobject_->eh->encoder, a->r.stage, handle, a->r.access);
			break;
		}
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
			bgfx_dynamic_vertex_buffer_handle_t handle = { id };
			BGFX(encoder_set_compute_dynamic_vertex_buffer)(cobject_->eh->encoder, a->r.stage, handle, a->r.access);
			break;
		}
		case BGFX_HANDLE_INDEX_BUFFER: {
			bgfx_index_buffer_handle_t handle = { id };
			BGFX(encoder_set_compute_index_buffer)(cobject_->eh->encoder, a->r.stage, handle, a->r.access);
			break;
		}
		case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32:
		case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER: {
			bgfx_dynamic_index_buffer_handle_t handle = { id };
			BGFX(encoder_set_compute_dynamic_index_buffer)(cobject_->eh->encoder, a->r.stage, handle, a->r.access);
			break;
		}
		case BGFX_HANDLE_INDIRECT_BUFFER: {
			bgfx_indirect_buffer_handle_t handle = { id };
			BGFX(encoder_set_compute_indirect_buffer)(cobject_->eh->encoder, a->r.stage, handle, a->r.access);
			break;
		}
		default:
			return luaL_error(L, "Invalid buffer type %d", type);
		}
	}
	struct attrib_arena * arena = cobject_;
	struct attrib* next = next_uniform_attrib(arena, a);
	if (next == NULL){
		int t;
		const float * v = math3d_value(CAPI_MATH3D, a->u.m, &t);
		BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, v, 1);
		return a->next;
	}
	// multiple uniforms
	float buffer[MAX_UNIFORM_NUM * 16];
	float *ptr = buffer;
	int n = 0;
	do {
		int t;
		int stride;
		const float * v = math3d_value(CAPI_MATH3D, a->u.m, &t);
		if (t == LINEAR_TYPE_MAT) {
			stride = 16;
		} else {
			stride = 4;
		}
		if (ptr + stride - buffer > MAX_UNIFORM_NUM * 16)
			luaL_error(L, "Too many uniforms %d", n);
		memcpy(ptr, v, stride * sizeof(float));
		ptr += stride;
		a = next;
		++n;
		next = next_uniform_attrib(arena, a);
	} while (a);
	BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, buffer, n);
	return a->next;
}

static inline uint16_t
next_id(struct attrib_arena *arena, uint16_t id){
	struct attrib* a = arena->a + id;
	if (is_uniform_attrib(a)){
		const bgfx_uniform_handle_t h = a->u.handle;
		while(a->next != INVALID_ATTRIB){
			struct attrib* na = arena->a + a->next;
			if (!(is_uniform_attrib(na) && BGFX_EQUAL(na->u.handle, h))){
				break;
			}
			a = na;
		}
	}
	return a->next;
}

// 1: material_instance
// 2: texture lookup table
static int
lapply_attrib(lua_State *L) {
	struct material_instance *mi = (struct material_instance *)lua_touserdata(L, 1);
	const int texture_index = 2;
	luaL_checktype(L, texture_index, LUA_TTABLE);
	struct material *mat = (struct material *)lua_touserdata(L, lua_upvalueindex(1));
	CAPI_INIT(L, lua_upvalueindex(2));
	BGFX(encoder_set_state)(cobject_->eh->encoder, mat->state, mat->rgba);

	if (mi->patch_attrib == INVALID_ATTRIB) {
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = next_id(cobject_, id)){
			struct attrib* a = cobject_->a + id;
			apply_attrib(L, cobject_, a, texture_index);
		}
	} else {
		uint16_t ids[MAX_UNIFORM_NUM];
		uint16_t num_attrib = 0;
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = next_id(cobject_, id)){
			ids[num_attrib++] = id;
		}

		for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = next_id(cobject_, pid)){
			struct attrib* pa = cobject_->a+pid;
			assert(is_uniform_attrib(pa));
			for (int i=0; i<num_attrib; ++i){
				struct attrib* a = cobject_->a+ids[i];
				if (is_uniform_attrib(a) && BGFX_EQUAL(pa->u.handle, a->u.handle)){
					ids[i] = pid;
					break;
				}
			}
		}

		for (int i=0; i<num_attrib; ++i){
			struct attrib *a = cobject_->a+ids[i];
			apply_attrib(L, cobject_, a, texture_index);
		}
	}

	return 0;
}

// 1: material
// 2: cobject
static void
create_material_instance_metatable(lua_State *L) {
	luaL_Reg l[] = {
		{ "__newindex", lset_attrib		},
		{ "__gc", 		lcollect_attrib	},
		{ "__call", 	lapply_attrib	},
		{ NULL, 		NULL },
	};
	luaL_newlibtable(L, l);
	lua_insert(L, -3);
	luaL_setfuncs(L, l, 2);
}

// 1: cobject
// 2: render state (string)
// 3: uniforms (table)
static int
lmaterial_new(lua_State *L) {
	CAPI_INIT(L, 1);
	uint64_t state;
	uint32_t rgba;
	get_state(L, 2, &state, &rgba);
	lua_settop(L, 3);
	struct math3d_api *mapi = CAPI_MATH3D;
	struct attrib_arena * arena = CAPI_ARENA;
	struct material *mat = (struct material *)lua_newuserdatauv(L, sizeof(*mat), 3);

	// push 2 up value for material_instance metatable functions
	lua_pushvalue(L, -1);	// material
	lua_pushvalue(L, 1);	// cobject
	create_material_instance_metatable(L);
	lua_setiuservalue(L, -2, 1);			// push material instance metatable as uv1

	lua_pushvalue(L, 1);
	lua_setiuservalue(L, -2, 2);			// push cobject as uv2

	mat->state = state;
	mat->rgba = rgba;
	mat->attrib = INVALID_ATTRIB;
	uint16_t *pattrib = &mat->attrib;
	
	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);

	lua_getiuservalue(L, 1, 1);	//system attribs
	lua_getiuservalue(L, -1, 1); //lookup table
	const int sa_lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 3) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		struct attrib* a;
		if (LUA_TNIL != lua_getfield(L, lookup_idx, key)){
			a = arena_alloc(L, 1);
			// system attribs
			a->type = ATTRIB_REF;
			a->ref = (uint16_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		} else {
			lua_pop(L, 1);
			a = gen_attrib(L, 1, -1);
		}
		uint16_t id = attrib_id(cobject_, a);
		*pattrib = id;
		pattrib = &a->next;

		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, key);
	}
	lua_pop(L, 2);	//system attribs, lookup table

	lua_setiuservalue(L, -2, 3);			// push lookup table as uv3

	if (luaL_newmetatable(L, "ANT_MATERIAL")) {
		luaL_Reg l[] = {
			{ "__gc",		lmaterial_gc },
			{ "attribs", 	lmaterial_attribs },
			{ "instance", 	lmaterial_instance },
			{ NULL, 		NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lcobject_new(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	if (lua_getfield(L, 1, "bgfx") != LUA_TLIGHTUSERDATA)
		return luaL_error(L, "Need bgfx api");
	bgfx_interface_vtbl_t *bgfx = lua_touserdata(L, -1);
	lua_pop(L, 1);
	if (lua_getfield(L, 1, "math3d") != LUA_TLIGHTUSERDATA)
		return luaL_error(L, "Need math3d api");
	struct math3d_api *mapi = lua_touserdata(L, -1);
	lua_pop(L, 1);

	if (lua_getfield(L, 1, "encoder") != LUA_TLIGHTUSERDATA)
		return luaL_error(L, "Need encoder holder");
	struct encoder_holder *eh = lua_touserdata(L, -1);
	lua_pop(L, 1);
	arena_new(L, bgfx, mapi, eh);
	return 1;
}

static int
lsystem_attribs_new(lua_State *L){
	CAPI_INIT(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);

	struct system_attribs *sa = (struct system_attribs*)lua_newuserdatauv(L, sizeof(struct system_attribs), 1);
	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 2) != 0; lua_pop(L, 1)) {
		const char* name = lua_tostring(L, -2);
		struct attrib* a = gen_attrib(L, 1, -1);
		const uint16_t id = attrib_id(cobject_, a);
		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, name);
	}

	lua_setiuservalue(L, -2, 1);	// lookup table in -1, push lookup table as 'system_attribs' No.1 uservalue
	return 1;
}

LUAMOD_API int
luaopen_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "cobject", 		lcobject_new },
		{ "material",		lmaterial_new},
		{ "system_attribs", lsystem_attribs_new},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

