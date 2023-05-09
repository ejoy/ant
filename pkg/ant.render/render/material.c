#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <luabgfx.h>

#include "ecs/world.h"
#include "textureman.h"

#include "vla.h"

static int s_key;
#define ATTRIB_ARENA (void*)(&s_key)

#ifdef _DEBUG
#define verfiy(_CON)	assert(_CON)
#else //!_DEBUG
#define verfiy(_CON)	_CON
#endif //_DEBUG


#define INVALID_ATTRIB	0xffff
//#define INVALID_ATTRIB	0x0001ffff
#define MAX_ATTRIB_CAPS	INVALID_ATTRIB
#define DEFAULT_ARENA_SIZE 256

#define MAX_ATTRIB_NUM 256

enum ATTIRB_TYPE {
	ATTRIB_UNIFORM= 0,
	ATTRIB_SAMPLER,
	ATTRIB_IMAGE,
	ATTRIB_BUFFER,
	ATTRIB_REF,
	ATTRIB_COLOR_PAL,
	ATTRIB_NONE,
};

// #define CAPI_INIT(L, idx) struct attrib_arena * cobject_ = get_cobject(L, idx);
// #define CAPI_ARENA cobject_
// #define CAPI_MATH3D cobject_->math
#define BGFX(api) w->bgfx->api
#define BGFX_INVALID(h) (h.idx == UINT16_MAX)
#define BGFX_EQUAL(a,b) (a.idx == b.idx)

typedef uint16_t attrib_id;

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

#define ATTRIB_HEARDER uint16_t type;\
	attrib_id next;\
	attrib_id patch;

struct attrib_header {
	ATTRIB_HEARDER
};

struct attrib_uniform {
	ATTRIB_HEARDER
	bgfx_uniform_handle_t handle;
	union {
		math_t m;
		struct {
			uint32_t handle;
			uint8_t stage;
		} t;
		struct {
			uint8_t pal;
			uint8_t	color;
		}cp;
	};
};

struct attrib_resource {
	ATTRIB_HEARDER
	uint8_t stage;
	uint8_t access;
	uint8_t mip;
	uint32_t handle;
};

struct attrib_ref {
	ATTRIB_HEARDER
	attrib_id id;
};

typedef union
{
	struct attrib_header	h;
	struct attrib_uniform	u;
	struct attrib_resource	r;
	struct attrib_ref		ref;
}	attrib_type;

#define MAX_COLOR_PALETTE_COUNT		8
#define MAX_COLOR_IN_PALETTE		256
struct color{
	float rgba[4];
};

struct color_palette{
	struct color colors[MAX_COLOR_IN_PALETTE];
};

#define ARENA_UV_ATTRIB_BUFFER		1
#define ARENA_UV_SYSTEM_ATTRIBS		2
#define ARENA_UV_INVALID_LIST		3
#define ARENA_UV_NUM				3
// uv1: attrib buffer
// uv2: system attribs
// uv3: material invalid attrib list
struct attrib_arena {
	uint16_t cap;
	uint16_t n;
	attrib_id freelist;
	uint16_t cp_idx;
	attrib_type *a;
	struct color_palette color_palettes[MAX_COLOR_PALETTE_COUNT];
};

#define MATERIAL_UV_ARENA			1
#define MATERIAL_UV_LUT				2
#define MATERIAL_UV_INVALID_LIST	3
#define MATERIAL_UV_NUM				3

//uv1: arena
//uv2: lookup table, [name: id]
//uv3: invalid list handle
struct material_state {
	uint64_t state;
	uint64_t stencil;
	uint32_t rgba;
};

struct material {
	struct material_state state;
	attrib_id attrib;
	bgfx_program_handle_t prog;
};

#define INSTANCE_UV_INVALID_LIST	1
#define INSTANCE_UV_MATERIAL		2
#define INSTANCE_UV_NUM				2

struct material_instance {
	struct material *m;
	struct material_state patch_state;
	attrib_id patch_attrib;
};

static inline void
check_ecs_world_in_upvalue1(lua_State *L){
	luaL_checkstring(L, lua_upvalueindex(1));
}

static struct attrib_arena*
arena_new(lua_State *L) {
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), ARENA_UV_NUM);
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
	a->cp_idx = 0;
	memset(&a->color_palettes, 0, sizeof(a->color_palettes));
	//invalid material attrib list
	vla_lua_new(L, 0, sizeof(attrib_id));
	verfiy(lua_setiuservalue(L, -2, ARENA_UV_INVALID_LIST));	//set invalid table as uv 3
	lua_rawsetp(L, LUA_REGISTRYINDEX, ATTRIB_ARENA);
	return a;
}

//attrib list: al_*///////////////////////////////////////////////////////////
static inline void
al_init_attrib(struct attrib_arena* arena, attrib_type *a){
	(void)arena;

	a->h.type = ATTRIB_NONE;
	a->h.next = INVALID_ATTRIB;
	a->h.patch = INVALID_ATTRIB;
	a->u.handle.idx = UINT16_MAX;
	a->u.m 	= MATH_NULL;
}

static inline attrib_type*
al_attrib(struct attrib_arena *arena, attrib_id id){
	assert(arena->cap > id);
	return arena->a + id;
}

static inline attrib_id
al_attrib_id(struct attrib_arena *arena, attrib_type *a) {
	return (attrib_id)(a - arena->a);
}

static inline attrib_type*
al_next_attrib(struct attrib_arena *arena, attrib_type* a){
	return a->h.next == INVALID_ATTRIB ? NULL : al_attrib(arena, a->h.next);
}

static inline int
is_uniform_attrib(uint16_t type){
	return type == ATTRIB_UNIFORM || type == ATTRIB_SAMPLER || type == ATTRIB_COLOR_PAL;
}

static inline int
al_attrib_is_uniform(struct attrib_arena* arena, attrib_type *a){
	(void)arena;
	return is_uniform_attrib(a->h.type);
}

static inline int
al_attrib_uniform_handle_equal(struct attrib_arena* arena, attrib_type *a1, attrib_type *a2){
	assert(al_attrib_is_uniform(arena, a1) && al_attrib_is_uniform(arena, a2));
	return BGFX_EQUAL(a1->u.handle, a2->u.handle);
}

static inline attrib_id
al_attrib_next_uniform_id(struct attrib_arena* arena, attrib_id id, uint32_t *count){
	assert(id != INVALID_ATTRIB);
	
	attrib_type* a = al_attrib(arena, id);
	attrib_id c = 1;
	if (a->h.type == ATTRIB_UNIFORM){
		while (a->h.next != INVALID_ATTRIB){
			attrib_type* na = al_attrib(arena, a->h.next);
			if (na->h.type != ATTRIB_UNIFORM ||
				!al_attrib_uniform_handle_equal(arena, a, na))
				break;
			++c;
			a = na;
		}
	}

	if (count)
		*count = c;
	return a->h.next;
}

static inline uint32_t
al_attrib_num(struct attrib_arena* arena, attrib_type *a){
	uint32_t c = 0;
	al_attrib_next_uniform_id(arena, al_attrib_id(arena, a), &c);
	return c;
}

static inline void
al_attrib_return(struct attrib_arena * arena, attrib_type *a) {
	attrib_id id = al_attrib_id(arena, a);
	a->h.next = arena->freelist;
	arena->freelist = id;
}

static inline attrib_id
al_attrib_clear(struct attrib_arena * arena, struct ecs_world *w, attrib_id id) {
	attrib_type *a = al_attrib(arena, id);
	if (a->h.type == ATTRIB_UNIFORM) {
		math_unmark(w->math3d->M, a->u.m);
		a->u.m = MATH_NULL;
	}
	id = a->h.next;
	al_attrib_return(arena, a);
	return id;
}

//material instance: mi_*////////////////////////////////////////////////////////////////////////////
static inline attrib_id
mi_find_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, attrib_id id){
	assert(id != INVALID_ATTRIB);
	for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
		attrib_type *pa = al_attrib(arena, pid);
		if (pa->h.patch == id)
			return pid;
	}

	return INVALID_ATTRIB;
}

/////////////////////////////////////////////////////////////////////////////
static inline struct attrib_arena*
to_arena(lua_State *L, int idx){
	struct attrib_arena *api = (struct attrib_arena *)lua_touserdata(L, idx);
	if (api == NULL)
		luaL_error(L, "Invalid C API");
	return api;
}

static inline int
check_push_arena(lua_State *L){
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, ATTRIB_ARENA) != LUA_TUSERDATA){
		luaL_error(L, "Not found C API in reg table");
	}
	return lua_absindex(L, -1);
}

static inline void
pop_arena(lua_State*L){
	lua_pop(L, 1);
}

static inline int
push_arena_uv(lua_State *L, int uvidx){
	const int arenaidx = check_push_arena(L);
	//system attrib table
	if (lua_getiuservalue(L, arenaidx, uvidx) != LUA_TTABLE){
		luaL_error(L, "Invalid system atrrib table");
	}

	lua_insert(L, -2);	//swap with arena
	pop_arena(L);
	return lua_absindex(L, -1);	// -1 is 'uvidx' object in stack
}

static inline struct attrib_arena*
arena_from_reg(lua_State *L){
	const int arenaidx = check_push_arena(L);
	struct attrib_arena *arena = to_arena(L, arenaidx);
	pop_arena(L);
	return arena;
}

attrib_type *
arena_alloc(lua_State *L) {
	const int arenaidx = check_push_arena(L);
	struct attrib_arena * arena = to_arena(L, arenaidx);
	attrib_type *ret;
	if (arena->freelist != INVALID_ATTRIB) {
		ret = al_attrib(arena, arena->freelist);
		arena->freelist = ret->h.next;
	} else if (arena->n < arena->cap) {
		ret = al_attrib(arena, arena->n);
		arena->n++;
	} else if (arena->cap == 0) {
		// new arena
		attrib_type * al = (attrib_type *)lua_newuserdatauv(L, sizeof(attrib_type) * DEFAULT_ARENA_SIZE, 0);
		verfiy(lua_setiuservalue(L, arenaidx, ARENA_UV_ATTRIB_BUFFER));
		arena->a = al;
		arena->cap = DEFAULT_ARENA_SIZE;
		arena->n = 1;
		ret = arena->a;
	} else {
		// resize arena
		int newcap = arena->cap * 2;
		if (newcap > MAX_ATTRIB_CAPS)
			luaL_error(L, "Too many attribs");
		attrib_type * al = (attrib_type *)lua_newuserdatauv(L, sizeof(attrib_type) * newcap, 0);
		memcpy(al, arena->a, sizeof(attrib_type) * arena->n);
		arena->a = al;
		arena->cap = newcap;
		verfiy(lua_setiuservalue(L, arenaidx, ARENA_UV_ATTRIB_BUFFER));
		ret = al_attrib(arena, arena->n++);
	}
	pop_arena(L);
	al_init_attrib(arena, ret);
	return ret;
}

static void
clear_unused_attribs(lua_State *L, struct attrib_arena *arena, vla_handle_t hlist) {
	vla_using(list, attrib_id, hlist, L);
	const int n = vla_size(list);
	struct ecs_world * w = getworld(L);
	for (int i=0;i<n;++i) {
		attrib_id id = list[i];
		do {
			id = al_attrib_clear(arena, w, id);
		} while (id != INVALID_ATTRIB);
	}
}

static void
uniform_value(lua_State *L, attrib_type *a) {
	switch (a->h.type){
		case ATTRIB_UNIFORM:
			lua_pushlightuserdata(L, (void*)a->u.m.idx);
			break;
		case ATTRIB_SAMPLER:
			lua_pushfstring(L, "s%d:%d", a->u.t.stage, a->u.t.handle);
			break;
		case ATTRIB_COLOR_PAL:
			lua_pushfstring(L, "c%d:%d", a->u.cp.pal, a->u.cp.color);
			break;
		default:
			luaL_error(L, "Invalid uniform attribute type:%d, image|buffer is not uniform attrib", a->h.type);
			break;
	}
}

static inline void
push_attrib_value(lua_State *L, struct attrib_arena *arena, struct ecs_world* w, attrib_id id){
	attrib_type * a = al_attrib(arena, id);
	switch(a->h.type){
		case ATTRIB_UNIFORM:
		case ATTRIB_SAMPLER:
		case ATTRIB_COLOR_PAL:{
			uint32_t num = al_attrib_num(arena, a);
			bgfx_uniform_info_t info;
			BGFX(get_uniform_info)(a->u.handle, &info);
			lua_createtable(L, 0, 0);
			lua_pushstring(L, info.name);
			lua_setfield(L, -2, "name");
			if (num == 1) {
				uniform_value(L, a);
			} else {
				lua_createtable(L, info.num, 0);
				int i;
				for (i=0;i<info.num;i++) {
					if (a == NULL)
						luaL_error(L, "Invalid multiple uniform");
					uniform_value(L, a);
					lua_rawseti(L, -2, i+1);
					a = al_next_attrib(arena, a);
				}
			}

			lua_setfield(L, -2, "value");
		}
		break;
		case ATTRIB_IMAGE:
			lua_pushfstring(L, "i%d:%d:%d:%d", a->r.stage, a->r.handle, a->r.mip, a->r.access);
			break;
		case ATTRIB_BUFFER:
			lua_pushfstring(L, "b%d:%d:%d", a->r.stage, a->r.handle, a->r.access);
			break;
		case ATTRIB_REF:
			lua_pushfstring(L, "r%d", a->ref);
			break;
		default:
			luaL_error(L, "Invalid Attrib type");
			break;
	}
}

static inline struct material*
check_material_index(lua_State *L, int mat_idx){
	void* m = luaL_testudata(L, mat_idx, "ANT_MATERIAL");
	if (m == NULL){
		m = luaL_testudata(L, mat_idx, "ANT_MATERIAL_TYPE");
		if (m == NULL){
			luaL_error(L, "Invalid material");
		}
	}
	return (struct material*)m;
}

// 1: material
static int
lmaterial_attribs(lua_State *L) {
	struct material* mat = check_material_index(L, 1);
	lua_settop(L, 1);
	if (LUA_TUSERDATA != lua_getiuservalue(L, 1, MATERIAL_UV_ARENA)){
		return luaL_error(L, "Invalid material, uservalue in 2 is not 'attrib_arena'");
	}
	struct attrib_arena *arena = to_arena(L, -1);
	lua_newtable(L);
	int result_index = lua_gettop(L);

	struct ecs_world* w = getworld(L);
	int idx = 1;
	for (attrib_id id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)) {
		push_attrib_value(L, arena, w, id);
		lua_seti(L, result_index, idx++);
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
byte2hex(uint8_t c, uint8_t *t) {
	static char *hex = "0123456789ABCDEF";
	t[0] = hex[c>>4];
	t[1] = hex[c&0xf];
}

static inline void
fetch_material_state(lua_State *L, int idx, struct material_state *ms) {
	// compute shader
	if (lua_isnoneornil(L, idx)){
		ms->state = 0;
		ms->rgba = 0;
		return;
	}
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
	ms->state = state;
	ms->rgba = rgba;
}

static inline void
fetch_material_stencil(lua_State *L, int idx, struct material_state *ms){
	// compute shader
	if (lua_isnoneornil(L, idx)){
		ms->stencil = 0;
		return;
	}

	size_t sz;
	const uint8_t * data = (const uint8_t *)luaL_checklstring(L, idx, &sz);
	if (sz != 16){
		luaL_error(L, "Invalid stencil length %d", sz);
	}

	ms->stencil = 0;
	for (int i=0;i<15;i++) {
		ms->stencil |= hex2n(L,data[i]);
		ms->stencil <<= 4;
	}
	ms->stencil |= hex2n(L,data[15]);
}

static inline vla_handle_t
to_vla_handle(lua_State *L, int idx){
	vla_handle_t hlist;
	hlist.l = (struct vla_lua*)lua_touserdata(L, -1);
	return hlist;
}

static void
unset_instance_attrib(lua_State* L, struct material_instance *mi, struct attrib_arena *arena, attrib_type *a) {
	attrib_id ref = mi_find_patch_attrib(arena, mi, al_attrib_id(arena, a));
	struct ecs_world* w = getworld(L);
	if (ref != INVALID_ATTRIB){
		const int num = al_attrib_num(arena, a);
		attrib_id id = ref;
		for (int i=0;i<num;i++) {
			id = al_attrib_clear(arena, w, id);
		}
	}
}

static inline uint8_t
fetch_attrib_type(lua_State *L, int index){
	const int tt = lua_type(L, index);
	// math3d value
	if (tt == LUA_TLIGHTUSERDATA || tt == LUA_TUSERDATA){
		return ATTRIB_UNIFORM;
	}

	if (tt != LUA_TTABLE){
		luaL_error(L, "Invalid value type:%s, should be math3d value or table like: {type='u', value=xxx, handle=xxx}", lua_typename(L, tt));
		return ATTRIB_NONE;
	}
	const int lt = lua_getfield(L, index, "type");
	if (lt == LUA_TNIL){
		lua_pop(L, 1);
		if (lua_rawlen(L, index) > 0){
			return ATTRIB_UNIFORM;
		}
	}
	if (lt != LUA_TSTRING){
		lua_pop(L, 1);
		luaL_error(L, "Invalid attrib value, 'type' filed:%s, is not string", lua_typename(L, lt));
		return ATTRIB_NONE;
	}
	const char  c = lua_tostring(L, -1)[0];
	lua_pop(L, 1);

	switch (c){
		case 't': return ATTRIB_SAMPLER;
		case 'i': return ATTRIB_IMAGE;
		case 'b': return ATTRIB_BUFFER;
		case 'p': return ATTRIB_COLOR_PAL;
		case 'u':
		// could not be ATTRIB_REF
		default: return ATTRIB_UNIFORM;
	}
}


static inline bgfx_uniform_handle_t
fetch_handle(lua_State *L, int index){
	const int htype = lua_getfield(L, index, "handle");
	bgfx_uniform_handle_t h = BGFX_INVALID_HANDLE;
	if (htype != LUA_TNIL){
		if (htype == LUA_TNUMBER){
			h.idx = (uint16_t)lua_tonumber(L, -1);
		} else {
			luaL_error(L, "Uniform attrib 'handle' must be number:%s", lua_typename(L, htype));
		}
	}
	lua_pop(L, 1);
	return h;
}

static inline uint8_t
fetch_stage(lua_State *L, int index){
	if (LUA_TNUMBER != lua_getfield(L, index, "stage")){
		luaL_error(L, "Invalid sampler 'stage' field, number is needed");
	}
	uint8_t stage = (uint8_t)lua_tointeger(L, -1);
	lua_pop(L, 1);	// stage
	return stage;
}

static inline uint32_t
fetch_value_handle(lua_State *L, int index){
	lua_getfield(L, index, "value");
	uint32_t h = (uint32_t)luaL_optinteger(L, -1, UINT16_MAX);
	lua_pop(L, 1);
	return h;
}

static inline uint8_t
fetch_mip(lua_State *L, int index){
	if (LUA_TNUMBER != lua_getfield(L, index, "mip")){
		luaL_error(L, "Invalid image 'mip' field, number is need");
	}
	const uint8_t mip = (uint8_t)lua_tointeger(L, -1);
	lua_pop(L, 1);
	return mip;
}

static inline uint8_t
fetch_access(lua_State *L, int index){
	if (LUA_TSTRING != lua_getfield(L, index, "access")){
		luaL_error(L, "Invalid image/buffer 'access' field, r/w/rw is required");
	}
	const char* s = lua_tostring(L, -1);
	uint8_t access = 0;
	if (strcmp(s, "w") == 0){
		access = BGFX_ACCESS_WRITE;
	} else if (strcmp(s, "r") == 0){
		access = BGFX_ACCESS_READ;
	} else if (strcmp(s, "rw") == 0){
		access = BGFX_ACCESS_READWRITE;
	} else {
		luaL_error(L, "Invalid access type:%s", s);
	}
	lua_pop(L, 1);	// access
	return access;
}

static inline void
fetch_math_value_(lua_State *L, attrib_type* a, int index){
	struct ecs_world* w = getworld(L);
	math_unmark(w->math3d->M, a->u.m);
	math_t id = math3d_from_lua_id(L, w->math3d, index);
	a->u.m = math_mark(w->math3d->M, id);
}

static inline void
fetch_math_value(lua_State *L, attrib_type* a, int index){
	const int datatype = lua_type(L, index);
	if (datatype == LUA_TTABLE){
		const int lt = lua_getfield(L, index, "value");
		if (lt != LUA_TLIGHTUSERDATA && lt != LUA_TUSERDATA){
			luaL_error(L, "Invalid math uniform 'value' field, math3d value is required");
		}
		fetch_math_value_(L, a, -1);
		lua_pop(L, 1);
	} else if (datatype == LUA_TLIGHTUSERDATA || datatype == LUA_TUSERDATA){
		fetch_math_value_(L, a, index);
	} else {
		luaL_error(L, "Invalid data for 'uniform' value, type:%s, should be table with 'value' field, or math3d value", lua_typename(L, datatype));
	}
}

static inline void
fetch_sampler(lua_State *L, attrib_type* a, int index){
	const int lt = lua_type(L, index);
	if (lt == LUA_TTABLE){
		a->u.t.stage	= fetch_stage(L, index);
		a->u.t.handle	= fetch_value_handle(L, index);
	} else if (lt == LUA_TNUMBER) {
		a->u.t.handle = (uint32_t)luaL_checkinteger(L, index);
	} else {
		luaL_error(L, "Invalid type for 'texture':%s, bgfx texture handle or table:{stage=0, value=bgfxhandle}", lua_typename(L, lt));
	}
}

static inline void
fetch_image(lua_State *L, attrib_type* a, int index){
	const int lt = lua_type(L, index);
	if (lt == LUA_TTABLE){
		a->r.mip	= fetch_mip(L, index);
		a->r.access	= fetch_access(L, index);
		a->r.stage	= fetch_stage(L, index);
		a->r.handle = fetch_value_handle(L, index);
	} else if (lt == LUA_TNUMBER){
		a->r.handle = (uint32_t)luaL_checkinteger(L, index);
	} else {
		luaL_error(L, "Invalid type for 'image':%s, bgfx texture handle or table:{stage=0, value=bgfxhandle, mip=0, access='r'}", lua_typename(L, lt));
	}

}

static inline void
fetch_buffer(lua_State *L, attrib_type* a, int index){
	const int lt = lua_type(L, index);
	if (lt == LUA_TTABLE){
		a->r.access	= fetch_access(L, index);
		a->r.stage	= fetch_stage(L, index);
		a->r.handle = fetch_value_handle(L, index);
	} else if (lt == LUA_TNUMBER){
		a->r.handle = (uint32_t)luaL_checkinteger(L, index);
	} else {
		luaL_error(L, "Invalid type for 'image':%s, bgfx buffer(dynamic/static) handle or table:{stage=0, value=bufferhandle, access='r'}", lua_typename(L, lt));
	}
}

static inline void
fetch_color_pal(lua_State *L, attrib_type *a, int index){
	luaL_checktype(L, index, LUA_TTABLE);
	if (LUA_TTABLE != lua_getfield(L, index, "value")){
		luaL_error(L, "Invalid color palette value, shoule be table");
	} {
		if (LUA_TNUMBER != lua_getfield(L, index, "pal")){
			luaL_error(L, "Invalid color palette id value, should be color palette id");
		}
		const int pal = (int)lua_tointeger(L, -1);
		if (pal < 0 || pal >= MAX_COLOR_PALETTE_COUNT){
			luaL_error(L, "Invalid color palette id");
		}
		a->u.cp.pal = (uint8_t)pal;
		lua_pop(L, 1);
		
		if (LUA_TNUMBER != lua_getfield(L, index, "color")){
			luaL_error(L, "Invalid color index value, shoule be color index");
		}
		const int coloridx = (int)lua_tointeger(L, -1);
		if (coloridx < 0 || coloridx >= MAX_COLOR_IN_PALETTE){
			luaL_error(L, "Invalid color index");
		}
		a->u.cp.color = (uint8_t)coloridx;
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
}

static void
fetch_attrib(lua_State *L, attrib_type *a, int index) {
	switch (a->h.type){
		case ATTRIB_UNIFORM:	fetch_math_value(L, a, index);						break;
		case ATTRIB_SAMPLER:	fetch_sampler(L, a, index);							break;
		case ATTRIB_IMAGE:		fetch_image(L, a, index);							break;
		case ATTRIB_BUFFER:		fetch_buffer(L, a, index);							break;
		case ATTRIB_COLOR_PAL:	fetch_color_pal(L, a, index);				break;
		default: luaL_error(L, "Attribute type:%d, could not update", a->h.type);	break;
	}
}

static inline attrib_id
create_attrib(lua_State *L, struct attrib_arena* arena, int n, attrib_id id, uint16_t attribtype, bgfx_uniform_handle_t h){
	for (int i=0; i<n; ++i){
		attrib_type* na = arena_alloc(L);
		na->h.type = attribtype;
		na->h.next = id;
		if (is_uniform_attrib(attribtype)){
			na->u.handle = h;
		}
		id = al_attrib_id(arena, na);
	}
	return id;
}

static inline int
begin_fetch_attrib_array(lua_State *L, int data_idx, int* didx){
	const int lt = lua_getfield(L, data_idx, "value");
	if (lt == LUA_TNIL){
		*didx = data_idx;
		lua_pop(L, 1);
	} else {
		assert(lt == LUA_TTABLE);
		*didx = -1;
	}

	return lt;
}

static inline void
end_fetch_attrib_array(lua_State *L, int ltype){
	if (ltype != LUA_TNIL){
		lua_pop(L, 1);
	}
}

static void
update_attrib(lua_State *L, struct attrib_arena *arena, attrib_type *a, int data_idx) {
	const uint32_t n = al_attrib_num(arena, a);
	if (n == 1) {
		fetch_attrib(L, a, data_idx);
	} else {
		int didx;
		const int lt = begin_fetch_attrib_array(L, data_idx, &didx);
		for (uint32_t i=0;i<n;i++) {
			assert(a && "Invalid attrib");
			lua_geti(L, didx, i+1);
			fetch_attrib(L, a, -1);
			lua_pop(L, 1);
			a = al_next_attrib(arena, a);
		}
		end_fetch_attrib_array(L, lt);
	}
}

static inline uint16_t
count_data_num(lua_State *L, int data_index, uint16_t type){
	uint16_t n = 1;
	if (type == ATTRIB_UNIFORM){
		if (LUA_TTABLE == lua_type(L, data_index)){
			const int nn = (int)lua_rawlen(L, data_index);
			if (nn > 0){
				n = nn;
			} else {
				if (LUA_TTABLE == lua_getfield(L, data_index, "value"))
					n = (uint16_t)lua_rawlen(L, -1);
				lua_pop(L, 1);
			}
			
		}
	}
	return n;
}

static attrib_id
load_attrib_from_data(lua_State *L, struct attrib_arena* arena, int data_index, attrib_id id) {
	const uint16_t type = fetch_attrib_type(L, data_index);
	const int n = count_data_num(L, data_index, type);
	const bgfx_uniform_handle_t h = {is_uniform_attrib(type) ? fetch_handle(L, data_index).idx : UINT16_MAX};
	attrib_id nid = create_attrib(L, arena, n, id, type, h);
	update_attrib(L, arena, al_attrib(arena, nid), data_index);
	return nid;
}

static int
lmaterial_set_attrib(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	struct attrib_arena* arena = arena_from_reg(L);
	
	if (LUA_TTABLE != lua_getiuservalue(L, 1, MATERIAL_UV_LUT)) {	// get material lookup table
		return luaL_error(L, "Invalid material object, not found lookup table in uservalue 3");
	}
	const int lut_idx = lua_gettop(L);

	const char* attribname = luaL_checkstring(L, 2);

	if (LUA_TNIL == lua_getfield(L, lut_idx, attribname)){
		mat->attrib = load_attrib_from_data(L, arena, 3, mat->attrib);
		lua_pushinteger(L, mat->attrib);
		lua_setfield(L, lut_idx, attribname);
	} else {
		const attrib_id id = (attrib_id)lua_tointeger(L, -1);
		update_attrib(L, arena, al_attrib(arena, id), 3);
	}
	lua_pop(L, 1);
	return 0;
}

static inline int 
push_material_state(lua_State *L, uint64_t state, uint32_t rgba){
	uint8_t temp[24];
	int i;
	int count = 16;
	for (i=0;i<8;i++) {
		byte2hex((state >> ((7-i) * 8)) & 0xff, &temp[i*2]);
	}
	if (rgba) {
		for (i=0;i<4;i++) {
			byte2hex( (rgba >> ((3-i) * 8)) & 0xff, &temp[16+i*2]);
		}
		count += 8;
	}
	lua_pushlstring(L, (const char *)temp, count);
	return 1;
}

static inline int
push_material_stencil(lua_State *L, uint64_t stencil){
	uint8_t temp[16];
	for (int i=0;i<8;i++) {
		byte2hex((stencil >> ((7-i) * 8)) & 0xff, &temp[i*2]);
	}

	lua_pushlstring(L, (const char *)temp, 16);
	return 1;
}

static int
lmaterial_get_state(lua_State *L){
	struct material* mat = check_material_index(L, 1);
	return push_material_state(L, mat->state.state, mat->state.rgba);
}

static int
lmaterial_set_state(lua_State *L){
	//only ANT_MATERIAL can set
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	fetch_material_state(L, 2, &mat->state);
	return 0;
}

static int
lmaterial_get_stencil(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	push_material_stencil(L, mat->state.stencil);
	return 1;
}

static int
lmaterial_set_stencil(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	fetch_material_stencil(L, 2, &mat->state);
	return 0;
}


static inline int
check_uniform_num(struct attrib_arena *arena, struct ecs_world* w, attrib_type *a, int n){
	if (al_attrib_is_uniform(arena, a)){
		bgfx_uniform_info_t info;
		BGFX(get_uniform_info)(a->u.handle, &info);
		return (n == info.num);
	}
	return 1;
}

static inline void
init_instance_attrib(struct attrib_arena* arena, attrib_id pid, attrib_id id, int n){
	attrib_id nid = id;
	attrib_id npid = pid;
	for (int i=0; i<n; ++i){
		attrib_type* a = al_attrib(arena, nid);
		attrib_type* pa = al_attrib(arena, npid);
		pa->h.patch = nid;

		switch (pa->h.type){
			case ATTRIB_UNIFORM:
			case ATTRIB_COLOR_PAL:
				break;
			case ATTRIB_SAMPLER:
				pa->u.t.stage = a->u.t.stage;
				break;
			case ATTRIB_IMAGE:
				pa->r.mip = a->r.mip;
			// walk through
			case ATTRIB_BUFFER:
				pa->r.stage = a->r.stage;
				pa->r.access = a->r.access;
				break;
			case ATTRIB_REF:
				assert(false && "Invalid instance attrib to patch system attrib");
				break;
			default:
				assert(false && "");
				break;
		}

		nid = a->h.next;
		npid = pa->h.next;
	}
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, attrib_type * a, int value_index) {
	const attrib_id id = al_attrib_id(arena, a);
	attrib_id pid = mi_find_patch_attrib(arena, mi, id);
	if (pid == INVALID_ATTRIB) {
		const int n = al_attrib_num(arena, a);
		assert(check_uniform_num(arena, getworld(L), a, n));
		pid = create_attrib(L, arena, n, mi->patch_attrib, a->h.type, a->u.handle);
		init_instance_attrib(arena, pid, id, n);
		mi->patch_attrib = pid;
	}
	update_attrib(L, arena, al_attrib(arena, pid), value_index);
}

static inline attrib_id
lookup_material_attrib_id(lua_State *L, int mat_idx, int key_idx){
	check_material_index(L, mat_idx);
	if (LUA_TTABLE != lua_getiuservalue(L, mat_idx, MATERIAL_UV_LUT)){
		return luaL_error(L, "Invalid uservalue in function upvalue 1, need a lookup table in material uservalue 3");
	}
	lua_pushvalue(L, key_idx);	// push lookup key
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, key_idx, NULL));
	}
	const attrib_id id = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);	//lut
	return id;
}

static inline int
get_arena_index(lua_State *L, int mat_idx){
	check_material_index(L, mat_idx);
	if (LUA_TUSERDATA != lua_getiuservalue(L, mat_idx, MATERIAL_UV_ARENA)){
		luaL_error(L, "Invalid material in material instance");
	}

	return lua_absindex(L, -1);
}

static inline int
get_invalid_list_index(lua_State *L, int mat_idx){
	check_material_index(L, mat_idx);
	if (LUA_TUSERDATA != lua_getiuservalue(L, mat_idx, MATERIAL_UV_INVALID_LIST)){
		luaL_error(L, "Invalid material for invalid list handle");
	}
	return lua_absindex(L, -1);
}

static inline vla_handle_t
get_invalid_list_handle(lua_State *L, int mat_idx){
	vla_handle_t h = to_vla_handle(L, get_invalid_list_index(L, mat_idx));
	lua_pop(L, 1);
	return h;
}

static inline int
get_material_index(lua_State *L, int instance_idx){
	if (!luaL_testudata(L, instance_idx, "ANT_INSTANCE_MT")){
		luaL_error(L, "Invalid material instance");
	}
	if (LUA_TUSERDATA != lua_getiuservalue(L, instance_idx, INSTANCE_UV_MATERIAL)){
		luaL_error(L, "Invalid material instance for material index");
	}
	return lua_absindex(L, -1);
}

static inline struct material_instance*
to_instance(lua_State *L, int instanceidx){
	return (struct material_instance*)luaL_checkudata(L, instanceidx, "ANT_INSTANCE_MT");
}

// 1: material_instance
// 2: uniform name
// 3: value
static int
linstance_set_attrib(lua_State *L) {
	struct material_instance * mi = to_instance(L, 1);
#ifdef _DEBUG
	const char* attribname = luaL_checkstring(L, 2);
#endif //_DEBUG

	const int mat_idx = get_material_index(L, 1);	// push material in stack
	const attrib_id id = lookup_material_attrib_id(L, mat_idx, 2);
	struct attrib_arena* arena = arena_from_reg(L);

	attrib_type * a = al_attrib(arena, id);
	if (lua_type(L, 3) == LUA_TNIL) {
		unset_instance_attrib(L, mi, arena, a);
	} else {
		set_instance_attrib(L, mi, arena, a, 3);
	}
	lua_pop(L, 2); //pop material object, arena
	return 0;
}

static void
return_invalid_attrib_from_instance(lua_State *L, int mat_idx, vla_handle_t cobj_hlist){
	vla_handle_t mhlist = get_invalid_list_handle(L, mat_idx);
	vla_using(mlist, attrib_id, mhlist, L);
	vla_using(cobjlist, attrib_id, cobj_hlist, L);
	for (int i=0;i<vla_size(mlist); ++i){
		vla_push(cobjlist, mlist[i], L);
	}
}

static inline vla_handle_t
material_get_cobj_invalid_list(lua_State*L, int mat_idx){
	if (lua_getiuservalue(L, 1, MATERIAL_UV_ARENA) != LUA_TUSERDATA){
		luaL_error(L, "Invalid material data, user value 1 is not 'arena'");
	}
	if (LUA_TUSERDATA != lua_getiuservalue(L, -1, ARENA_UV_INVALID_LIST)){// material invalid attrib list table
		luaL_error(L, "Invalid uservalue in 'arena', uservalue in 3 should ba invalid material atrrib table");
	}
	vla_handle_t cobj_hlist = to_vla_handle(L, -1);
	lua_pop(L, 2);
	return cobj_hlist;
}

static int
lmaterial_gc(lua_State *L) {
	struct material *mat = luaL_checkudata(L, 1, "ANT_MATERIAL");
	vla_handle_t cobj_hlist = material_get_cobj_invalid_list(L, 1);

	if (mat->attrib != INVALID_ATTRIB) {
		vla_using(cobjlist, attrib_id, cobj_hlist, L);
		vla_push(cobjlist, mat->attrib, L);
		mat->attrib = INVALID_ATTRIB;
	}

	return_invalid_attrib_from_instance(L, 1, cobj_hlist);
	lua_pop(L, 2);				// arena, material invalid attrib list
	return 0;
}

static int
linstance_release(lua_State *L) {
	struct material_instance * mi = to_instance(L, 1);
	if (mi->patch_attrib != INVALID_ATTRIB) {
		if (LUA_TUSERDATA != lua_getiuservalue(L, 1, INSTANCE_UV_INVALID_LIST)){
			return luaL_error(L, "Invalid material instance");
		}
		vla_handle_t hlist = to_vla_handle(L, -1);
		lua_pop(L, 1);

		vla_using(list, attrib_id, hlist, L);
		vla_push(list, mi->patch_attrib, L);
		mi->patch_attrib = INVALID_ATTRIB;
		mi->m = NULL;
	}

	return 0;
}

#define MAX_UNIFORM_NUM 1024

static inline bgfx_texture_handle_t
check_get_texture_handle(lua_State *L, uint32_t handle){
	if ((0xffff0000 & handle) == 0){
		return texture_get((int)handle);
	}
	
	bgfx_texture_handle_t t = {(uint16_t)handle};
	return t;
}

static void
apply_attrib(lua_State *L, struct attrib_arena * arena, struct ecs_world* w, attrib_type *a) {
	switch(a->h.type){
		case ATTRIB_REF:
			apply_attrib(L, arena, w, al_attrib(arena, a->ref.id));
			break;
		case ATTRIB_SAMPLER: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(L, a->u.t.handle);
			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG
			BGFX(encoder_set_texture)(w->holder->encoder, a->u.t.stage, a->u.handle, tex, UINT32_MAX);
		}	break;
		case ATTRIB_IMAGE: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(L, a->r.handle);
			BGFX(encoder_set_image)(w->holder->encoder, a->r.stage, tex, a->r.mip, a->r.access, BGFX_TEXTURE_FORMAT_COUNT);
		}	break;

		case ATTRIB_BUFFER: {
			const attrib_id id = a->r.handle & 0xffff;
			const uint16_t btype = a->r.handle >> 16;
			switch(btype) {
			case BGFX_HANDLE_VERTEX_BUFFER: {
				bgfx_vertex_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_vertex_buffer)(w->holder->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
				bgfx_dynamic_vertex_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_dynamic_vertex_buffer)(w->holder->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_INDEX_BUFFER: {
				bgfx_index_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_index_buffer)(w->holder->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32:
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER: {
				bgfx_dynamic_index_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_dynamic_index_buffer)(w->holder->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_INDIRECT_BUFFER: {
				bgfx_indirect_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_indirect_buffer)(w->holder->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			default:
				luaL_error(L, "Invalid buffer type %d", btype);
				break;
			}
		}	break;
		case ATTRIB_COLOR_PAL:{
			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG
			const uint32_t n = al_attrib_num(arena, a);
			if (n == 1) {
				struct color_palette* cp = arena->color_palettes + a->u.cp.pal;
				struct color* c = cp->colors+a->u.cp.color;
				BGFX(encoder_set_uniform)(w->holder->encoder, a->u.handle, c->rgba, 1);
			} else {
				luaL_error(L, "Not implement multi color pal");
			}
		}	break;
		case ATTRIB_UNIFORM: {
			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG

			const uint32_t n = al_attrib_num(arena, a);
			// most case is n == 1
			if (n == 1){
				const float * v = math_value(w->math3d->M, a->u.m);
				BGFX(encoder_set_uniform)(w->holder->encoder, a->u.handle, v, 1);
			} else {
				// multiple uniforms
				float buffer[MAX_UNIFORM_NUM * 16];
				float *ptr = buffer;
				
				attrib_type* na = a;
				for (uint16_t i=0; i<n; ++i){
					int stride;
					int t = math_type(w->math3d->M, na->u.m);
					const float * v = math_value(w->math3d->M, na->u.m);
					if (t == MATH_TYPE_MAT) {
						stride = 16;
					} else {
						stride = 4;
					}
					if (ptr + stride - buffer > MAX_UNIFORM_NUM * 16)
						luaL_error(L, "Too many uniforms %d", n);
					memcpy(ptr, v, stride * sizeof(float));
					ptr += stride;
					na = al_next_attrib(arena, na);
				}
				BGFX(encoder_set_uniform)(w->holder->encoder, a->u.handle, buffer, n);
			}
		}	break;
		default:
			luaL_error(L, "Invalid attrib type:%d", a->h.type);
			break;
	}
}

static int
linstance_attribs(lua_State *L){
	struct attrib_arena* arena = arena_from_reg(L);
	const struct material_instance* mi = to_instance(L, 1);
	struct ecs_world* w = getworld(L);

	lua_createtable(L, 0, 0);
	const int resultidx = lua_absindex(L, -1);

	int idx = 1;
	for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
		push_attrib_value(L, arena, w, pid);
		lua_seti(L, resultidx, idx++);
	}
	
	return 1;
}

void
apply_material_instance(lua_State *L, struct material_instance *mi, struct ecs_world *w){
	struct attrib_arena* arena = arena_from_reg(L);
	BGFX(encoder_set_state)(w->holder->encoder, 
		(mi->patch_state.state == 0 ? mi->m->state.state : mi->patch_state.state), 
		(mi->patch_state.rgba == 0 ? mi->m->state.rgba : mi->patch_state.rgba));

	const uint64_t stencil = mi->patch_state.stencil == 0 ? mi->m->state.stencil : mi->patch_state.stencil;
	BGFX(encoder_set_stencil)(w->holder->encoder,
		(uint32_t)(stencil & 0xffffffff), (uint32_t)(stencil >> 32)
	);

	if (mi->patch_attrib == INVALID_ATTRIB) {
		for (attrib_id id = mi->m->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)){
			attrib_type* a = al_attrib(arena, id);
			apply_attrib(L, arena, w, a);
		}
	} else {
		for (attrib_id id = mi->m->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)){
			attrib_id apply_id = id;
			for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
				attrib_type* pa = al_attrib(arena, pid);
				if (pa->h.patch == id){
					apply_id = pid;
					break;
				}
			}
			attrib_type *a = al_attrib(arena, apply_id);
			apply_attrib(L, arena, w, a);
		}
	}
}

bgfx_program_handle_t
material_prog(lua_State *L, struct material_instance *mi){
	(void)L;
	return mi->m->prog;
}

// 1: material_instance
// 2: texture lookup table
static int
linstance_apply_attrib(lua_State *L) {
	struct material_instance *mi = to_instance(L, 1);
	struct ecs_world* w = getworld(L);
	apply_material_instance(L, mi, w);
	return 0;
}

static int
linstance_get_material(lua_State *L){
	get_material_index(L, 1);
	return 1;
}

static int
linstance_replace_material(lua_State *L){
	struct material_instance* mi = to_instance(L, 1);
	struct material* m = check_material_index(L, 2);
	mi->m = m;
	lua_pushvalue(L, 2);
	verfiy(lua_setiuservalue(L, 1, INSTANCE_UV_MATERIAL));
	return 0;
}

static int
linstance_get_state(lua_State *L){
	struct material_instance* mi = to_instance(L, 1);
	return push_material_state(L,
		mi->patch_state.state == 0 ? mi->m->state.state : mi->patch_state.state,
		mi->patch_state.rgba == 0 ? mi->m->state.rgba : mi->patch_state.rgba);
}

static int
linstance_set_state(lua_State *L){
	struct material_instance* mi = to_instance(L, 1);
	fetch_material_state(L, 2, &mi->patch_state);
	return 0;
}

static int
linstance_get_stencil(lua_State *L){
	struct material_instance* mi = to_instance(L, 1);
	return push_material_stencil(L,
		mi->patch_state.stencil == 0 ? mi->m->state.stencil : mi->patch_state.stencil);
}

static int
linstance_set_stencil(lua_State *L){
	struct material_instance* mi = to_instance(L, 1);
	fetch_material_stencil(L, 2, &mi->patch_state);
	return 0;
}

static int
linstance_ptr(lua_State *L){
	lua_pushlightuserdata(L, to_instance(L, 1));
	return 1;
}

static inline void
clear_material_attribs(lua_State *L, int mat_idx){
	struct attrib_arena * arena = to_arena(L, get_arena_index(L, mat_idx));
	lua_pop(L, 1);
	vla_handle_t hlist = get_invalid_list_handle(L, mat_idx);
	clear_unused_attribs(L, arena, hlist);
}

static int
lmaterial_instance(lua_State *L) {
	clear_material_attribs(L, 1);

	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), INSTANCE_UV_NUM);
	mi->patch_attrib = INVALID_ATTRIB;
	mi->patch_state.state = 0;
	mi->patch_state.rgba = 0;
	mi->m = check_material_index(L, 1);
	vla_lua_new(L, 0, sizeof(attrib_id));
	verfiy(lua_setiuservalue(L, -2, INSTANCE_UV_INVALID_LIST));
	lua_pushvalue(L, 1);
	verfiy(lua_setiuservalue(L, -2, INSTANCE_UV_MATERIAL));

	if (luaL_newmetatable(L, "ANT_INSTANCE_MT")){
		luaL_Reg l[] = {
			{ "__newindex", 	linstance_set_attrib},
			{ "__call", 		linstance_apply_attrib},
			{ "release",		linstance_release},
			{ "attribs",		linstance_attribs},
			{ "get_material",	linstance_get_material},
			{ "replace_material",linstance_replace_material},

			{ "get_state",		linstance_get_state},
			{ "set_state",		linstance_set_state},
			{ "get_stencil",	linstance_get_stencil},
			{ "set_stencil",	linstance_set_stencil},

			{ "ptr",			linstance_ptr},
			{ NULL, 		NULL },
		};
		check_ecs_world_in_upvalue1(L);
		lua_pushvalue(L, lua_upvalueindex(1));
		luaL_setfuncs(L, l, 1);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static inline attrib_id
fetch_material_attrib_value(lua_State *L, struct attrib_arena* arena,
	int sa_lookup_idx, int lookup_idx, const char*key, attrib_id lastid){
	if (LUA_TNIL != lua_getfield(L, sa_lookup_idx, key)){
		attrib_type* a = arena_alloc(L);
		a->h.type = ATTRIB_REF;
		a->ref.id = (attrib_id)lua_tointeger(L, -1);
		a->h.next = lastid;
		lastid = al_attrib_id(arena, a);
		lua_pop(L, 1);
	} else {
		lua_pop(L, 1);
		lastid = load_attrib_from_data(L, arena, -1, lastid);
	}

	lua_pushinteger(L, lastid);
	lua_setfield(L, lookup_idx, key);
	return lastid;
}

static int
lmaterial_type_gc(lua_State *L){
	struct material* submat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL_TYPE");
	submat->attrib = INVALID_ATTRIB;

	vla_handle_t cobj_hlist = material_get_cobj_invalid_list(L, 1);
	return_invalid_attrib_from_instance(L, 1, cobj_hlist);
	return 0;
}

static int
lmaterial_copy(lua_State *L);

static void
set_material_matatable(lua_State *L, const char* mtname, int issubtype){
	if (luaL_newmetatable(L, mtname)) {
		luaL_Reg l[] = {
			{ "__gc",		(issubtype ? lmaterial_type_gc : lmaterial_gc)},
			{ "attribs", 	lmaterial_attribs },
			{ "instance", 	lmaterial_instance },
			{ "set_attrib",	lmaterial_set_attrib},
			{ "get_state",	lmaterial_get_state},
			{ "set_state",	lmaterial_set_state},
			{ "fetch_material_stencil",lmaterial_get_stencil},
			{ "set_stencil",lmaterial_set_stencil},
			{ "copy",		(issubtype ? NULL : lmaterial_copy)},
			{ NULL, 		NULL },
		};
		check_ecs_world_in_upvalue1(L);
		lua_pushvalue(L, lua_upvalueindex(1));
		luaL_setfuncs(L, l, 1);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
}

//material type user value:
//1. arena
//2. material lut
static int
lmaterial_copy(lua_State *L){
	struct material* temp_mat = (struct material*)lua_touserdata(L, 1);
	struct material* new_mat = (struct material*)lua_newuserdatauv(L, sizeof(*new_mat), MATERIAL_UV_NUM);
	new_mat->attrib = temp_mat->attrib;
	new_mat->prog = temp_mat->prog;
	new_mat->state = temp_mat->state;
	if (!lua_isnoneornil(L, 2)){
		fetch_material_state(L, 2, &(new_mat->state));
	}

	if (!lua_isnoneornil(L, 3)){
		fetch_material_stencil(L, 3, &new_mat->state);
	}

	//uv1
	lua_getiuservalue(L, 1, MATERIAL_UV_ARENA);
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_ARENA));

	//uv2
	lua_getiuservalue(L, 1, MATERIAL_UV_LUT);
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_LUT));

	//uv3
	vla_lua_new(L, 0, sizeof(attrib_id));
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_INVALID_LIST));

	set_material_matatable(L, "ANT_MATERIAL_TYPE", 1);

	return 1;
}

// 1: arena
// 2: render state (string)
// 3: uniforms (table)
static int
lmaterial_new(lua_State *L) {
	struct material_state state;
	fetch_material_state(L, 1, &state);
	fetch_material_stencil(L, 2, &state);
	lua_settop(L, 4);
	struct material *mat = (struct material *)lua_newuserdatauv(L, sizeof(*mat), MATERIAL_UV_NUM);
	mat->state = state;

	mat->attrib = INVALID_ATTRIB;
	mat->prog.idx = luaL_checkinteger(L, 4) & 0xffff;
	set_material_matatable(L, "ANT_MATERIAL", 0);
	const int matidx = lua_absindex(L, -1);

	const int arenaidx = check_push_arena(L);
	struct attrib_arena* arena = to_arena(L, arenaidx);

	//system attrib table
	if (lua_getiuservalue(L, arenaidx, ARENA_UV_SYSTEM_ATTRIBS) != LUA_TTABLE){
		luaL_error(L, "Invalid system atrrib table");
	}
	lua_insert(L, -2);	//swap arena index and system attrib index

	//-1 index is arena object
	verfiy(lua_setiuservalue(L, matidx, MATERIAL_UV_ARENA));			// push arena as user value

	//-1 index is system attrib index
	const int sa_lookup_idx = lua_absindex(L, -1);

	lua_newtable(L);
	const int lookup_idx = lua_absindex(L, -1);
	const int properties_idx = 3;
	for (lua_pushnil(L); lua_next(L, properties_idx) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		mat->attrib = fetch_material_attrib_value(L, arena, sa_lookup_idx, lookup_idx, key, mat->attrib);
	}

	verfiy(lua_setiuservalue(L, matidx, MATERIAL_UV_LUT));	// push lookup table as uv3

	lua_pop(L, 1);	//system attrib table

	vla_lua_new(L, 0, sizeof(attrib_id));
	verfiy(lua_setiuservalue(L, matidx, MATERIAL_UV_INVALID_LIST));
	return 1;
}


static int
lcolor_palette_new(lua_State *L){
	struct ecs_world * w = getworld(L);
	struct attrib_arena* arena = arena_from_reg(L);
	const int argidx = 1;
	if (!lua_isnoneornil(L, argidx)){
		luaL_checktype(L, argidx, LUA_TTABLE);
		const int n = (int)lua_rawlen(L, argidx);
		if (n > MAX_COLOR_IN_PALETTE){
			return luaL_error(L, "Too many color for palette, max number is:%d", MAX_COLOR_IN_PALETTE);
		}
		struct color_palette* cp = arena->color_palettes + arena->cp_idx;
		for (int i=0; i<n; ++i){
			lua_geti(L, argidx, i+1);
			const float *v = math_value(w->math3d->M, math3d_from_lua(L, w->math3d, -1, MATH_TYPE_VEC4));
			struct color* c = cp->colors + i;
			memcpy(c->rgba, v, sizeof(c->rgba));
			lua_pop(L, 1);
		}
	}
	lua_pushinteger(L, arena->cp_idx++);
	return 1;
}

static int
lsa_update(lua_State *L){
	luaL_checktype(L, 1, LUA_TTABLE);
	const char* name = luaL_checkstring(L, 2);
	if (LUA_TNUMBER != lua_getfield(L, 1, name)){
		lua_pop(L, 1);
		return luaL_error(L, "Invalid system attrib:%s", name);
	}
	const attrib_id id = (attrib_id)lua_tointeger(L, -1);
	struct attrib_arena* arena = arena_from_reg(L);
	attrib_type* a = al_attrib(arena, id);
	update_attrib(L, arena, a, 3);
	lua_pop(L, 1);
	return 0;
}

static int
lsystem_attribs_new(lua_State *L){
	check_push_arena(L);
	const int arenaidx = lua_absindex(L, -1);
	struct attrib_arena* arena = to_arena(L, arenaidx);
	luaL_checktype(L, 1, LUA_TTABLE);

	lua_newtable(L);
	const int lookup_idx = lua_absindex(L, -1);
	for (lua_pushnil(L); lua_next(L, 1) != 0; lua_pop(L, 1)) {
		const char* name = lua_tostring(L, -2);
		const attrib_id id = load_attrib_from_data(L, arena, -1, INVALID_ATTRIB);
		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, name);
	}

	if (luaL_newmetatable(L, "ANT_SYSTEM_ATTRIBS")){
		luaL_Reg l[] = {
			{"update", 	lsa_update},
			{NULL,		NULL},
		};
		check_ecs_world_in_upvalue1(L);
		lua_pushvalue(L, lua_upvalueindex(1));
		luaL_setfuncs(L, l, 1);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);

	lua_pushvalue(L, -1);		// system attrib table
	verfiy(lua_setiuservalue(L, arenaidx, ARENA_UV_SYSTEM_ATTRIBS));
	return 1;
}

static inline struct color*
get_color(lua_State *L, struct attrib_arena *arena, int palidx, int coloridx){
	const uint8_t palid = (uint8_t)luaL_checkinteger(L, 2);
	if (palid > MAX_COLOR_PALETTE_COUNT){
		luaL_error(L, "Invalid color palette index");
	}
	const int32_t colorid = (int32_t)luaL_checkinteger(L, 3);
	if (colorid < 0 || colorid > MAX_COLOR_IN_PALETTE){
		luaL_error(L, "Invalid color index");
	}

	struct color_palette* cp = arena->color_palettes+palid;
	return cp->colors+colorid;
}

static int
lcolor_palette_get(lua_State *L){
	struct attrib_arena* arena = arena_from_reg(L);
	struct ecs_world* w = getworld(L);
	const struct color* c = get_color(L, arena, 2, 3);

	math_t id = math_import(w->math3d->M, c->rgba, MATH_TYPE_VEC4, 1);
	lua_pushlightuserdata(L, (void *)id.idx);
	return 1;
}

static int
lcolor_palette_set(lua_State *L){
	struct attrib_arena* arena = arena_from_reg(L);
	struct ecs_world* w = getworld(L);
	struct color* c = get_color(L, arena, 2, 3);

	const float* v = math_value(w->math3d->M, math3d_from_lua(L, w->math3d, 4, MATH_TYPE_VEC4));
	memcpy(c->rgba, v, sizeof(c->rgba));
	return 0;
}

static int
lstat(lua_State *L){
	struct attrib_arena *arena = arena_from_reg(L);
	lua_newtable(L);
	lua_pushinteger(L, arena->n);
	lua_setfield(L, -2, "attrib_num");
	lua_pushinteger(L, arena->cap);
	lua_setfield(L, -2, "attrib_cap");
	return 1;
}

LUAMOD_API int
luaopen_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "material",		lmaterial_new},
		{ "system_attribs", lsystem_attribs_new},
		{ "color_palette",	lcolor_palette_new},
		{ "color_palette_get",lcolor_palette_get},
		{ "color_palette_set",lcolor_palette_set},
		{ "stat",			lstat},
		{ NULL, 			NULL },
	};
	luaL_newlib(L, l);
	lua_pushnil(L);
	luaL_setfuncs(L, l, 1);

	arena_new(L);
	return 1;
}

