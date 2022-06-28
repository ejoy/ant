#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <luabgfx.h>

#include "vla.h"

#ifdef _DEBUG
#define verfiy(_CON)	assert(_CON)
#else //!_DEBUG
#define verfiy(_CON)	_CON
#endif //_DEBUG


#define INVALID_ATTRIB 0xffff
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

#define CAPI_INIT(L, idx) struct attrib_arena * cobject_ = get_cobject(L, idx);
#define CAPI_ARENA cobject_
#define CAPI_MATH3D cobject_->math
#define BGFX(api) cobject_->bgfx->api
#define BGFX_INVALID(h) (h.idx == UINT16_MAX)
#define BGFX_EQUAL(a,b) (a.idx == b.idx)

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

#define ATTRIB_HEARDER uint16_t type;\
	uint16_t next;\
	uint16_t patch;

struct attrib_header {
	ATTRIB_HEARDER
};

struct attrib_uniform {
	ATTRIB_HEARDER
	bgfx_uniform_handle_t handle;
	union {
		int64_t m;
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
	uint16_t id;
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

#define COBJECT_UV_ATTRIB_BUFFER	1
#define COBJECT_UV_SYSTEM_ATTRIBS	2
#define COBJECT_UV_INVALID_LIST		3
#define COBJECT_UV_NUM				3
// uv1: attrib buffer
// uv2: system attribs
// uv3: material invalid attrib list
struct attrib_arena {
	bgfx_interface_vtbl_t *bgfx;
	struct math3d_api *math;
	struct encoder_holder* eh;
	uint16_t cap;
	uint16_t n;
	uint16_t freelist;
	uint16_t cp_idx;
	attrib_type *a;
	struct color_palette color_palettes[MAX_COLOR_PALETTE_COUNT];
};

#define MATERIAL_UV_COBJECT			1
#define MATERIAL_UV_LUT				2
#define MATERIAL_UV_INVALID_LIST	3
#define MATERIAL_UV_NUM				3

//uv1: cobject
//uv2: lookup table, [name: id]
//uv3: invalid list handle
struct material {
	uint64_t state;
	uint32_t rgba;
	uint16_t attrib;
};

#define INSTANCE_UV_INVALID_LIST	1
#define INSTANCE_UV_MATERIAL		2
#define INSTANCE_UV_NUM				2

//TODO: patch attrib list should include world matrix
struct material_instance {
	uint16_t patch_attrib;
};

struct attrib_arena *
arena_new(lua_State *L, bgfx_interface_vtbl_t *bgfx, struct math3d_api *mapi, struct encoder_holder *h) {
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), COBJECT_UV_NUM);
	a->bgfx = bgfx;
	a->math = mapi;
	a->eh = h;
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
	a->cp_idx = 0;
	memset(&a->color_palettes, 0, sizeof(a->color_palettes));
	//invalid material attrib list
	vla_lua_new(L, 0, sizeof(uint16_t));
	verfiy(lua_setiuservalue(L, -2, COBJECT_UV_INVALID_LIST));	//set invalid table as uv 3
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
	a->u.m 	= 0;
}

static inline attrib_type*
al_attrib(struct attrib_arena *arena, uint16_t id){
	assert(arena->cap > id);
	return arena->a + id;
}

static inline uint16_t
al_attrib_id(struct attrib_arena *arena, attrib_type *a) {
	return (uint16_t)(a - arena->a);
}

// static inline uint16_t
// al_attrib_next_id(struct attrib_arena* arena, uint16_t id){
// 	return al_attrib(arena, id)->h.next;
// }

static inline attrib_type*
al_next_attrib(struct attrib_arena *arena, attrib_type* a){
	return a->h.next == INVALID_ATTRIB ? NULL : al_attrib(arena, a->h.next);
}

// static inline attrib_type*
// al_attrib_next(struct attrib_arena *arena, uint16_t id){
// 	return al_next_attrib(arena, al_attrib(arena, id));
// }

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

static inline uint16_t
al_attrib_next_uniform_id(struct attrib_arena* arena, uint16_t id, uint16_t *count){
	assert(id != INVALID_ATTRIB);
	
	attrib_type* a = al_attrib(arena, id);
	uint16_t c = 1;
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

// static inline attrib_type*
// al_attrib_next_uniform(struct attrib_arena* arena, attrib_type* a, uint16_t *count){
// 	uint16_t nid = al_attrib_next_uniform_id(arena, al_attrib_id(arena, a), count);
// 	return nid == INVALID_ATTRIB ? NULL : al_attrib(arena, nid);
// }

static inline int
al_attrib_num(struct attrib_arena* arena, attrib_type *a){
	uint16_t c = 0;
	al_attrib_next_uniform_id(arena, al_attrib_id(arena, a), &c);
	return c;
}

static inline void
al_attrib_return(struct attrib_arena * arena, attrib_type *a) {
	uint16_t id = al_attrib_id(arena, a);
	a->h.next = arena->freelist;
	arena->freelist = id;
}

static inline uint16_t
al_attrib_clear(struct attrib_arena *arena, uint16_t id) {
	attrib_type *a = al_attrib(arena, id);
	if (a->h.type == ATTRIB_UNIFORM) {
		math3d_unmark_id(arena->math, a->u.m);
		a->u.m = 0;
	}
	id = a->h.next;
	al_attrib_return(arena, a);
	return id;
}

//material instance: mi_*////////////////////////////////////////////////////////////////////////////
static inline uint16_t
mi_find_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, uint16_t id){
	assert(id != INVALID_ATTRIB);
	for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
		attrib_type *pa = al_attrib(arena, pid);
		if (pa->h.patch == id)
			return pid;
	}

	return INVALID_ATTRIB;
}

/////////////////////////////////////////////////////////////////////////////
attrib_type *
arena_alloc(lua_State *L, int idx) {
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, idx);
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
		verfiy(lua_setiuservalue(L, idx, COBJECT_UV_ATTRIB_BUFFER));
		arena->a = al;
		arena->cap = DEFAULT_ARENA_SIZE;
		arena->n = 1;
		ret = arena->a;
	} else {
		// resize arena
		int newcap = arena->cap * 2;
		if (newcap > INVALID_ATTRIB)
			luaL_error(L, "Too many attribs");
		attrib_type * al = (attrib_type *)lua_newuserdatauv(L, sizeof(attrib_type) * newcap, 0);
		memcpy(al, arena->a, sizeof(attrib_type) * arena->n);
		arena->a = al;
		arena->cap = newcap;
		verfiy(lua_setiuservalue(L, idx, COBJECT_UV_ATTRIB_BUFFER));
		ret = al_attrib(arena, arena->n++);
	}
	al_init_attrib(arena, ret);
	return ret;
}

static void
clear_unused_attribs(lua_State *L, struct attrib_arena *arena, vla_handle_t hlist) {
	vla_using(list, uint16_t, hlist, L);
	const int n = vla_size(list);
	for (int i=0;i<n;++i) {
		uint16_t id = list[i];
		do {
			id = al_attrib_clear(arena, id);
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

static void
uniform_value(lua_State *L, attrib_type *a) {
	switch (a->h.type){
		case ATTRIB_UNIFORM:
			lua_pushlightuserdata(L, (void *)a->u.m);
			break;
		case ATTRIB_SAMPLER:
			lua_pushfstring(L, "s%d:%x", a->u.t.stage, a->u.t.handle);
			break;
		default:
			luaL_error(L, "Invalid uniform attribute type:%d, image|buffer is not uniform attrib", a->h.type);
			break;
	}
}

// 1: material
static int
lmaterial_attribs(lua_State *L) {
	struct material *mat = (struct material *)luaL_checkudata(L, 1, "ANT_MATERIAL");
	lua_settop(L, 1);
	if (LUA_TUSERDATA != lua_getiuservalue(L, 1, MATERIAL_UV_COBJECT)){
		return luaL_error(L, "Invalid material, uservalue in 2 is not 'cobject'");
	}
	const int arena_idx = 2;
	CAPI_INIT(L, arena_idx);
	struct attrib_arena *arena = CAPI_ARENA;
	lua_newtable(L);
	int result_index = lua_gettop(L);

	for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)) {
		attrib_type * a = al_attrib(cobject_, id);
		switch(a->h.type){
			case ATTRIB_UNIFORM:
			case ATTRIB_SAMPLER:{
				uint16_t num = al_attrib_num(arena, a);
				bgfx_uniform_info_t info;
				BGFX(get_uniform_info)(a->u.handle, &info);
				assert(info.num == num);
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
						a = al_next_attrib(arena, a);
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
get_state(lua_State *L, int idx, uint64_t *pstate, uint32_t *prgba) {
	// compute shader
	if (lua_isnoneornil(L, idx)){
		*pstate = 0;
		*prgba = 0;
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
	*pstate = state;
	*prgba = rgba;
}

static inline vla_handle_t
to_vla_handle(lua_State *L, int idx){
	vla_handle_t hlist;
	hlist.l = (struct vla_lua*)lua_touserdata(L, -1);
	return hlist;
}

static inline struct attrib_arena*
to_arena(lua_State *L, int arena_idx){
	return (struct attrib_arena*)lua_touserdata(L, arena_idx);
}

static void
unset_instance_attrib(struct material_instance *mi, struct attrib_arena *arena, attrib_type *a) {
	uint16_t ref = mi_find_patch_attrib(arena, mi, al_attrib_id(arena, a));
	if (ref != INVALID_ATTRIB){
		const int num = al_attrib_num(arena, a);
		uint16_t id = ref;
		for (int i=0;i<num;i++) {
			id = al_attrib_clear(arena, id);
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
fetch_math_value_(lua_State *L, struct attrib_arena* arena,  attrib_type* a, int index){
	math3d_unmark_id(arena->math, a->u.m);
	a->u.m = math3d_mark_id(L, arena->math, index);
}

static inline void
fetch_math_value(lua_State *L, struct attrib_arena* arena, attrib_type* a, int index){
	const int datatype = lua_type(L, index);
	if (datatype == LUA_TTABLE){
		const int lt = lua_getfield(L, index, "value");
		if (lt != LUA_TLIGHTUSERDATA && lt != LUA_TUSERDATA){
			luaL_error(L, "Invalid math uniform 'value' field, math3d value is required");
		}
		fetch_math_value_(L, arena, a, -1);
		lua_pop(L, 1);
	} else if (datatype == LUA_TLIGHTUSERDATA || datatype == LUA_TUSERDATA){
		fetch_math_value_(L, arena, a, index);
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
fetch_color_pal(lua_State *L, struct attrib_arena *arena, attrib_type *a, int index){
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
fetch_attrib(lua_State *L, struct attrib_arena *arena, attrib_type *a, int index) {
	switch (a->h.type){
		case ATTRIB_UNIFORM:	fetch_math_value(L, arena, a, index);				break;
		case ATTRIB_SAMPLER:	fetch_sampler(L, a, index);							break;
		case ATTRIB_IMAGE:		fetch_image(L, a, index);							break;
		case ATTRIB_BUFFER:		fetch_buffer(L, a, index);							break;
		case ATTRIB_COLOR_PAL:	fetch_color_pal(L, arena, a, index);				break;
		default: luaL_error(L, "Attribute type:%d, could not update", a->h.type);	break;
	}
}

static inline uint16_t
create_attrib(lua_State *L, int arena_idx, int n, uint16_t id, uint16_t attribtype, bgfx_uniform_handle_t h){
	struct attrib_arena* arena = to_arena(L, arena_idx);
	for (int i=0; i<n; ++i){
		attrib_type* na = arena_alloc(L, arena_idx);
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
	const uint16_t n = al_attrib_num(arena, a);
	if (n == 1) {
		fetch_attrib(L, arena, a, data_idx);
	} else {
		int didx;
		const int lt = begin_fetch_attrib_array(L, data_idx, &didx);
		for (int i=0;i<n;i++) {
			assert(a && "Invalid attrib");
			lua_geti(L, didx, i+1);
			fetch_attrib(L, arena, a, -1);
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

static uint16_t
load_attrib_from_data(lua_State *L, int arena_idx, int data_index, uint16_t id) {
	const uint16_t type = fetch_attrib_type(L, data_index);
	const int n = count_data_num(L, data_index, type);
	const bgfx_uniform_handle_t h = {is_uniform_attrib(type) ? fetch_handle(L, data_index).idx : UINT16_MAX};
	uint16_t nid = create_attrib(L, arena_idx, n, id, type, h);
	struct attrib_arena* arena = to_arena(L, arena_idx);
	update_attrib(L, arena, al_attrib(arena, nid), data_index);
	return nid;
}

static int
lmaterial_set_attrib(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	if (LUA_TUSERDATA != lua_getiuservalue(L, 1, MATERIAL_UV_COBJECT)) {	// get cobject
		return luaL_error(L, "Invalid material object, not found cobject in uservalue 2");
	}
	const int arena_idx = lua_gettop(L);
	
	if (LUA_TTABLE != lua_getiuservalue(L, 1, MATERIAL_UV_LUT)) {	// get material lookup table
		return luaL_error(L, "Invalid material object, not found lookup table in uservalue 3");
	}
	const int lut_idx = lua_gettop(L);

	const char* attribname = luaL_checkstring(L, 2);

	if (LUA_TNIL == lua_getfield(L, lut_idx, attribname)){
		mat->attrib = load_attrib_from_data(L, arena_idx, 3, mat->attrib);
		lua_pushinteger(L, mat->attrib);
		lua_setfield(L, lut_idx, attribname);
	} else {
		const uint16_t id = (uint16_t)lua_tointeger(L, -1);
		struct attrib_arena* arena = to_arena(L, arena_idx);
		update_attrib(L, arena, al_attrib(arena, id), 3);
	}
	lua_pop(L, 1);
	return 0;
}

static inline int 
push_material_state(lua_State *L, struct material *mat){
	uint64_t state = mat->state;
	uint32_t rgba = mat->rgba;
	uint8_t temp[24];
	int i;
	for (i=0;i<8;i++) {
		byte2hex((state >> ((7-i) * 8)) & 0xff, &temp[i*2]);
	}
	if (rgba) {
		for (i=0;i<4;i++) {
			byte2hex( (rgba >> ((3-i) * 8)) & 0xff, &temp[16+i*2]);
		}
		lua_pushlstring(L, (const char *)temp, 24);
	} else {
		lua_pushlstring(L, (const char *)temp, 16);
	}
	return 1;
}

static int
lmaterial_get_state(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	return push_material_state(L, mat);
}

static int
lmaterial_set_state(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	get_state(L, 2, &mat->state, &mat->rgba);
	return 0;
}


static inline int
check_uniform_num(struct attrib_arena *arena, attrib_type *a, int n){
	if (al_attrib_is_uniform(arena, a)){
		bgfx_uniform_info_t info;
		struct attrib_arena* cobject_ = arena;
		BGFX(get_uniform_info)(a->u.handle, &info);
		return (n == info.num);
	}
	return 1;
}

static inline void
init_instance_attrib(struct attrib_arena* arena, uint16_t pid, uint16_t id, int n){
	uint16_t nid = id;
	uint16_t npid = pid;
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
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, int arena_idx, attrib_type * a, int value_index) {
	const uint16_t id = al_attrib_id(arena, a);
	uint16_t pid = mi_find_patch_attrib(arena, mi, id);
	if (pid == INVALID_ATTRIB) {
		const int n = al_attrib_num(arena, a);
		assert(check_uniform_num(arena, a, n));
		pid = create_attrib(L, arena_idx, n, mi->patch_attrib, a->h.type, a->u.handle);
		init_instance_attrib(arena, pid, id, n);
		mi->patch_attrib = pid;
	}
	update_attrib(L, arena, al_attrib(arena, pid), value_index);
}

static inline void
check_material_index(lua_State *L, int mat_idx){
	if (!(luaL_testudata(L, mat_idx, "ANT_MATERIAL") || luaL_testudata(L, mat_idx, "ANT_MATERIAL_TYPE"))){
		luaL_error(L, "Invalid material");
	}
}

static inline uint16_t
lookup_material_attrib_id(lua_State *L, int mat_idx, int key_idx){
	check_material_index(L, mat_idx);
	if (LUA_TTABLE != lua_getiuservalue(L, mat_idx, MATERIAL_UV_LUT)){
		return luaL_error(L, "Invalid uservalue in function upvalue 1, need a lookup table in material uservalue 3");
	}
	lua_pushvalue(L, key_idx);	// push lookup key
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, 2, NULL));
	}
	const int id = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);	//lut
	return id;
}

static inline int
get_cobject_index(lua_State *L, int mat_idx){
	check_material_index(L, mat_idx);
	if (LUA_TUSERDATA != lua_getiuservalue(L, mat_idx, MATERIAL_UV_COBJECT)){
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

// 1: material_instance
// 2: uniform name
// 3: value
static int
linstance_set_attrib(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
#ifdef _DEBUG
	const char* attribname = luaL_checkstring(L, 2);
#endif //_DEBUG

	const int mat_idx = get_material_index(L, 1);	// push material in stack

	const uint16_t id = lookup_material_attrib_id(L, mat_idx, 2);

	const int arena_idx = get_cobject_index(L, mat_idx);	//push cobject
	struct attrib_arena* arena = to_arena(L, arena_idx);

	attrib_type * a = al_attrib(arena, id);
	if (lua_type(L, 3) == LUA_TNIL) {
		unset_instance_attrib(mi, arena, a);
	} else {
		set_instance_attrib(L, mi, arena, arena_idx, a, 3);
	}
	lua_pop(L, 2); //pop material object, cobject
	return 0;
}

static void
return_invalid_attrib_from_instance(lua_State *L, int mat_idx, vla_handle_t cobj_hlist){
	vla_handle_t mhlist = get_invalid_list_handle(L, mat_idx);
	vla_using(mlist, uint16_t, mhlist, L);
	vla_using(cobjlist, uint16_t, cobj_hlist, L);
	for (int i=0;i<vla_size(mlist); ++i){
		vla_push(cobjlist, mlist[i], L);
	}
}

static inline vla_handle_t
material_get_cobj_invalid_list(lua_State*L, int mat_idx){
	if (lua_getiuservalue(L, 1, MATERIAL_UV_COBJECT) != LUA_TUSERDATA){
		luaL_error(L, "Invalid material data, user value 1 is not 'cobject'");
	}
	if (LUA_TUSERDATA != lua_getiuservalue(L, -1, COBJECT_UV_INVALID_LIST)){// material invalid attrib list table
		luaL_error(L, "Invalid uservalue in 'cobject', uservalue in 3 should ba invalid material atrrib table");
	}
	vla_handle_t cobj_hlist = to_vla_handle(L, -1);
	lua_pop(L, 2);
	return cobj_hlist;
}

static int
lmaterial_gc(lua_State *L) {
	struct material *mat = (struct material *)lua_touserdata(L, 1);
	vla_handle_t cobj_hlist = material_get_cobj_invalid_list(L, 1);

	if (mat->attrib != INVALID_ATTRIB) {
		vla_using(cobjlist, uint16_t, cobj_hlist, L);
		vla_push(cobjlist, mat->attrib, L);
		mat->attrib = INVALID_ATTRIB;
	}

	return_invalid_attrib_from_instance(L, 1, cobj_hlist);
	lua_pop(L, 2);				// cobject, material invalid attrib list
	return 0;
}

static int
linstance_gc(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
	if (mi->patch_attrib != INVALID_ATTRIB) {
		if (LUA_TUSERDATA != lua_getiuservalue(L, 1, INSTANCE_UV_INVALID_LIST)){
			return luaL_error(L, "Invalid material instance");
		}
		vla_handle_t hlist = to_vla_handle(L, -1);
		lua_pop(L, 1);

		vla_using(list, uint16_t, hlist, L);
		vla_push(list, mi->patch_attrib, L);
		mi->patch_attrib = INVALID_ATTRIB;
	}

	return 0;
}

#define MAX_UNIFORM_NUM 1024

static inline bgfx_texture_handle_t
check_get_texture_handle(lua_State *L, int texture_index, uint32_t handle){
	bgfx_texture_handle_t tex;
	lua_geti(L, texture_index, handle);
	tex.idx = luaL_optinteger(L, -1, handle) & 0xffff;
	lua_pop(L, 1);
	return tex;
}

static void
apply_attrib(lua_State *L, struct attrib_arena * cobject_, attrib_type *a, int texture_index) {
	switch(a->h.type){
		case ATTRIB_REF:
			apply_attrib(L, cobject_, al_attrib(cobject_, a->ref.id), texture_index);
			break;
		case ATTRIB_SAMPLER: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(L, texture_index, a->u.t.handle);
			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG
			BGFX(encoder_set_texture)(cobject_->eh->encoder, a->u.t.stage, a->u.handle, tex, UINT32_MAX);
		}	break;
		case ATTRIB_IMAGE: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(L, texture_index, a->r.handle);
			BGFX(encoder_set_image)(cobject_->eh->encoder, a->r.stage, tex, a->r.mip, a->r.access, BGFX_TEXTURE_FORMAT_COUNT);
		}	break;

		case ATTRIB_BUFFER: {
			const uint16_t id = a->r.handle & 0xffff;
			const uint16_t btype = a->r.handle >> 16;
			switch(btype) {
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
				luaL_error(L, "Invalid buffer type %d", btype);
				break;
			}
		}	break;
		case ATTRIB_COLOR_PAL:{
			struct attrib_arena * arena = cobject_;
			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG
			const uint16_t n = al_attrib_num(arena, a);
			if (n == 1) {
				struct color_palette* cp = arena->color_palettes + a->u.cp.pal;
				struct color* c = cp->colors+a->u.cp.color;
				BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, c->rgba, 1);
			} else {
				luaL_error(L, "Not implement multi color pal");
			}
		}	break;
		case ATTRIB_UNIFORM: {
			struct attrib_arena * arena = cobject_;

			#ifdef _DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //_DEBUG

			const uint16_t n = al_attrib_num(arena, a);
			// most case is n == 1
			if (n == 1){
				int t;
				const float * v = math3d_value(CAPI_MATH3D, a->u.m, &t);
				BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, v, 1);
			} else {
				// multiple uniforms
				float buffer[MAX_UNIFORM_NUM * 16];
				float *ptr = buffer;
				
				attrib_type* na = a;
				for (uint16_t i=0; i<n; ++i){
					int t;
					int stride;
					const float * v = math3d_value(CAPI_MATH3D, na->u.m, &t);
					if (t == LINEAR_TYPE_MAT) {
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
				BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, buffer, n);
			}
		}	break;
		default:
			luaL_error(L, "Invalid attrib type:%d", a->h.type);
			break;
	}
}

// 1: material_instance
// 2: texture lookup table
static int
linstance_apply_attrib(lua_State *L) {
	struct material_instance *mi = (struct material_instance *)lua_touserdata(L, 1);
	const int texture_index = 2;
	luaL_checktype(L, texture_index, LUA_TTABLE);
	const int mat_idx = get_material_index(L, 1); // push material object
	struct material *mat = (struct material *)lua_touserdata(L, mat_idx);
	struct attrib_arena* arena = to_arena(L, get_cobject_index(L, mat_idx));	// push cobject

	struct attrib_arena* cobject_ = arena;
	BGFX(encoder_set_state)(cobject_->eh->encoder, mat->state, mat->rgba);

	if (mi->patch_attrib == INVALID_ATTRIB) {
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)){
			attrib_type* a = al_attrib(arena, id);
			apply_attrib(L, arena, a, texture_index);
		}
	} else {
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)){
			uint16_t apply_id = id;
			for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
				attrib_type* pa = al_attrib(arena, pid);
				if (pa->h.patch == id){
					apply_id = pid;
					break;
				}
			}
			attrib_type *a = al_attrib(arena, apply_id);
			apply_attrib(L, arena, a, texture_index);
		}
	}

	lua_pop(L, 2);	//pop material object, cobject
	return 0;
}

static int
linstance_get_material(lua_State *L){
	get_material_index(L, 1);
	return 1;
}

static int
linstance_get_state(lua_State *L){
	const int mat_idx = get_material_index(L, 1);	//push material object
	struct material * mat = (struct material*)lua_touserdata(L, mat_idx);
	lua_pop(L, 1); // pop material object
	return push_material_state(L, mat);
}

static inline void
clear_material_attribs(lua_State *L, int mat_idx){
	struct attrib_arena * arena = to_arena(L, get_cobject_index(L, mat_idx));
	lua_pop(L, 1);
	vla_handle_t hlist = get_invalid_list_handle(L, mat_idx);
	clear_unused_attribs(L, arena, hlist);
}

static int
lmaterial_instance(lua_State *L) {
	clear_material_attribs(L, 1);

	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), INSTANCE_UV_NUM);
	mi->patch_attrib = INVALID_ATTRIB;
	vla_lua_new(L, 0, sizeof(uint16_t));
	verfiy(lua_setiuservalue(L, -2, INSTANCE_UV_INVALID_LIST));
	lua_pushvalue(L, 1);
	verfiy(lua_setiuservalue(L, -2, INSTANCE_UV_MATERIAL));

	if (luaL_newmetatable(L, "ANT_INSTANCE_MT")){
		luaL_Reg l[] = {
			{ "__gc", 			linstance_gc		},
			{ "__newindex", 	linstance_set_attrib},
			{ "__call", 		linstance_apply_attrib},
			{ "get_material",	linstance_get_material},
			{ "get_state",		linstance_get_state},
			{ NULL, 		NULL },
		};

		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static inline uint16_t
fetch_material_attrib_value(lua_State *L, struct attrib_arena* arena, int arena_idx, 
	int sa_lookup_idx, int lookup_idx, const char*key, uint16_t lastid){
	if (LUA_TNIL != lua_getfield(L, sa_lookup_idx, key)){
		attrib_type* a = arena_alloc(L, arena_idx);
		a->h.type = ATTRIB_REF;
		a->ref.id = (uint16_t)lua_tointeger(L, -1);
		a->h.next = lastid;
		lastid = al_attrib_id(arena, a);
		lua_pop(L, 1);
	} else {
		lua_pop(L, 1);
		lastid = load_attrib_from_data(L, arena_idx, -1, lastid);
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
			{ "copy",		(issubtype ? NULL : lmaterial_copy)},
			{ NULL, 		NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
}

//material type user value:
//1. cobject
//2. material lut
static int
lmaterial_copy(lua_State *L){
	struct material* temp_mat = (struct material*)lua_touserdata(L, 1);
	struct material* new_mat = (struct material*)lua_newuserdatauv(L, sizeof(*new_mat), MATERIAL_UV_NUM);
	new_mat->attrib = temp_mat->attrib;
	if (!lua_isnoneornil(L, 2)){
		get_state(L, 2, &new_mat->state, &new_mat->rgba);
	} else {
		new_mat->state = temp_mat->state;
		new_mat->rgba = temp_mat->rgba;
	}

	//uv1
	lua_getiuservalue(L, 1, MATERIAL_UV_COBJECT);
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_COBJECT));

	//uv2
	lua_getiuservalue(L, 1, MATERIAL_UV_LUT);
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_LUT));

	//uv3
	vla_lua_new(L, 0, sizeof(uint16_t));
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_INVALID_LIST));

	set_material_matatable(L, "ANT_MATERIAL_TYPE", 1);

	return 1;
}

// 1: cobject
// 2: render state (string)
// 3: uniforms (table)
static int
lmaterial_new(lua_State *L) {
	const int arena_idx = 1;
	CAPI_INIT(L, arena_idx);
	uint64_t state;
	uint32_t rgba;
	get_state(L, 2, &state, &rgba);
	lua_settop(L, 3);
	struct attrib_arena * arena = CAPI_ARENA;
	struct material *mat = (struct material *)lua_newuserdatauv(L, sizeof(*mat), MATERIAL_UV_NUM);

	lua_pushvalue(L, 1);
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_COBJECT));			// push cobject as uv2

	mat->state = state;
	mat->rgba = rgba;
	mat->attrib = INVALID_ATTRIB;

	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);

	//system attrib table
	if (lua_getiuservalue(L, arena_idx, COBJECT_UV_SYSTEM_ATTRIBS) != LUA_TTABLE){
		luaL_error(L, "Invalid cobject");
	}
	const int sa_lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 3) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		mat->attrib = fetch_material_attrib_value(L, arena, arena_idx, sa_lookup_idx, lookup_idx, key, mat->attrib);
	}
	lua_pop(L, 1);	//system attrib table

	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_LUT));	// push lookup table as uv3

	vla_lua_new(L, 0, sizeof(uint16_t));
	verfiy(lua_setiuservalue(L, -2, MATERIAL_UV_INVALID_LIST));

	set_material_matatable(L, "ANT_MATERIAL", 0);
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
lcolor_palette_new(lua_State *L){
	struct attrib_arena* arena = to_arena(L, 1);
	if (!lua_isnoneornil(L, 2)){
		luaL_checktype(L, 2, LUA_TTABLE);
		const int n = (int)lua_rawlen(L, 2);
		if (n > MAX_COLOR_IN_PALETTE){
			return luaL_error(L, "Too many color for palette, max number is:%d", MAX_COLOR_IN_PALETTE);
		}
		struct color_palette* cp = arena->color_palettes + arena->cp_idx;
		for (int i=0; i<n; ++i){
			lua_geti(L, 2, i+1);
			const float *v = math3d_from_lua(L, arena->math, -1, LINEAR_TYPE_VEC4);
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
	const uint16_t id = (uint16_t)lua_tointeger(L, -1);
	const int arena_idx = lua_upvalueindex(1);
	struct attrib_arena* arena = to_arena(L, arena_idx);
	attrib_type* a = al_attrib(arena, id);
	update_attrib(L, arena, a, 3);
	lua_pop(L, 1);
	return 0;
}

static int
lsystem_attribs_new(lua_State *L){
	const int arena_idx = 1;
	luaL_checktype(L, 2, LUA_TTABLE);

	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 2) != 0; lua_pop(L, 1)) {
		const char* name = lua_tostring(L, -2);
		const uint16_t id = load_attrib_from_data(L, arena_idx, -1, INVALID_ATTRIB);
		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, name);
	}

	if (luaL_newmetatable(L, "ANT_SYSTEM_ATTRIBS")){
		luaL_Reg l[] = {
			{"update", 	lsa_update},
			{NULL,		NULL},
		};
		lua_pushvalue(L, 1);	//push cobject as upvalue 1
		luaL_setfuncs(L, l , 1);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);

	lua_pushvalue(L, -1);		// system attrib table
	verfiy(lua_setiuservalue(L, 1, COBJECT_UV_SYSTEM_ATTRIBS));	// set system attrib table as cobject 1 user value
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
	struct attrib_arena* arena = to_arena(L, 1);
	const struct color* c = get_color(L, arena, 2, 3);
	math3d_push(L, arena->math, c->rgba, LINEAR_TYPE_VEC4);
	return 1;
}

static int
lcolor_palette_set(lua_State *L){
	struct attrib_arena* arena = to_arena(L, 1);
	struct color* c = get_color(L, arena, 2, 3);

	const float* v = math3d_from_lua(L, arena->math, 4, LINEAR_TYPE_VEC4);
	memcpy(c->rgba, v, sizeof(c->rgba));
	return 0;
}

LUAMOD_API int
luaopen_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "cobject", 		lcobject_new },
		{ "material",		lmaterial_new},
		{ "system_attribs", lsystem_attribs_new},
		{ "color_palette",	lcolor_palette_new},
		{ "color_palette_get",lcolor_palette_get},
		{ "color_palette_set",lcolor_palette_set},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

