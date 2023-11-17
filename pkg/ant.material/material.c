#include "lua.h"
#include "lauxlib.h"
#include "material.h"
#include "ecs/world.h"

#include "math3d.h"
#include "textureman.h"
#include "programan.h"

#include "material_arena.h"

#include <bgfx/c99/bgfx.h>
#include <luabgfx.h>
#include <stdlib.h>
#include <string.h>

#define MAX_ATTRIB 1024

struct material_state {
	uint64_t state;
	uint64_t stencil;
	uint32_t rgba;
};

struct material {
	struct attrib_arena     *A;
	struct material_state	state;
	uint64_t				global[MATERIAL_SYSTEM_ATTRIB_CHUNK];
	attrib_id				attrib;
	int 					prog;
};

struct material_instance {
	struct material *m;
	struct material_state patch_state;
	attrib_id patch_attrib;
};

static int
larena_new(lua_State *L) {
	struct attrib_arena *A = (struct attrib_arena *)lua_newuserdatauv(L, attrib_arena_size(), 0);
	attrib_arena_init(A);
	return 1;
}

static inline uint8_t
fetch_attrib_type(lua_State *L, int index) {
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

	switch (c) {
		case 't': return ATTRIB_SAMPLER;
		case 'i': return ATTRIB_IMAGE;
		case 'b': return ATTRIB_BUFFER;
		case 'u':
		default: return ATTRIB_UNIFORM;
	}
}

static inline void
fetch_math_type(lua_State *L, int index, int *n, int *elem) {
	luaL_checktype(L, index, LUA_TTABLE);
	if (lua_getfield(L, index, "utype") != LUA_TSTRING)
		luaL_error(L, "Invalid uniform type 'utype' field");
	const char * utype = lua_tostring(L, -1);
	int scale = 1;
	if (utype[0] == 'm')
		scale = 4;
	else if (utype[0] != 'v')
		luaL_error(L, "Invalid .utype %s", utype);
	int e = 0;
	int i;
	for (i=1;utype[i];i++) {
		if (utype[i] >= '0' || utype[i] <= '9') {
			e = e * 10 + utype[i] - '0';
		}
	}
	if (e == 0)
		e = 1;
	*n = e * scale;
	*elem = e;
	lua_pop(L, 1);
}

static inline const float *
fetch_math_value(lua_State *L, int index, int *n) {
	luaL_checktype(L, index, LUA_TTABLE);
	if (lua_getfield(L, index, "value") != LUA_TSTRING) {
		luaL_error(L, "Invalid math uniform 'value' field, math3d value must be float packed string");
	}
	size_t sz;
	const float * f = (const float *)lua_tolstring(L, -1, &sz);
	if (sz % 16 != 0) {
		luaL_error(L, "Invalid math uniform 'value' field, should be float4 packed string, size = %d", (int)sz);
	}
	*n = (int)sz / 16;
	lua_pop(L, 1);
	return f;
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

static inline uint32_t
fetch_sampler(lua_State *L, int index, int *stage) {
	const int lt = lua_type(L, index);
	if (lt == LUA_TTABLE) {
		*stage = fetch_stage(L, index);
		return fetch_value_handle(L, index);
	} else {
		*stage = 0;
		if (lt == LUA_TNUMBER)
			return (uint32_t)luaL_checkinteger(L, index);
		else
		return luaL_error(L, "Invalid type for 'texture':%s, bgfx texture handle or table:{stage=0, value=bgfxhandle}", lua_typename(L, lt));
	}
}

static inline uint8_t
fetch_mip(lua_State *L, int index){
	if (LUA_TNUMBER != lua_getfield(L, index, "mip")) {
		luaL_error(L, "Invalid image 'mip' field, number is need");
	}
	const uint8_t mip = (uint8_t)lua_tointeger(L, -1);
	lua_pop(L, 1);
	return mip;
}

static inline bgfx_access_t
fetch_access(lua_State *L, int index) {
	if (LUA_TSTRING != lua_getfield(L, index, "access")){
		luaL_error(L, "Invalid image/buffer 'access' field, r/w/rw is required");
	}
	const char* s = lua_tostring(L, -1);
	int access = 0;
	int i;
	for (i=0;s[i];i++) {
		if (s[i] == 'r')
			access |= 1;
		else if (s[i] == 'w')
			access |= 2;
		else
			luaL_error(L, "Invalid access type:%s", s);
	}
	lua_pop(L, 1);	// access
	switch(access) {
	case 1:
		return BGFX_ACCESS_READ;
	case 2:
		return BGFX_ACCESS_WRITE;
	case 3:
		return BGFX_ACCESS_READWRITE;
	default:
		luaL_error(L, "Invalid access type:%s", s);
		return BGFX_ACCESS_COUNT;
	}
}

static inline uint32_t
fetch_resource(lua_State *L, int index, int *mip, bgfx_access_t *access, uint8_t *stage) {
	const int lt = lua_type(L, index);
	if (lt == LUA_TTABLE) {
		if (mip) *mip = fetch_mip(L, index);
		*access	= fetch_access(L, index);
		*stage	= fetch_stage(L, index);
		return fetch_value_handle(L, index);
	} else {
		if (mip) *mip = 0;
		*access = BGFX_ACCESS_READ;
		*stage = 0;
		if (lt == LUA_TNUMBER)
			return (uint32_t)luaL_checkinteger(L, index);
		else
			return luaL_error(L, "Invalid type for 'resource':%s, bgfx texture handle or table:{stage=0, value=bgfxhandle, mip=0, access='r'}", lua_typename(L, lt));
	}
}

static void
init_attrib(lua_State *L, struct attrib_arena *A, int id, int index) {
	int t = fetch_attrib_type(L, index);
	switch (t) {
	case ATTRIB_UNIFORM: {
		bgfx_uniform_handle_t h = fetch_handle(L, index);
		int n, elem, vn;
		fetch_math_type(L, index, &n, &elem);
		const float * v = fetch_math_value(L, index, &vn);
		if (vn != n)
			luaL_error(L, "Invalid math uniform 'value' size (%d != %d)", n, vn);
		const char * err = attrib_arena_init_uniform(A, id, h, v, n, elem);
		if (err)
			luaL_error(L, "Init uniform error : %s", err);
		break;
	}
	case ATTRIB_SAMPLER: {
		int stage = 0;
		bgfx_uniform_handle_t h = fetch_handle(L, index);
		uint32_t handle = fetch_sampler(L, index, &stage);
		const char * err = attrib_arena_init_sampler(A, id, h, handle, stage);
		if (err)
			luaL_error(L, "Init sampler error : %s", err);
		break;
	}
	case ATTRIB_BUFFER:{
		uint8_t stage; bgfx_access_t access;
		uint32_t handle = fetch_resource(L, index, NULL, &access, &stage);
		const char* err = attrib_arena_init_buffer(A, id, handle, stage, access);
		if (err)
			luaL_error(L, "Init buffer error : %s", err);
		break;
	}
	case ATTRIB_IMAGE: {
		int mip; uint8_t stage; bgfx_access_t access;
		uint32_t handle = fetch_resource(L, index, &mip, &access, &stage);
		const char *err = attrib_arena_init_image(A, id, handle, stage, access, mip);
		if (err)
			luaL_error(L, "Init image error : %s", err);
		break;
	}
	default: luaL_error(L, "Attribute type:%d, could not update", t);	break;
	}
}

// 1: arena
// 2: global id (base 1)
// 3: attrib value
static int
larena_system_attrib(lua_State *L) {
	struct attrib_arena *A = (struct attrib_arena *)lua_touserdata(L, 1);
	int id = (int)luaL_checkinteger(L, 2);
	if (id < 1)
		return luaL_error(L, "Invalid system attrib id %d", id);
	init_attrib(L, A, -id, 3);
	return 0;
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
fetch_system_attrib_set(lua_State *L, int index, uint64_t *set) {
	int max_id = MATERIAL_SYSTEM_ATTRIB_CHUNK * 64;
	luaL_checktype(L, index, LUA_TTABLE);
	int n = (int)lua_rawlen(L, index);
	memset(set, 0, sizeof(*set) * MATERIAL_SYSTEM_ATTRIB_CHUNK);
	int i;
	for (i=0;i<n;i++) {
		lua_geti(L, index, i+1);
		int id = (int)luaL_checkinteger(L, -1);
		if (id <= 0 || id > max_id)
			luaL_error(L, "Invalid system attrib id %d", id);
		lua_pop(L, 1);
		--id;
		int idx = id / 64;
		int shift = id % 64;
		set[idx] |= (uint64_t)(1 << shift);
	}
}

static inline int
compar_int(const void *a, const void *b) {
	const int *aa = (const int *)a;
	const int *bb = (const int *)b;
	return *aa - *bb;
}

// 1: arena
// 2: render state (string)
// 3: stencil (int64)
// 4: program id
// 5: system attrib set
// 6: attrib table (keyid -> attrib)
// ret: userdata material
static int
lmaterial_new(lua_State *L) {
	struct attrib_arena *A = (struct attrib_arena *)lua_touserdata(L, 1);
	lua_settop(L, 6);
	struct material *m = (struct material *)lua_newuserdatauv(L, sizeof(*m), 0);
	m->A = A;

	fetch_material_state(L, 2, &m->state);
	fetch_material_stencil(L, 3, &m->state);
	m->prog = (int)luaL_checkinteger(L, 4);

	// base 1 array [1, MATERIAL_SYSTEM_ATTRIB_CHUNK * 64]
	fetch_system_attrib_set(L, 5, m->global);

	luaL_checktype(L, 6, LUA_TTABLE);
	int key[MAX_ATTRIB];
	int key_n = 0;
	lua_pushnil(L);
	while (lua_next(L, 6) != 0) {
		if (key_n >= MAX_ATTRIB)
			return luaL_error(L, "Too many attrib %d", key_n);
		key[key_n] = (int)luaL_checkinteger(L, -2);
		if (key[key_n] <= 0)
			return luaL_error(L, "Invalid key id %d", key[key_n]);
		lua_pop(L, 1);
		++key_n;
	}

	if (key_n == 0) {
		m->attrib = INVALID_ATTRIB;
		return 1;
	}

	qsort(key, key_n, sizeof(int), compar_int);

	int top = lua_gettop(L) + 1;

	int prev = -1;

	int i;
	for (i=0;i<key_n;i++) {
		int current = attrib_arena_new(A, prev, key[i]);
		if (current < 0)
			return luaL_error(L, "Too many attribs");
		if (i == 0)
			m->attrib = (attrib_id)current;
		lua_geti(L, 6, key[i]);
		init_attrib(L, A, current, top);
		lua_pop(L, 1);
		prev = current;
	}
	return 1;
}

int
luaopen_material_arena(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "arena",			larena_new },
		{ "system_attrib",  larena_system_attrib},
		{ "material",       lmaterial_new},
		{ NULL, 			NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

static inline struct material *
MO(lua_State *L, int index) {
	return (struct material *)lua_touserdata(L, index);
}

static inline struct material_instance*
to_instance(lua_State *L, int instanceidx){
	return (struct material_instance*)lua_touserdata(L, instanceidx);
}

static inline void
check_ecs_world_in_upvalue1(lua_State *L){
	getworld(L);
}

static inline math_t
fetch_math_id(lua_State *L, struct ecs_world* w, int index) {
	return math3d_from_lua_id(L, w->math3d, index);
}

static void
set_attrib(lua_State *L, struct attrib_arena *A, int id, int index) {
	int t = attrib_arena_type(A, id);
	//int lt = fetch_attrib_type(L, index);
	switch (t) {
	case ATTRIB_UNIFORM:
	case ATTRIB_UNIFORM_INSTANCE: {
		int lt = fetch_attrib_type(L, index);
		if (lt != ATTRIB_UNIFORM)
			luaL_error(L, "Invalid attrib %d , need uniform", id);
		struct ecs_world* w = getworld(L);
		math_t m = fetch_math_id(L, w, index);
		if (t == ATTRIB_UNIFORM_INSTANCE) {
			m = attrib_arena_set_uniform_instance(A, id, math_mark(w->math3d->M, m));
			math_unmark(w->math3d->M, m);
		} else {
			const float *v = math_value(w->math3d->M, m);
			attrib_arena_set_uniform(A, id, v);
		}
		break;
	}
	case ATTRIB_SAMPLER:
	case ATTRIB_IMAGE:
	case ATTRIB_BUFFER:
		if (lua_type(L, index) == LUA_TNUMBER) {
			uint32_t handle = (uint32_t)lua_tointeger(L, index);
			attrib_arena_set_handle(A, id, handle);
		} else {
			int lt = fetch_attrib_type(L, index);
			if (t != lt) {
				luaL_error(L, "Invalid attrib %d (%d != %d)", id, t , lt);
			}

			if (t == ATTRIB_SAMPLER) {
				int stage;
				uint32_t handle = fetch_sampler(L, index, &stage);
				attrib_arena_set_sampler(A, id, handle, stage);
			} else {
				int mip = 0;
				bgfx_access_t access;
				uint8_t stage;
				uint32_t handle = fetch_resource(L, index, t == ATTRIB_BUFFER ? NULL : &mip, &access, &stage);
				attrib_arena_set_resource(A, id, handle, stage, access, mip);
			}
		}
		break;
	case ATTRIB_NONE:
	default:
		luaL_error(L, "Invalid attrib %d", id);
	}
}

static int
linstance_set_attrib(lua_State *L) {
	lua_pushvalue(L, 2);
	if (lua_type(L, 2) != LUA_TSTRING) {
		return luaL_error(L, "Need string key, it's %s", lua_typename(L, lua_type(L, 2)));
	}
	if (lua_gettable(L, lua_upvalueindex(2)) != LUA_TNUMBER) {
		return luaL_error(L, "No attrib %s", lua_tostring(L, 2));
	}
	int key = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	struct material_instance* mi = to_instance(L, 1);
	struct attrib_arena *A = mi->m->A;
	attrib_id prev = INVALID_ATTRIB;
	if (mi->patch_attrib != INVALID_ATTRIB) {
		attrib_id id = attrib_arena_find(A, mi->patch_attrib, key, &prev);
		if (id != INVALID_ATTRIB) {
			if (lua_isnil(L, 3)) {
				// unset patch
				attrib_id next = attrib_arena_delete(A, prev, id);
				if (prev == INVALID_ATTRIB) {
					mi->patch_attrib = next;
				}
			} else {
				set_attrib(L, A, id, 3);
			}
			return 0;
		}
	}
	if (lua_isnil(L, 3))	// ignore nil
		return 0;
	// patch after prev
	attrib_id dummy;
	attrib_id id = attrib_arena_find(A, mi->m->attrib, key, &dummy);
	if (id == INVALID_ATTRIB) {
		return luaL_error(L, "No attrib %s in instance", lua_tostring(L, 2));
	}
	attrib_id patch = attrib_arena_clone(A, prev, mi->patch_attrib, id);
	if (patch == INVALID_ATTRIB)
		return luaL_error(L, "Clone attrib %s fail", lua_tostring(L, 2));
	if (prev == INVALID_ATTRIB)
		mi->patch_attrib = patch;
	set_attrib(L, A, patch, 3);
	return 0;
}

#define BGFX(api) w->bgfx->api

void
apply_material_instance(lua_State *L, struct material_instance *mi, struct ecs_world *w) {
	BGFX(encoder_set_state)(w->holder->encoder, 
		(mi->patch_state.state == 0 ? mi->m->state.state : mi->patch_state.state), 
		(mi->patch_state.rgba == 0 ? mi->m->state.rgba : mi->patch_state.rgba));

	const uint64_t stencil = mi->patch_state.stencil == 0 ? mi->m->state.stencil : mi->patch_state.stencil;
	BGFX(encoder_set_stencil)(w->holder->encoder,
		(uint32_t)(stencil & 0xffffffff), (uint32_t)(stencil >> 32)
	);

	struct attrib_arena_apply_context ctx = {
		w->bgfx,
		w->holder->encoder,
		w->math3d->M,
		math_value,
		math_size,
		texture_get,
	};

	const char * err = attrib_arena_apply_list(mi->m->A, mi->m->attrib, mi->patch_attrib, &ctx);
	if (err)
		luaL_error(L, "Apply error : %s", err);

	int ii;
	for (ii = 0; ii < MATERIAL_SYSTEM_ATTRIB_CHUNK; ++ii) {
		err = attrib_arena_apply_global(mi->m->A, mi->m->global[ii], ii * 64, &ctx);
		if (err)
			luaL_error(L, "Apply global error : %s", err);
	}

}

static int
linstance_apply_attrib(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	struct ecs_world * w = getworld(L);
	apply_material_instance(L, mi, w);
	return 0;
}

static int
linstance_release(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	if (mi->patch_attrib == INVALID_ATTRIB)
		return 0;
	struct ecs_world * w = getworld(L);
	struct attrib_arena *A = mi->m->A;
	attrib_id iter = mi->patch_attrib;
	mi->patch_attrib = INVALID_ATTRIB;
	while (iter != INVALID_ATTRIB) {
		math_t m = attrib_arena_remove(A, &iter);
		math_unmark(w->math3d->M, m);
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
linstance_get_state(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	return push_material_state(L,
		mi->patch_state.state == 0 ? mi->m->state.state : mi->patch_state.state,
		mi->patch_state.rgba == 0 ? mi->m->state.rgba : mi->patch_state.rgba);
}

static int
linstance_set_state(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	fetch_material_state(L, 2, &mi->patch_state);
	return 0;
}

static int
linstance_get_stencil(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	return push_material_stencil(L,
		mi->patch_state.stencil == 0 ? mi->m->state.stencil : mi->patch_state.stencil);
}

static int
linstance_set_stencil(lua_State *L) {
	struct material_instance* mi = to_instance(L, 1);
	fetch_material_stencil(L, 2, &mi->patch_state);
	return 0;
}

static int
linstance_isnull(lua_State *L){
	struct material_instance *mi = to_instance(L, 1);
	lua_pushboolean(L, mi == NULL || mi->m == NULL);
	return 1;
}

static int
linstance_ptr(lua_State *L) {
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
	if (mi->m == NULL){
		luaL_error(L, "material object is NULL");
	}

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);

	return 1;
}

static int
lmaterial_instance_init(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);	// key lookup_table
	check_ecs_world_in_upvalue1(L);

	luaL_Reg l[] = {
		{ "__index",		NULL},
		{ "__newindex", 	NULL},
		{ "__call", 		linstance_apply_attrib},
		{ "release",		linstance_release},
//		{ "attribs",		linstance_attribs},

		{ "get_state",		linstance_get_state},
		{ "set_state",		linstance_set_state},
		{ "get_stencil",	linstance_get_stencil},
		{ "set_stencil",	linstance_set_stencil},

		{ "isnull",			linstance_isnull},
		{ "ptr",			linstance_ptr},
		{ NULL, 			NULL },
	};
	luaL_newlibtable(L, l);
	lua_pushvalue(L, lua_upvalueindex(1));
	luaL_setfuncs(L, l, 1);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushcclosure(L, linstance_set_attrib, 2);

	lua_setfield(L, -2, "__newindex");

	lua_pushcclosure(L, lmaterial_instance, 1);
	return 1;
}

static int
lsystem_attrib_update(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);	// key
	lua_pushvalue(L, 1);
	if (lua_gettable(L, lua_upvalueindex(2)) != LUA_TNUMBER) {
		return luaL_error(L, "%s is not a system attrib name", lua_tostring(L, 1));
	}
	int id = (int)lua_tointeger(L, -1);
	if (id <= 0 && id > MATERIAL_SYSTEM_ATTRIB_CHUNK * 64) {
		return luaL_error(L, "Invalid system attrib %s (%d)", lua_tostring(L, 1), id);
	}
	struct attrib_arena *A = (struct attrib_arena *)lua_touserdata(L, lua_upvalueindex(3));
	set_attrib(L, A, -id, 2);
	return 0;
}

static int
lsystem_attrib_update_init(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);	// key lookup_table
	luaL_checktype(L, 2, LUA_TUSERDATA);	// arena
	check_ecs_world_in_upvalue1(L);

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushcclosure(L, lsystem_attrib_update, 3);
	return 1;
}

int
luaopen_material_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "instance",      lmaterial_instance_init },
		{ "system_attrib_update", lsystem_attrib_update_init },
		{ NULL,            NULL },
	};
	luaL_newlibtable(L, l);
	lua_pushnil(L);	// world
	luaL_setfuncs(L, l, 1);
	return 1;
}

bgfx_program_handle_t
material_prog(lua_State *L, struct material_instance *mi){
	(void)L;
	return program_get(mi->m->prog);
}
