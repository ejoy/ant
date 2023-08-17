#include "lua.hpp"
#include "ecs/world.h"

extern "C"{
	#include "math3d.h"
	#include "textureman.h"
	#include "programan.h"
}

#include <cstdint>
#include <cstring>
#include <cassert>

#include <bgfx/c99/bgfx.h>
#include <luabgfx.h>

#include <string>
#include <unordered_map>

static int s_key;
#define ATTRIB_ARENA (void*)(&s_key)

#if !defined(MATERIAL_DEBUG)
#define MATERIAL_DEBUG 0
#endif

#if MATERIAL_DEBUG
#define verfiy(_CON)	assert(_CON)
#else //!MATERIAL_DEBUG
#define verfiy(_CON)	_CON
#endif //MATERIAL_DEBUG


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
	uint8_t 		stage;
	bgfx_access_t	access;
	uint8_t			mip;
	uint32_t		handle;
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

using attrib_map = std::unordered_map<std::string, attrib_id>;

struct attrib_arena {
	uint16_t cap;
	uint16_t n;
	attrib_id freelist;
	uint16_t cp_idx;
	attrib_type *a;
	struct color_palette color_palettes[MAX_COLOR_PALETTE_COUNT];
	attrib_map	sa_lut;
};

struct material_state {
	uint64_t state;
	uint64_t stencil;
	uint32_t rgba;
};

struct material {
	struct material_state	state;
	attrib_id				attrib;
	int 					prog;
	attrib_map				attrib_lut;
};

struct material_instance {
	struct material *m;
	struct material_state patch_state;
	attrib_id patch_attrib;
};

static inline void
check_ecs_world_in_upvalue1(lua_State *L){
	getworld(L);
}

static int
larena_init(lua_State *L) {
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), 0);
	new (&a->sa_lut) attrib_map();
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
	a->cp_idx = 0;
	memset(&a->color_palettes, 0, sizeof(a->color_palettes));
	lua_rawsetp(L, LUA_REGISTRYINDEX, ATTRIB_ARENA);
	return 0;
}

static inline struct attrib_arena*
arena_from_reg(lua_State *L){
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, ATTRIB_ARENA) != LUA_TUSERDATA){
		luaL_error(L, "Not found C API in reg table");
	}
	struct attrib_arena *arena = (struct attrib_arena *)lua_touserdata(L, -1);
	if (arena == NULL)
		luaL_error(L, "Invalid C API");
	lua_pop(L, 1);
	return arena;
}

static int
larena_release(lua_State *L){
	auto arean = arena_from_reg(L);
	arean->sa_lut.~attrib_map();
	arean->freelist = INVALID_ATTRIB;
	if (arean->a){
		free(arean->a);
		arean->a = nullptr;
	}
	return 0;
}

//attrib list: al_*///////////////////////////////////////////////////////////
static inline void
al_init_attrib(struct attrib_arena* arena, attrib_type *a){
	(void)arena;

	a->h.type 		= ATTRIB_NONE;
	a->h.next 		= INVALID_ATTRIB;
	a->h.patch 		= INVALID_ATTRIB;
	a->u.handle		= BGFX_INVALID_HANDLE;
	a->u.m 			= MATH_NULL;
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

static inline attrib_id
al_attrib_next_id(struct attrib_arena *arena, attrib_id id){
	return al_attrib(arena, id)->h.next;
}

static inline int
is_uniform_attrib(uint16_t type){
	return type == ATTRIB_UNIFORM || type == ATTRIB_SAMPLER || type == ATTRIB_COLOR_PAL;
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
	for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_id(arena, pid)){
		attrib_type *pa = al_attrib(arena, pid);
		if (pa->h.patch == id)
			return pid;
	}

	return INVALID_ATTRIB;
}

/////////////////////////////////////////////////////////////////////////////
attrib_type *
arena_alloc(lua_State *L) {
	struct attrib_arena * arena = arena_from_reg(L);
	attrib_type *ret;
	if (arena->freelist != INVALID_ATTRIB) {
		ret = al_attrib(arena, arena->freelist);
		arena->freelist = ret->h.next;
	} else if (arena->n < arena->cap) {
		ret = al_attrib(arena, arena->n);
		arena->n++;
	} else if (arena->cap == 0) {
		assert(arena->a == nullptr);
		arena->a = (attrib_type *)malloc(sizeof(attrib_type) * DEFAULT_ARENA_SIZE);
		arena->cap = DEFAULT_ARENA_SIZE;
		arena->n = 1;
		ret = arena->a;
	} else {
		// resize arena
		int newcap = arena->cap * 2;
		if (newcap > MAX_ATTRIB_CAPS)
			luaL_error(L, "Too many attribs");

		arena->a = (attrib_type *)realloc(arena->a, sizeof(attrib_type) * newcap);
		arena->cap = newcap;
		ret = al_attrib(arena, arena->n++);
		
	}
	al_init_attrib(arena, ret);
	return ret;
}

static void
clear_unused_attribs(lua_State *L, struct attrib_arena *arena, attrib_id id) {
	struct ecs_world * w = getworld(L);
	do {
		id = al_attrib_clear(arena, w, id);
	} while (id != INVALID_ATTRIB);
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
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			assert(a->h.type != ATTRIB_UNIFORM || math_size(w->math3d->M, a->u.m) <= info.num);
			lua_createtable(L, 0, 0);

			lua_pushstring(L, info.name);
			lua_setfield(L, -2, "name");

			uniform_value(L, a);
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

static inline struct material *
MO(lua_State *L, int index){
	return (struct material *)luaL_checkudata(L, index, "ANT_MATERIAL");
}

// 1: material
static int
lmaterial_attribs(lua_State *L) {
	struct attrib_arena *arena = arena_from_reg(L);
	struct material* mat = MO(L, 1);
	lua_settop(L, 1);
	lua_newtable(L);
	int result_index = lua_gettop(L);

	struct ecs_world* w = getworld(L);
	int idx = 1;
	for (attrib_id id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)) {
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
	static const char *hex = "0123456789ABCDEF";
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

	ms->stencil = (uint64_t)luaL_checkinteger(L, idx);
}

static void
unset_instance_attrib(lua_State* L, struct material_instance *mi, struct attrib_arena *arena, attrib_type *a) {
	attrib_id ref = mi_find_patch_attrib(arena, mi, al_attrib_id(arena, a));
	struct ecs_world* w = getworld(L);
	if (ref != INVALID_ATTRIB){
		al_attrib_clear(arena, w, ref);
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
			luaL_error(L, "Not support table array, use math3d.array_[matrix/vector] instead");
			return ATTRIB_NONE;
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

static inline bgfx_access_t
fetch_access(lua_State *L, int index){
	if (LUA_TSTRING != lua_getfield(L, index, "access")){
		luaL_error(L, "Invalid image/buffer 'access' field, r/w/rw is required");
	}
	const char* s = lua_tostring(L, -1);
	bgfx_access_t access = BGFX_ACCESS_COUNT;
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

static inline attrib_id
create_attrib(lua_State *L, struct attrib_arena* arena, attrib_id id, uint16_t attribtype, bgfx_uniform_handle_t h){
	attrib_type* na = arena_alloc(L);
	na->h.type = attribtype;
	na->h.next = id;
	if (is_uniform_attrib(attribtype)){
		na->u.handle = h;
	}
	return al_attrib_id(arena, na);
}

static void
update_attrib(lua_State *L, struct attrib_arena *arena, attrib_type *a, int index) {
	switch (a->h.type){
		case ATTRIB_UNIFORM:	fetch_math_value(L, a, index);						break;
		case ATTRIB_SAMPLER:	fetch_sampler(L, a, index);							break;
		case ATTRIB_IMAGE:		fetch_image(L, a, index);							break;
		case ATTRIB_BUFFER:		fetch_buffer(L, a, index);							break;
		case ATTRIB_COLOR_PAL:	fetch_color_pal(L, a, index);						break;
		default: luaL_error(L, "Attribute type:%d, could not update", a->h.type);	break;
	}
}

static attrib_id
load_attrib_from_data(lua_State *L, struct attrib_arena* arena, int data_index, attrib_id id) {
	const uint16_t type = fetch_attrib_type(L, data_index);
	const bgfx_uniform_handle_t h = {is_uniform_attrib(type) ? fetch_handle(L, data_index).idx : (uint16_t)UINT16_MAX};
	attrib_id nid = create_attrib(L, arena, id, type, h);
	update_attrib(L, arena, al_attrib(arena, nid), data_index);
	return nid;
}

static int
lmaterial_set_attrib(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	struct attrib_arena* arena = arena_from_reg(L);

	const char* attribname = luaL_checkstring(L, 2);

	auto itfound = mat->attrib_lut.find(attribname);
	if (mat->attrib_lut.end() == itfound){
		mat->attrib = load_attrib_from_data(L, arena, 3, mat->attrib);
		mat->attrib_lut[attribname] = mat->attrib;
	} else {
		const attrib_id id = itfound->second;
		update_attrib(L, arena, al_attrib(arena, id), 3);
	}
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
	lua_pushinteger(L, stencil);
	return 1;
}

static int
lmaterial_get_state(lua_State *L){
	struct material* mat = MO(L, 1);
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

static inline void
init_instance_attrib(struct attrib_arena* arena, attrib_id pid, attrib_id id){
	attrib_type* a = al_attrib(arena, id);
	attrib_type* pa = al_attrib(arena, pid);
	pa->h.patch = id;

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
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, attrib_type * a, int value_index) {
	const attrib_id id = al_attrib_id(arena, a);
	attrib_id pid = mi_find_patch_attrib(arena, mi, id);
	if (pid == INVALID_ATTRIB) {
		pid = create_attrib(L, arena, mi->patch_attrib, a->h.type, a->u.handle);
		init_instance_attrib(arena, pid, id);
		mi->patch_attrib = pid;
	}
	update_attrib(L, arena, al_attrib(arena, pid), value_index);
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
	const char* attribname = luaL_checkstring(L, 2);
	auto itfound = mi->m->attrib_lut.find(attribname);
	if (itfound == mi->m->attrib_lut.end()){
		luaL_error(L, "Invalid attribute name:", attribname);
	}

	const attrib_id id = itfound->second;

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

static int
lmaterial_release(lua_State *L){
	const auto mo = MO(L, 1);
	if (0 == mo->prog){
		auto arena = arena_from_reg(L);
		if (mo->attrib != INVALID_ATTRIB){
			clear_unused_attribs(L, arena, mo->attrib);
			mo->attrib = INVALID_ATTRIB;
		}
		
		mo->prog = 0;
		mo->attrib_lut.~attrib_map();
	}

	return 0;
}

static int
lmaterial_gc(lua_State *L) {
	return lmaterial_release(L);
}

static int
linstance_release(lua_State *L) {
	struct material_instance * mi = to_instance(L, 1);
	if (mi->m){
		auto arena = arena_from_reg(L);
		if (mi->patch_attrib != INVALID_ATTRIB) {
			clear_unused_attribs(L, arena, mi->patch_attrib);
			mi->patch_attrib = INVALID_ATTRIB;
		}

		mi->m = nullptr;
	}
	return 0;
}

#define MAX_UNIFORM_NUM 1024

static inline bgfx_texture_handle_t
check_get_texture_handle(lua_State *L, uint32_t handle){
	if ((0xffff0000 & handle) == 0){
		return texture_get((int)handle);
	}
	
	return bgfx_texture_handle_t{(uint16_t)handle};
}

static void
apply_attrib(lua_State *L, struct attrib_arena * arena, struct ecs_world* w, attrib_type *a) {
	switch(a->h.type){
		case ATTRIB_REF:
			apply_attrib(L, arena, w, al_attrib(arena, a->ref.id));
			break;
		case ATTRIB_SAMPLER: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(L, a->u.t.handle);
			#if MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //MATERIAL_DEBUG
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
			#ifdef MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //MATERIAL_DEBUG

			struct color_palette* cp = arena->color_palettes + a->u.cp.pal;
			struct color* c = cp->colors+a->u.cp.color;
			BGFX(encoder_set_uniform)(w->holder->encoder, a->u.handle, c->rgba, 1);
		}	break;
		case ATTRIB_UNIFORM: {
			const int n = math_size(w->math3d->M, a->u.m);
			#ifdef MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			assert(n <= info.num);
			#endif //MATERIAL_DEBUG
			BGFX(encoder_set_uniform)(w->holder->encoder, a->u.handle, math_value(w->math3d->M, a->u.m), n);
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
	int idx = 1;
	for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_id(arena, pid)){
		push_attrib_value(L, arena, w, pid);
		lua_seti(L, -2, idx++);
	}
	
	return 1;
}

extern "C" void
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
		for (attrib_id id = mi->m->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)){
			attrib_type* a = al_attrib(arena, id);
			apply_attrib(L, arena, w, a);
		}
	} else {
		for (attrib_id id = mi->m->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)){
			attrib_id apply_id = id;
			for (attrib_id pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_id(arena, pid)){
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

extern "C" bgfx_program_handle_t
material_prog(lua_State *L, struct material_instance *mi){
	(void)L;
	return program_get(mi->m->prog);
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

static int
lmaterial_instance(lua_State *L) {
	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), 0);
	mi->patch_attrib = INVALID_ATTRIB;
	mi->patch_state.state = 0;
	mi->patch_state.stencil = 0;
	mi->patch_state.rgba = 0;
	mi->m = MO(L, 1);

	if (luaL_newmetatable(L, "ANT_INSTANCE_MT")){
		luaL_Reg l[] = {
			{ "__newindex", 	linstance_set_attrib},
			{ "__call", 		linstance_apply_attrib},
			{ "release",		linstance_release},
			{ "attribs",		linstance_attribs},

			{ "get_state",		linstance_get_state},
			{ "set_state",		linstance_set_state},
			{ "get_stencil",	linstance_get_stencil},
			{ "set_stencil",	linstance_set_stencil},

			{ "ptr",			linstance_ptr},
			{ nullptr, 			nullptr },
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
fetch_material_attrib_value(lua_State *L, struct attrib_arena* arena, int data_idx,
	const char*key, attrib_id lastid){
	auto itfound = arena->sa_lut.find(key);
	if (arena->sa_lut.end() != itfound){
		attrib_type* a = arena_alloc(L);
		a->h.type = ATTRIB_REF;
		a->ref.id = itfound->second;
		a->h.next = lastid;
		lastid = al_attrib_id(arena, a);
	} else {
		lastid = load_attrib_from_data(L, arena, data_idx, lastid);
	}
	return lastid;
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
	struct material *mat = (struct material *)lua_newuserdatauv(L, sizeof(*mat), 0);
	new (&mat->attrib_lut) attrib_map();

	mat->state = state;

	mat->attrib = INVALID_ATTRIB;
	mat->prog = (int)luaL_checkinteger(L, 4);
	if (0 == mat->prog){
		luaL_error(L, "Invalid prog index");
	}
	if (luaL_newmetatable(L, "ANT_MATERIAL")) {
		luaL_Reg l[] = {
			{ "__gc",					lmaterial_gc},
			{ "release",				lmaterial_release},
			{ "attribs", 				lmaterial_attribs },
			{ "instance", 				lmaterial_instance },
			{ "set_attrib",				lmaterial_set_attrib},
			{ "get_state",				lmaterial_get_state},
			{ "set_state",				lmaterial_set_state},
			{ "fetch_material_stencil",	lmaterial_get_stencil},
			{ "set_stencil",			lmaterial_set_stencil},
			{ nullptr,					nullptr},
		};
		check_ecs_world_in_upvalue1(L);
		lua_pushvalue(L, lua_upvalueindex(1));
		luaL_setfuncs(L, l, 1);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);

	struct attrib_arena* arena = arena_from_reg(L);

	const int properties_idx = 3;
	for (lua_pushnil(L); lua_next(L, properties_idx) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		mat->attrib = fetch_material_attrib_value(L, arena, -1, key, mat->attrib);
		mat->attrib_lut[key] = mat->attrib;
	}

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
	const auto arena = arena_from_reg(L);

	luaL_checktype(L, 1, LUA_TTABLE);
	const char* name = luaL_checkstring(L, 2);
	auto itfound = arena->sa_lut.find(name);
	if (arena->sa_lut.end() == itfound){
		return luaL_error(L, "Invalid system attrib:%s", name);
	}
	const attrib_id id = itfound->second;
	attrib_type* a = al_attrib(arena, id);
	update_attrib(L, arena, a, 3);
	return 0;
}

static int
lsystem_attribs_new(lua_State *L){
	struct attrib_arena* arena = arena_from_reg(L);
	luaL_checktype(L, 1, LUA_TTABLE);

	for (lua_pushnil(L); lua_next(L, 1) != 0; lua_pop(L, 1)) {
		const char* name = lua_tostring(L, -2);
		assert(arena->sa_lut.end() == arena->sa_lut.find(name));
		arena->sa_lut[name] = load_attrib_from_data(L, arena, -1, INVALID_ATTRIB);
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

extern "C" int
luaopen_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init",			larena_init},
		{ "release",		larena_release},
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
	return 1;
}

