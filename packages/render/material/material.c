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
#define ATTRIB_NONE		5

#define CAPI_INIT(L, idx) struct attrib_arena * cobject_ = get_cobject(L, idx);
#define CAPI_ARENA cobject_
#define CAPI_MATH3D cobject_->math
#define BGFX(api) cobject_->bgfx->api
#define BGFX_INVALID(h) (h.idx == UINT16_MAX)
#define BGFX_EQUAL(a,b) (a.idx == b.idx)

struct encoder_holder {
	bgfx_encoder_t *encoder;
};

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

//attrib list: al_*///////////////////////////////////////////////////////////
static inline void
al_init_attrib(struct attrib_arena* arena, struct attrib *a){
	(void)arena;

	a->type = ATTRIB_NONE;
	a->next = INVALID_ATTRIB;
	a->u.handle.idx = UINT16_MAX;
	a->u.m 	= 0;
}

static inline struct attrib*
al_attrib(struct attrib_arena *arena, uint16_t id){
	assert(arena->cap > id);
	return arena->a + id;
}

static inline uint16_t
al_attrib_id(struct attrib_arena *arena, struct attrib *a) {
	return (uint16_t)(a - arena->a);
}

static inline uint16_t
al_attrib_next_id(struct attrib_arena* arena, uint16_t id){
	return al_attrib(arena, id)->next;
}

static inline struct attrib*
al_next_attrib(struct attrib_arena *arena, struct attrib* a){
	return a->next == INVALID_ATTRIB ? NULL : al_attrib(arena, a->next);
}

static inline struct attrib*
al_attrib_next(struct attrib_arena *arena, uint16_t id){
	return al_next_attrib(arena, al_attrib(arena, id));
}

static inline int
is_uniform_attrib(uint16_t type){
	return type == ATTRIB_UNIFORM || type == ATTRIB_SAMPLER;
}

static inline int
al_attrib_is_uniform(struct attrib_arena* arena, struct attrib *a){
	(void)arena;
	return is_uniform_attrib(a->type);
}

static inline int
al_attrib_uniform_handle_equal(struct attrib_arena* arena, struct attrib *a1, struct attrib *a2){
	assert(al_attrib_is_uniform(arena, a1) && al_attrib_is_uniform(arena, a2));
	return BGFX_EQUAL(a1->u.handle, a2->u.handle);
}

static inline uint16_t
al_attrib_next_uniform_id(struct attrib_arena* arena, uint16_t id, uint16_t *count){
	assert(id != INVALID_ATTRIB);
	
	struct attrib* a = al_attrib(arena, id);
	uint16_t c = 1;
	if (al_attrib_is_uniform(arena, a)){
		while (a->next != INVALID_ATTRIB){
			struct attrib* na = al_attrib(arena, a->next);
			if (!al_attrib_is_uniform(arena, na) ||
				!al_attrib_uniform_handle_equal(arena, a, na))
				break;
			++c;
			a = na;
		}
	}

	if (count)
		*count = c;
	return a->next;
}

static inline struct attrib*
al_attrib_next_uniform(struct attrib_arena* arena, struct attrib* a, uint16_t *count){
	uint16_t nid = al_attrib_next_uniform_id(arena, al_attrib_id(arena, a), count);
	return nid == INVALID_ATTRIB ? NULL : al_attrib(arena, nid);
}

static inline int
al_attrib_num(struct attrib_arena* arena, struct attrib *a){
	uint16_t c = 0;
	al_attrib_next_uniform_id(arena, al_attrib_id(arena, a), &c);
	return c;
}

//lookup table:[name, attrib_id]///////////////////////////////////////////
static inline void
lut_create(lua_State *L, int value_idx){

}


static inline uint16_t
lut_find_name(lua_State *L, int lut_idx, const char* name){
	const int ltype = lua_getfield(L, lut_idx, name);
	const uint16_t id = (ltype != LUA_TNUMBER) ? (uint16_t)lua_tonumber(L, -1) : INVALID_ATTRIB;
	lua_pop(L, 1);
	return id;
}

static inline uint16_t
lut_find_stack(lua_State *L, int lut_idx, int value_idx){
	lua_pushvalue(L, value_idx);
	const int ltype = lua_rawget(L, lut_idx);
	const uint16_t id = (ltype != LUA_TNUMBER) ? (uint16_t)lua_tonumber(L, -1) : INVALID_ATTRIB;
	lua_pop(L, 1);
	return id;
}

//material instance: mi_*////////////////////////////////////////////////////////////////////////////
static inline int
mi_is_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, uint16_t pid){
	for (uint16_t id = mi->patch_attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)) {
		assert(al_attrib_is_uniform(arena, al_attrib(arena, id)));
		if (id == pid)
			return 1;
	}

	return 0;
}

static inline uint16_t
mi_find_material_atrrib(struct attrib_arena *arena, struct material *mat, struct material_instance *mi,  uint16_t id) {
	assert(mi_is_patch_attrib(arena, mi, id));
	struct attrib *pa = al_attrib(arena, id);
	for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)){
		struct attrib* a = al_attrib(arena, id);
		if (al_attrib_uniform_handle_equal(arena, a, pa))
			return id;
	}

	return INVALID_ATTRIB;
}

static inline uint16_t
mi_find_patch_attrib(struct material_instance *mi, struct attrib_arena *arena, struct attrib* a) {
	assert(!mi_is_patch_attrib(arena, mi, al_attrib_id(arena, a)) && "attrib 'a' should be pointer to material attirb not material instance attrib");
	if (!al_attrib_is_uniform(arena, a)){
		return INVALID_ATTRIB;
	}

	for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; ){
		struct attrib * ra = al_attrib(arena, pid);
		assert(al_attrib_is_uniform(arena, ra));
		if (al_attrib_uniform_handle_equal(arena, a, ra))
			return pid;
		pid = ra->next;
	}

	return INVALID_ATTRIB;
}

static void
mi_submit(struct attrib_arena *arena, struct material *mat, struct material_instance *mi){

}

/////////////////////////////////////////////////////////////////////////////
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
	struct attrib *a = al_attrib(arena, id);
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

	for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)) {
		struct attrib * a = al_attrib(cobject_, id);
		switch(a->type){
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
		case 'u':
		// could not be ATTRIB_REF
		default: return ATTRIB_UNIFORM;
	}
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

static void
unset_instance_attrib(struct material_instance *mi, struct attrib_arena *arena, struct attrib *a) {
	uint16_t ref = mi_find_patch_attrib(mi, arena, a);
	if (ref != INVALID_ATTRIB){
		const int num = al_attrib_num(arena, a);
		uint16_t id = ref;
		for (int i=0;i<num;i++) {
			id = clear_attrib(arena, id);
		}
	}
}

static void
update_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int index) {
	switch (a->type){
		case ATTRIB_UNIFORM:{
			const int datatype = lua_type(L, index);
			if (datatype == LUA_TTABLE){
				const int lt = lua_getfield(L, index, "value");
				if (lt != LUA_TLIGHTUSERDATA || lt != LUA_TUSERDATA){
					luaL_error(L, "Invalid math uniform 'value' field, math3d value is required");
				}
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
				if (LUA_TNUMBER != lua_getfield(L, index, "stage")){
					luaL_error(L, "Invalid sampler 'stage' field, number is needed");
				}
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
			if (LUA_TNUMBER != lua_getfield(L, index, "mip")){
				luaL_error(L, "Invalid image 'mip' field, number is need");
			}
			a->r.mip = (uint8_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		//walk through
		case ATTRIB_BUFFER: {
			luaL_checktype(L, index, LUA_TTABLE);
			if (LUA_TSTRING != lua_getfield(L, index, "access")){
				luaL_error(L, "Invalid image/buffer 'access' field, r/w/rw is required");
			}
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

			if (LUA_TNUMBER != lua_getfield(L, index, "stage")){
				luaL_error(L, "Invalid image/buffer 'stage' field, number is need");
			}
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

static struct attrib*
new_attrib(lua_State *L, int arena_index, int data_index, uint16_t attribtype){
	struct attrib* a = arena_alloc(L, arena_index);
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_index);
	al_init_attrib(arena, a);
	a->type = attribtype;
	update_attrib(L, arena, a, data_index);
	return a;
}

static void
replace_instance_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int value_index) {
	const uint16_t n = al_attrib_num(arena, a);
	if (n == 1) {
		update_attrib(L, arena, a, value_index);
	} else {
		for (int i=0;i<n;i++) {
			assert(a && "Invalid attrib");
			lua_geti(L, value_index, i+1);
			update_attrib(L, arena, a, -1);
			lua_pop(L, 1);
			a = al_next_attrib(arena, a);
		}
	}
}

static inline uint16_t
load_attrib_array(lua_State *L, int arena_idx, int data_idx, int num, uint16_t id, uint16_t type){
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
	for (int i=0; i<num; ++i){
		lua_geti(L, data_idx, i+1);
		struct attrib* a = new_attrib(L, arena_idx, -1, type);
		a->next = id;
		id = al_attrib_id(arena, a);
		lua_pop(L, 1);
	}

	return id;
}

static uint16_t
load_attrib(lua_State *L, int arena_idx, int data_idx, int num, uint16_t id, uint16_t type) {
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
	if (num == 1) {
		struct attrib * na = new_attrib(L, arena_idx, data_idx, type);
		na->next = id;
		return al_attrib_id(arena, na);
	}

	luaL_checktype(L, data_idx, LUA_TTABLE);

	const int n = (int)lua_rawlen(L, data_idx);
	if (n > 0){
		assert(n == num);
		return load_attrib_array(L, arena_idx, data_idx, num, id, type);
	}

	if (LUA_TTABLE == lua_getfield(L, data_idx, "value")){
		id = load_attrib_array(L, arena_idx, data_idx, num, id, type);
		lua_pop(L, 1);
		return id;
	}

	lua_pop(L, 1);
	luaL_error(L, "Invalid multi uniform value, table field 'value' should be table");
	return INVALID_ATTRIB;
}

static inline uint16_t
count_data_num(lua_State *L, int data_index, uint16_t type){
	uint16_t n = 1;
	if (is_uniform_attrib(type)){
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
	return load_attrib(L, arena_idx, data_index, n, id, type);
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, int arena_idx, struct attrib * a, int value_index) {
	uint16_t pid = mi_find_patch_attrib(mi, arena, a);
	if (pid == INVALID_ATTRIB) {
		const int n = al_attrib_num(arena, a);
		#ifdef _DEBUG
		{
			if (n > 1){
				bgfx_uniform_info_t info;
				struct attrib_arena* cobject_ = arena;
				BGFX(get_uniform_info)(a->u.handle, &info);
				assert(n == info.num);
			}
		}
		#endif //_DEBUG
		mi->patch_attrib = load_attrib(L, arena_idx, value_index, n, mi->patch_attrib, a->type);
	} else {
		replace_instance_attrib(L, arena, al_attrib(arena, pid), value_index);
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
	const char* attribname = luaL_checkstring(L, 2);
	const int arena_idx = lua_upvalueindex(2);
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, arena_idx);
	lua_getiuservalue(L, lua_upvalueindex(1), 3);
	lua_pushvalue(L, 2);
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, 2, NULL));
	}
	const int id = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);

	struct attrib * a = al_attrib(arena, id);
	if (!al_attrib_is_uniform(arena, a)){
		return luaL_error(L, "only uniform & sampler attrib can modify");
	}

	if (lua_type(L, 3) == LUA_TNIL) {
		unset_instance_attrib(mi, arena, a);
	} else {
		set_instance_attrib(L, mi, arena, arena_idx, a, 3);
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

static void
apply_attrib(lua_State *L, struct attrib_arena * cobject_, struct attrib *a, int texture_index) {
	if (a->type == ATTRIB_REF){
		struct attrib *ra = al_attrib(cobject_, a->ref);
		apply_attrib(L, cobject_, ra, texture_index);
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
			luaL_error(L, "Invalid buffer type %d", type);
		}
	}
	struct attrib_arena * arena = cobject_;

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
		
		for (uint16_t i=0; i<n; ++i){
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
		}
		BGFX(encoder_set_uniform)(cobject_->eh->encoder, a->u.handle, buffer, n);
	}
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

	struct attrib_arena* arena = cobject_;

	if (mi->patch_attrib == INVALID_ATTRIB) {
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)){
			struct attrib* a = al_attrib(arena, id);
			apply_attrib(L, arena, a, texture_index);
		}
	} else {
		uint16_t ids[MAX_UNIFORM_NUM];
		uint16_t num_attrib = 0;
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)){
			ids[num_attrib++] = id;
		}

		for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_id(arena, pid)){
			struct attrib* pa = al_attrib(arena, pid);
			assert(al_attrib_is_uniform(arena, pa));
			for (int i=0; i<num_attrib; ++i){
				struct attrib* a = al_attrib(arena, ids[i]);
				if (al_attrib_uniform_handle_equal(arena, pa, a)){
					ids[i] = pid;
					break;
				}
			}
		}

		for (int i=0; i<num_attrib; ++i){
			struct attrib *a = al_attrib(arena, ids[i]);
			apply_attrib(L, arena, a, texture_index);
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
	const char* filename = lua_tostring(L, 4);
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

	//system attrib table
	if (lua_getiuservalue(L, 1, 1) != LUA_TTABLE){
		luaL_error(L, "Invalid cobject");
	}
	const int sa_lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 3) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		struct attrib* a = NULL;
		if (LUA_TNIL != lua_getfield(L, sa_lookup_idx, key)){
			a = arena_alloc(L, 1);
			// system attribs
			a->type = ATTRIB_REF;
			a->ref = (uint16_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		} else {
			lua_pop(L, 1);
			uint16_t id = load_attrib_from_data(L, 1, -1, *pattrib);
			a = al_attrib(cobject_, id);
		}
		uint16_t id = al_attrib_id(cobject_, a);
		*pattrib = id;
		pattrib = &a->next;

		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, key);
	}
	lua_pop(L, 1);	//system attrib table

	lua_setiuservalue(L, -2, 3);	// push lookup table as uv3

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

	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 2) != 0; lua_pop(L, 1)) {
		const char* name = lua_tostring(L, -2);
		const uint16_t id = load_attrib_from_data(L, 1, -1, INVALID_ATTRIB);
		lua_pushinteger(L, id);
		lua_setfield(L, lookup_idx, name);
	}

	lua_setiuservalue(L, 1, 1);	// system attrib table as cobject 1 user value
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

