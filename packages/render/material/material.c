#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

#include <luabgfx.h>

#define INVALID_ATTRIB 0xffff
#define DEFAULT_ARENA_SIZE 256

#define ATTRIB_UNIFORM	0
#define ATTRIB_SAMPLER	1
#define ATTRIB_IMAGE	2
#define ATTRIB_BUFFER	3
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
	};
};

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

struct attrib_arena {
	bgfx_interface_vtbl_t *bgfx;
	struct math3d_api *math;
	struct encoder_holder* eh;
	uint16_t cap;
	uint16_t n;
	uint16_t freelist;
	struct attrib *a;
};

// uservalue 1 : table { name -> index }
// uservalue 2 : cobject
struct program {
	int n_uniform;
	bgfx_program_handle_t prog;
	bgfx_uniform_handle_t u[1];
};

struct material {
	uint64_t state;
	uint32_t rgba;
	bgfx_program_handle_t prog;
	uint16_t attrib;
};

struct material_instance {
	uint16_t patch_attrib;
};

struct attrib_arena *
arena_new(lua_State *L, bgfx_interface_vtbl_t *bgfx, struct math3d_api *mapi, struct encoder_holder *h) {
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), 1);
	a->bgfx = bgfx;
	a->math = mapi;
	a->eh = h;
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
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
clear_program_attribs(lua_State *L, int program_index, int cobject_index) {
	struct attrib_arena *arena = (struct attrib_arena *)lua_touserdata(L, cobject_index);
	if (arena == NULL)
		luaL_error(L, "Invalid cobject");
	if (lua_getiuservalue(L, program_index, 1) != LUA_TTABLE) {
		luaL_error(L, "Invalid program");
	}
	int n = (int)lua_rawlen(L, -1);
	if (n > 0)
		clear_unused_attribs(L, arena, n);
	lua_pop(L, 1);
}

static int
lprogram_delete(lua_State *L) {
	struct program *p = (struct program *)luaL_checkudata(L, 1, "ANT_PROGRAM");
	lua_settop(L, 1);
	lua_getiuservalue(L, 1, 2);
	CAPI_INIT(L, 2);
	clear_program_attribs(L, 1, 2);
	if (!BGFX_INVALID(p->prog)) {
		BGFX(destroy_program)(p->prog);
		p->prog.idx = UINT16_MAX;
	}
	return 0;
}

static int
lprogram_collect(lua_State *L) {
	struct program *p = (struct program *)luaL_checkudata(L, 1, "ANT_PROGRAM");
	lua_settop(L, 1);
	lua_getiuservalue(L, 1, 2);
	clear_program_attribs(L, 1, 2);
	return 0;
}

static const char *
uniform_type(bgfx_uniform_type_t t) {
	switch(t) {
	case BGFX_UNIFORM_TYPE_SAMPLER:
		return "sampler";
	case BGFX_UNIFORM_TYPE_VEC4:
		return "vec4";
	case BGFX_UNIFORM_TYPE_MAT3:
		return "mat3";
	case BGFX_UNIFORM_TYPE_MAT4:
		return "mat4";
	default:
		return "unknown";
	};
}

static int
lprogram_info(lua_State *L) {
	struct program *p = (struct program *)luaL_checkudata(L, 1, "ANT_PROGRAM");
	lua_settop(L, 1);
	lua_getiuservalue(L, 1, 2);
	CAPI_INIT(L, 2);
	lua_newtable(L);
	int i;
	for (i=0;i<p->n_uniform;i++) {
		bgfx_uniform_info_t info;
		BGFX(get_uniform_info)(p->u[i], &info);
		if (info.num == 1) {
			lua_pushstring(L, uniform_type(info.type));
		} else {
			lua_pushfstring(L, "%s(%d)", uniform_type(info.type), info.num);
		}
		lua_setfield(L, -2, info.name);
	}
	return 1;
}

static void
gen_lookuptable(lua_State *L, struct program *p) {
	CAPI_INIT(L, 1);
	lua_createtable(L, p->n_uniform, 0);
	int i;
	int index = 0;
	for (i=0;i<p->n_uniform;i++) {
		bgfx_uniform_info_t info;
		BGFX(get_uniform_info)(p->u[i], &info);
		lua_pushinteger(L, index);
		lua_setfield(L, -2, info.name);
		index += info.num;
	}
}

static inline void
swap_uniform(struct program *p, int a, int b) {
	bgfx_uniform_handle_t t = p->u[a];
	p->u[a] = p->u[b];
	p->u[b] = t;
}

static void
remove_duplicate_uniform(struct program *p, int n) {
	int i,j;
	int first_part = p->n_uniform - n;
	int dup = 0;
	i = 0;
	for (i=0;i<n;i++) {
		int index = first_part + i;
		for (j=dup;j<first_part;j++) {
			if (BGFX_EQUAL(p->u[j], p->u[index])) {
				swap_uniform(p, dup++, j);
				p->u[index] = p->u[--p->n_uniform];
				--first_part;
				break;
			}
		}
	}
}

static void
attrib_value(lua_State *L, struct attrib *a) {
	switch (a->type){
		case ATTRIB_UNIFORM:
			lua_pushlightuserdata(L, (void *)a->u.m);
			break;
		case ATTRIB_SAMPLER:
			lua_pushfstring(L, "s%d:%x", a->u.t.stage, a->u.t.handle);
			break;
		case ATTRIB_IMAGE:
			lua_pushfstring(L, "i%d:%x:%d:%d", a->r.stage, a->r.handle, a->r.mip, a->r.access);
			break;
		case ATTRIB_BUFFER:
			lua_pushfstring(L, "b%d:%x:%d", a->r.stage, a->r.handle, a->r.access);
			break;
		default:
			luaL_error(L, "Invalid attribute type:%d", a->type);
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
		bgfx_uniform_info_t info;
		struct attrib * a = &arena->a[attrib_id];
		BGFX(get_uniform_info)(a->u.handle, &info);
		if (info.num == 1) {
			attrib_value(L, a);
		} else {
			lua_createtable(L, info.num, 0);
			int i;
			for (i=0;i<info.num;i++) {
				if (a == NULL)
					return luaL_error(L, "Invalid multiple uniform");
				attrib_value(L, a);
				lua_rawseti(L, -2, i+1);
				attrib_id = a->next;
				if (attrib_id == INVALID_ATTRIB)
					a = NULL;
				else
					a = &arena->a[attrib_id];
			}
		}
		lua_setfield(L, result_index, info.name);
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

static struct attrib *
gen_uniform_attrib(lua_State *L, int arena_index, const bgfx_uniform_info_t *info, bgfx_uniform_handle_t handle, int type, struct math3d_api *mapi) {
	struct attrib *a = arena_alloc(L, arena_index);
	a->u.handle = handle;
	a->next = INVALID_ATTRIB;
	if (info->type == BGFX_UNIFORM_TYPE_SAMPLER) {
		if (type != LUA_TTABLE)
			luaL_error(L, "Need texture");
		a->type = ATTRIB_SAMPLER;
		if (lua_getfield(L, -1, "stage") != LUA_TNUMBER)
			luaL_error(L, "Need texture stage");
		a->u.t.stage = lua_tointeger(L, -1) & 0xff;
		if (lua_getfield(L, -2, "handle") != LUA_TNUMBER)
			luaL_error(L, "Need texture handle");
		a->u.t.handle = (uint32_t)lua_tointeger(L, -1);
		lua_pop(L, 2);
	} else {
		a->type = ATTRIB_UNIFORM;
		a->u.m = math3d_mark_id(L, mapi, -1);
	}
	lua_pop(L, 1);
	return a;
}

static inline uint16_t
attrib_id(struct attrib_arena *arena, struct attrib *a) {
	return (uint16_t)(a - arena->a);
}

// 1: material
static int
lmaterial_instance(lua_State *L) {
	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), 0);
	mi->patch_attrib = INVALID_ATTRIB;
	lua_getiuservalue(L, 1, 1);
	int n = (int)lua_rawlen(L, -1);	// free instance attrib
	if (n > 0) {
		lua_getfield(L, -1, "__gc");
		if (lua_getupvalue(L, -1, 3) == NULL)
			return luaL_error(L, "Invalid material metatable");
		struct attrib_arena * arena = lua_touserdata(L, -1);
		lua_pop(L, 2);
		clear_unused_attribs(L, arena, n);
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lmaterial_progid(lua_State *L){
	struct material* m = (struct material *)luaL_checkudata(L, 1, "ANT_MATERIAL");
	lua_pushinteger(L, m->prog.idx);
	return 1;
}

static struct attrib *
fetch_attrib(lua_State *L, struct material *mat, struct attrib_arena *arena, int n, int *num) {
	uint16_t attrib = mat->attrib;
	struct attrib * a = NULL;
	while (n-- >= 0) {
		if (attrib == INVALID_ATTRIB)
			luaL_error(L, "Invalid attrib");
		a = &arena->a[attrib];
		attrib = a->next;
	}
	int count = 1;
	bgfx_uniform_handle_t u = a->u.handle;
	struct attrib * ret = a;
	while (attrib != INVALID_ATTRIB) {
		a = &arena->a[attrib];
		if (BGFX_EQUAL(u, a->u.handle)) {
			++count;
			attrib = a->next;
		} else {
			break;
		}
	}
	*num = count;
	return ret;
}

static inline int
is_uniform_attrib(struct attrib *a){
	return a->type == ATTRIB_SAMPLER || a->type == ATTRIB_UNIFORM;
}

static uint16_t *
find_attrib_ref(struct material_instance *mi, struct attrib_arena *arena, struct attrib* a) {
	uint16_t *ret = &mi->patch_attrib;
	while (*ret != INVALID_ATTRIB) {
		struct attrib * ra = &arena->a[*ret];
		if (a == ra){
			return ret;
		}
		ret = &ra->next;
	}
	return NULL;
}

static void
unset_instance_attrib(struct material_instance *mi, struct attrib_arena *arena, struct attrib *a, int n) {
	uint16_t * ref = find_attrib_ref(mi, arena, a);
	if (ref == NULL)
		return;
	int i;
	uint16_t id = *ref;
	for (i=0;i<n;i++) {
		id = clear_attrib(arena, id);
	}
	*ref = id;
}

static void
set_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int index) {
	switch (a->type){
		case ATTRIB_UNIFORM:
			math3d_unmark_id(arena->math, a->u.m);
			a->u.m = math3d_mark_id(L, arena->math, index);
			break;
		case ATTRIB_SAMPLER:
			a->u.t.handle = (uint32_t)luaL_checkinteger(L, index);
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

			lua_getfield(L, index, "handle");
			a->r.handle = (uint32_t)luaL_checkinteger(L, -1);
			lua_pop(L, 1); // handle
		}
			break;
		default:
			luaL_error(L, "Invalid attribute type:%d", a->type);
			break;
	}
}

static void
replace_instance_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int value_index, int n) {
	if (n == 1) {
		set_attrib(L, arena, a, value_index);
	} else {
		int i;
		for (i=0;i<n;i++) {
			if (a == NULL)
				luaL_error(L, "Replace attrib error");
			lua_geti(L, value_index, i+1);
			set_attrib(L, arena, a, -1);
			lua_pop(L, 1);
			if (a->next == INVALID_ATTRIB)
				a = NULL;
			else
				a = &arena->a[a->next];
		}
	}
}

static struct attrib *
new_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, int cobject_index, struct attrib *a, int value_index) {
	struct attrib * new_attrib = arena_alloc(L, cobject_index);
	*new_attrib = *a;
	new_attrib->u.m = 0;	// unmark will ignore 0
	new_attrib->next = INVALID_ATTRIB;
	set_attrib(L, arena, new_attrib, value_index);
	return new_attrib;
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, struct attrib * a, int value_index, int n) {
	uint16_t * ref = find_attrib_ref(mi, arena, a);
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
				struct attrib * new_attrib = new_instance_attrib(L, mi, arena, lua_upvalueindex(3), a, -1);
				new_attrib->next = last_id;
				last_id = attrib_id(arena, new_attrib);
				lua_pop(L, 1);
				if (a->next == INVALID_ATTRIB)
					a = NULL;
				else
					a = &arena->a[a->next];
			}
			mi->patch_attrib = last_id;
		}
	} else {
		replace_instance_attrib(L, arena, &arena->a[*ref], value_index, n);
	}
}

// upvalue 1: material
// upvalue 2: lookup table
// upvalue 3: cobject
// 1: material_instance
// 2: uniform name
// 3: value
static int
lset_attrib(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
	struct material * mat = (struct material *)lua_touserdata(L, lua_upvalueindex(1));
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, lua_upvalueindex(3));
	lua_pushvalue(L, 2);
	if (lua_rawget(L, lua_upvalueindex(2)) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, 2, NULL));
	}
	int index = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	int n;
	struct attrib * a = fetch_attrib(L, mat, arena, index, &n);
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
	mat->prog.idx = UINT16_MAX;
	// material_metatable
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE) {
		return 0;
	}
	int free_instance = (int)lua_rawlen(L, -1);
	int instance_index = lua_gettop(L);
	if (lua_getfield(L, -1, "__gc") != LUA_TFUNCTION) {
		return 0;
	}
	lua_getupvalue(L, -1, 2);	// lookup table
	int n = (int)lua_rawlen(L, -1);
	if (mat->attrib != INVALID_ATTRIB) {
		lua_pushinteger(L, mat->attrib);
		lua_rawseti(L, -2, ++n);
		mat->attrib = INVALID_ATTRIB;
	}
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

static uint16_t
apply_attrib(lua_State *L, struct attrib_arena * cobject_, struct attrib *a, int texture_index) {
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
	struct attrib *next = &arena->a[a->next];
	if (a->next == INVALID_ATTRIB || !BGFX_EQUAL(next->u.handle, a->u.handle)) {
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
		next = &arena->a[a->next];
		++n;
	} while (a->next != INVALID_ATTRIB && BGFX_EQUAL(next->u.handle, a->u.handle));
	BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, buffer, n);
	return a->next;
}

static int
apply_material_attribs(lua_State *L, int cobject_index, int texture_index, uint16_t attrib_id, bgfx_uniform_handle_t u[]) {
	int n = 0;
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, cobject_index);
	while (attrib_id != INVALID_ATTRIB) {
		struct attrib *a = &arena->a[attrib_id];
		u[n] = a->u.handle;
		attrib_id = apply_attrib(L, arena, a, texture_index);
		++n;
	}
	return n;
}

static inline uint16_t
skip_attrib(struct attrib_arena *arena, struct attrib *a) {
	struct attrib *next = &arena->a[a->next];
	while (a->next != INVALID_ATTRIB && BGFX_EQUAL(next->u.handle, a->u.handle)) {
		a = next;
		next = &arena->a[a->next];
	}
	return a->next;
}

static int
collect_uniforms(lua_State *L, int cobject_index, uint16_t attrib_id, bgfx_uniform_handle_t u[]) {
	int n = 0;
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, cobject_index);
	while (attrib_id != INVALID_ATTRIB) {
		struct attrib *a = &arena->a[attrib_id];
		u[n] = a->u.handle;
		attrib_id = skip_attrib(arena, a);
		++n;
	}
	return n;
}

static void
apply_material_attribs_exclude(lua_State *L, int cobject_index, int texture_index, uint16_t attrib_id, const bgfx_uniform_handle_t u[]) {
	int n = 0;
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, cobject_index);
	while (attrib_id != INVALID_ATTRIB) {
		struct attrib *a = &arena->a[attrib_id];
		if (BGFX_EQUAL(a->u.handle, u[n])) {
			attrib_id = apply_attrib(L, arena, a, texture_index);
		} else {
			attrib_id = skip_attrib(arena, a);
		}
		++n;
	}
}

// 1: material_instance
// 2: texture lookup table
static int
lapply_attrib(lua_State *L) {
	struct material_instance *mi = (struct material_instance *)lua_touserdata(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	struct material *mat = (struct material *)lua_touserdata(L, lua_upvalueindex(1));
	int cobject_index =  lua_upvalueindex(3);
	CAPI_INIT(L, cobject_index);
	BGFX(encoder_set_state)(cobject_->eh->encoder, mat->state, mat->rgba);
	bgfx_uniform_handle_t mat_uniform[MAX_UNIFORM_NUM];
	if (mi->patch_attrib == INVALID_ATTRIB) {
		apply_material_attribs(L, cobject_index, 2, mat->attrib, mat_uniform);
	} else {
		bgfx_uniform_handle_t mi_uniform[MAX_UNIFORM_NUM];
		int n = apply_material_attribs(L, cobject_index, 2, mi->patch_attrib, mi_uniform);
		int mat_n = collect_uniforms(L, cobject_index, mat->attrib, mat_uniform);
		if (n >= mat_n)
			return 0;
		// unmark uniforms applied
		int i,j;
		for (i=0;i<mat_n && n>0;i++) {
			bgfx_uniform_handle_t uni = mat_uniform[i];
			for (j=0;j<n;j++) {
				if (BGFX_EQUAL(mi_uniform[j], uni)) {
					mat_uniform[i].idx = UINT16_MAX;
					mi_uniform[j] = mi_uniform[--n];
					break;
				}
			}
		}
		apply_material_attribs_exclude(L, cobject_index, 2, mat->attrib, mat_uniform);
	}

	return 0;
}

static int
lget_attrib(lua_State *L){
	const char* key = luaL_checkstring(L, 2);
	if (strcmp(key, "prog") == 0){
		struct material *mat = (struct material *)lua_touserdata(L, lua_upvalueindex(1));
		lua_pushinteger(L, BGFX_LUAHANDLE(PROGRAM, mat->prog));
		return 1;
	}



	return luaL_error(L, "invalid key:%s", key);
}

// 1: material
// 2: lookup table
// 3: cobject
static void
gen_material_metatable(lua_State *L) {
	luaL_Reg l[] = {
		{ "__newindex", lset_attrib		},
		{ "__gc", 		lcollect_attrib	},
		{ "__call", 	lapply_attrib	},
		{ "__index",	lget_attrib		},
		{ NULL, NULL },
	};
	luaL_newlibtable(L, l);
	lua_insert(L, -4);
	luaL_setfuncs(L, l, 3);
}

// 1: program
// 2: render state (string)
// 3: uniforms (table:optional)

#define MATERIAL_NEW_PROGRAM 1
#define MATERIAL_NEW_STATE 2
#define MATERIAL_NEW_UNIFORM 3
#define MATERIAL_NEW_COBJECT 4
static int
lmaterial_new(lua_State *L) {
	struct program *p = (struct program *)luaL_checkudata(L, 1, "ANT_PROGRAM");
	uint64_t state;
	uint32_t rgba;
	get_state(L, MATERIAL_NEW_STATE, &state, &rgba);
	lua_settop(L, 3);
	lua_getiuservalue(L, MATERIAL_NEW_PROGRAM, 2);	// get CAPI from program(1)
	CAPI_INIT(L, MATERIAL_NEW_COBJECT);
	struct math3d_api *mapi = CAPI_MATH3D;
	struct attrib_arena * arena = CAPI_ARENA;
	struct material *mat = (struct material *)lua_newuserdatauv(L, sizeof(*mat), 2);
	lua_pushvalue(L, -1);	// material
	// copy lookup table from program(1) to uservalue 1
	lua_getiuservalue(L, 1, 1);
	// free attribs
	int n = (int)lua_rawlen(L, -1);
	if (n > 0) {
		clear_unused_attribs(L, arena, n);
	}
	lua_pushvalue(L, MATERIAL_NEW_COBJECT);	// cobject
	gen_material_metatable(L);
	lua_setiuservalue(L, -2, 1);
	lua_pushvalue(L, MATERIAL_NEW_COBJECT);
	lua_setiuservalue(L, -2, 2);
	mat->state = state;
	mat->rgba = rgba;
	mat->prog = p->prog;
	mat->attrib = INVALID_ATTRIB;
	uint16_t *pattrib = &mat->attrib;
	if (p->n_uniform > 0) {
		luaL_checktype(L, MATERIAL_NEW_UNIFORM, LUA_TTABLE);
		int i,j;
		for (i=0;i<p->n_uniform;i++) {
			bgfx_uniform_info_t info;
			BGFX(get_uniform_info)(p->u[i], &info);
			int t = lua_getfield(L, MATERIAL_NEW_UNIFORM, info.name);
			if (t == LUA_TNIL) {
				return luaL_error(L, "Missing uniform %s", info.name);
			}
			if (info.num == 1) {
				struct attrib * a = gen_uniform_attrib(L, MATERIAL_NEW_COBJECT, &info, p->u[i], t, mapi);
				*pattrib = attrib_id(arena, a);
				pattrib = &a->next;
			} else {
				if (t != LUA_TTABLE) {
					return luaL_error(L, "%s is a multiple uniform (%d), Need a table", info.name, info.num);
				}
				for (j=0;j<info.num;j++) {
					t = lua_geti(L, -1, j+1);
					struct attrib * a = gen_uniform_attrib(L, MATERIAL_NEW_COBJECT, &info, p->u[i], t, mapi);
					*pattrib = attrib_id(arena, a);
					pattrib = &a->next;
				}
				lua_pop(L, 1);
			}
		}
	}

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

static bgfx_uniform_handle_t*
find_valid_uniform(lua_State *L, struct attrib_arena * cobject_, bgfx_shader_handle_t h0, bgfx_shader_handle_t h1, int *count){
#define MAX_UNIFORM_NAME_COUNT 256
	static bgfx_uniform_handle_t s_uniforms[MAX_UNIFORM_NAME_COUNT] = {BGFX_INVALID_HANDLE};

	int n = BGFX(get_shader_uniforms)(h0, s_uniforms, MAX_UNIFORM_NAME_COUNT);
	if (!BGFX_INVALID(h1)) {
		n += BGFX(get_shader_uniforms)(h1, s_uniforms + n, MAX_UNIFORM_NAME_COUNT - n);
	}

	if (n > MAX_UNIFORM_NAME_COUNT){
		luaL_error(L, "Too many uniform in vs and fs, max uniform count is: %d", MAX_UNIFORM_NAME_COUNT);
	}

	lua_newtable(L);

	for (int ii=0; ii<n; ++ii){
		bgfx_uniform_info_t info;
		BGFX(get_uniform_info)(s_uniforms[ii], &info);
		lua_pushinteger(L, s_uniforms[ii].idx);
		lua_setfield(L, -2, info.name);
	}

	for (lua_pushnil(L); lua_next(L, -2) != 0; lua_pop(L, 1)) {
		s_uniforms[(*count)++].idx = (uint16_t)lua_tointeger(L, -1);
	}

	lua_remove(L, -1);	// remove this hash table
	return s_uniforms;

#undef MAX_UNIFORM_NAME_COUNT
}

// 1 : cobject
// 2 : bgfx_shader_handle_t vs
// 3 : bgfx_shader_handle_t fs (optional)
static int
lprogram_new(lua_State *L) {
	CAPI_INIT(L, 1);
	const int vs = (int)luaL_checkinteger(L, 2);
	const int iscompute = lua_isnoneornil(L, 4) ? 0 : lua_toboolean(L, 4);
	const int fs = iscompute ? UINT16_MAX : (int)luaL_optinteger(L, 3, 0xffff);
	const bgfx_shader_handle_t vsh = { vs & 0xffff };
	const bgfx_shader_handle_t fsh = { fs & 0xffff };

	int n = 0;
	bgfx_uniform_handle_t *uniforms = find_valid_uniform(L, cobject_, vsh, fsh, &n);
	struct program * p = (struct program *)lua_newuserdatauv(L, sizeof(struct program) + (n-1) * sizeof(bgfx_uniform_handle_t), 2);
	memcpy(p->u, uniforms, sizeof(bgfx_uniform_handle_t)*n);
	p->n_uniform = n;

	p->prog = iscompute ? BGFX(create_compute_program)(vsh, false) : BGFX(create_program)(vsh, fsh, false);
	if (BGFX_INVALID(p->prog))
		return luaL_error(L, "Create Program fail");

	remove_duplicate_uniform(p, p->n_uniform);
	if (luaL_newmetatable(L, "ANT_PROGRAM")) {
		luaL_Reg l[] = {
//			{ "__gc", lprogram_delete },
			{ "release", lprogram_delete },
			{ "collect", lprogram_collect },
			{ "info", lprogram_info },
			{ "material", lmaterial_new },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	gen_lookuptable(L, p);
	lua_setiuservalue(L, -2, 1);
	lua_pushvalue(L, 1);
	lua_setiuservalue(L, -2, 2);
	return 1;
}

static int
lattribs_new(lua_State *L) {
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

LUAMOD_API int
luaopen_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "program", lprogram_new },
		{ "cobject", lattribs_new },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

