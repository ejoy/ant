#define LUA_LIB

#include <bgfx/c99/bgfx.h>
#include <math3d.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <luabgfx.h>

#ifdef _DEBUG
#define verfiy(_CON)	assert(_CON)
#else //!_DEBUG
#define verfiy(_CON)	_CON
#endif //_DEBUG


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
	uint16_t patch;
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
	struct attrib_arena * a = (struct attrib_arena *)lua_newuserdatauv(L, sizeof(struct attrib_arena), 3);
	a->bgfx = bgfx;
	a->math = mapi;
	a->eh = h;
	a->cap = 0;
	a->n = 0;
	a->freelist = INVALID_ATTRIB;
	a->a = NULL;
	//invalid material attrib list
	lua_newtable(L);
	lua_setiuservalue(L, -2, 3);	//set invalid table as uv 3
	return a;
}

//attrib list: al_*///////////////////////////////////////////////////////////
static inline void
al_init_attrib(struct attrib_arena* arena, struct attrib *a){
	(void)arena;

	a->type = ATTRIB_NONE;
	a->next = INVALID_ATTRIB;
	a->patch = INVALID_ATTRIB;
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

//material instance: mi_*////////////////////////////////////////////////////////////////////////////
static inline int
mi_is_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, uint16_t pid){
	for (uint16_t id = mi->patch_attrib; id != INVALID_ATTRIB; id = al_attrib_next_uniform_id(arena, id, NULL)) {
		if (id == pid)
			return 1;
	}

	return 0;
}

static inline struct attrib*
mi_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, uint16_t pid){
	assert(mi_is_patch_attrib(arena, mi, pid));
	struct attrib* pa = al_attrib(arena, pid);
	return (pa->patch != INVALID_ATTRIB) ? al_attrib(arena, pa->patch) : NULL;
}

static inline uint16_t
mi_find_patch_attrib(struct attrib_arena *arena, struct material_instance *mi, uint16_t id){
	assert(id != INVALID_ATTRIB);
	for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_uniform_id(arena, pid, NULL)){
		struct attrib *pa = al_attrib(arena, pid);
		if (pa->patch == id)
			return pid;
	}

	return INVALID_ATTRIB;
}

/////////////////////////////////////////////////////////////////////////////
struct attrib *
arena_alloc(lua_State *L, int idx) {
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, idx);
	struct attrib *ret;
	if (arena->freelist != INVALID_ATTRIB) {
		ret = al_attrib(arena, arena->freelist);
		arena->freelist = ret->next;
	} else if (arena->n < arena->cap) {
		ret = al_attrib(arena, arena->n);
		arena->n++;
	} else if (arena->cap == 0) {
		// new arena
		struct attrib * al = (struct attrib *)lua_newuserdatauv(L, sizeof(struct attrib) * DEFAULT_ARENA_SIZE, 0);
		lua_setiuservalue(L, idx, 1);
		arena->a = al;
		arena->cap = DEFAULT_ARENA_SIZE;
		arena->n = 1;
		ret = arena->a;
	} else {
		// resize arena
		int newcap = arena->cap * 2;
		if (newcap > INVALID_ATTRIB)
			luaL_error(L, "Too many attribs");
		struct attrib * al = (struct attrib *)lua_newuserdatauv(L, sizeof(struct attrib) * newcap, 0);
		memcpy(al, arena->a, sizeof(struct attrib) * arena->n);
		arena->a = al;
		lua_setiuservalue(L, idx, 1);
		ret = al_attrib(arena, arena->n++);
	}
	al_init_attrib(arena, ret);
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
	if (LUA_TUSERDATA != lua_getiuservalue(L, 1, 2)){
		return luaL_error(L, "Invalid material, uservalue in 2 is not 'cobject'");
	}
	const int arena_idx = 2;
	CAPI_INIT(L, arena_idx);
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

// 1: material
static int
lmaterial_instance(lua_State *L) {
	struct material_instance * mi = (struct material_instance *)lua_newuserdatauv(L, sizeof(*mi), 0);
	mi->patch_attrib = INVALID_ATTRIB;
	if (LUA_TTABLE != lua_getiuservalue(L, 1, 1)){	// push material instance metatable
		return luaL_error(L, "Invalid material object, uservalue in 1 is not material instance metatable");
	}
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
	uint16_t ref = mi_find_patch_attrib(arena, mi, al_attrib_id(arena, a));
	if (ref != INVALID_ATTRIB){
		const int num = al_attrib_num(arena, a);
		uint16_t id = ref;
		for (int i=0;i<num;i++) {
			id = clear_attrib(arena, id);
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
fetch_math_value_(lua_State *L, struct attrib_arena* arena,  struct attrib* a, int index){
	math3d_unmark_id(arena->math, a->u.m);
	a->u.m = math3d_mark_id(L, arena->math, index);
}

static inline void
fetch_math_value(lua_State *L, struct attrib_arena* arena, struct attrib* a, int index){
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
fetch_sampler(lua_State *L, struct attrib* a, int index){
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
fetch_image(lua_State *L, struct attrib* a, int index){
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
fetch_buffer(lua_State *L, struct attrib* a, int index){
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

static void
fetch_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int index) {
	switch (a->type){
		case ATTRIB_UNIFORM:	fetch_math_value(L, arena, a, index);			break;
		case ATTRIB_SAMPLER:	fetch_sampler(L, a, index);					break;
		case ATTRIB_IMAGE:		fetch_image(L, a, index);						break;
		case ATTRIB_BUFFER:		fetch_buffer(L, a, index);						break;
		default: luaL_error(L, "Attribute type:%d, could not update", a->type);	break;
	}
}

static inline uint16_t
create_attrib(lua_State *L, int arena_idx, int n, uint16_t id, uint16_t attribtype, uint16_t patchid, bgfx_uniform_handle_t h){
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
	for (int i=0; i<n; ++i){
		struct attrib* na = arena_alloc(L, arena_idx);
		na->type = attribtype;
		na->next = id;
		na->patch = patchid;
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
update_attrib(lua_State *L, struct attrib_arena *arena, struct attrib *a, int data_idx) {
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
	const bgfx_uniform_handle_t h = {is_uniform_attrib(type) ? fetch_handle(L, data_index).idx : UINT16_MAX};
	uint16_t nid = create_attrib(L, arena_idx, n, id, type, INVALID_ATTRIB, h);
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
	update_attrib(L, arena, al_attrib(arena, nid), data_index);
	return nid;
}

static int
lmaterial_set_attrib(lua_State *L){
	struct material* mat = (struct material*)luaL_checkudata(L, 1, "ANT_MATERIAL");
	if (LUA_TUSERDATA != lua_getiuservalue(L, 1, 2)) {	// get cobject
		return luaL_error(L, "Invalid material object, not found cobject in uservalue 2");
	}
	const int arena_idx = lua_gettop(L);
	
	if (LUA_TTABLE != lua_getiuservalue(L, 1, 3)) {	// get material lookup table
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
		struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
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
check_uniform_num(struct attrib_arena *arena, struct attrib *a, int n){
	if (al_attrib_is_uniform(arena, a)){
		bgfx_uniform_info_t info;
		struct attrib_arena* cobject_ = arena;
		BGFX(get_uniform_info)(a->u.handle, &info);
		return (n == info.num);
	}
	return 1;
}

static void
set_instance_attrib(lua_State *L, struct material_instance *mi, struct attrib_arena *arena, int arena_idx, struct attrib * a, int value_index) {
	uint16_t pid = mi_find_patch_attrib(arena, mi, al_attrib_id(arena, a));
	if (pid == INVALID_ATTRIB) {
		const int n = al_attrib_num(arena, a);
		assert(check_uniform_num(arena, a, n));
		pid = create_attrib(L, arena_idx, n, mi->patch_attrib, a->type, al_attrib_id(arena, a), a->u.handle);
		mi->patch_attrib = pid;
	}
	update_attrib(L, arena, al_attrib(arena, pid), value_index);
}

// upvalue 1: material
// upvalue 2: cobject
// 1: material_instance
// 2: uniform name
// 3: value
static int
linstance_set_attrib(lua_State *L) {
	struct material_instance * mi = (struct	material_instance *)lua_touserdata(L, 1);
	const char* attribname = luaL_checkstring(L, 2);
	if (strcmp(attribname, "material_obj") == 0){
		return luaL_error(L, "'material_obj' is not a valid name, use another name");
	}
	const int arena_idx = lua_upvalueindex(2);
	struct attrib_arena * arena = (struct attrib_arena *)lua_touserdata(L, arena_idx);
	// push materia lookup table in stack
	if (LUA_TTABLE != lua_getiuservalue(L, lua_upvalueindex(1), 3)){
		return luaL_error(L, "Invalid uservalue in function upvalue 1, need a lookup table in material uservalue 3");
	}
	lua_pushvalue(L, 2);	// push lookup key
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		return luaL_error(L, "set invalid attrib %s", luaL_tolstring(L, 2, NULL));
	}
	const int id = (int)lua_tointeger(L, -1);
	lua_pop(L, 2);	//

	struct attrib * a = al_attrib(arena, id);
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
		return luaL_error(L, "Invalid material data in uservalue 1, should be material instance metatable");
	}
	int free_instance = (int)lua_rawlen(L, -1);
	int instance_index = lua_gettop(L);
	if (lua_getfield(L, -1, "__gc") != LUA_TFUNCTION) {
		return 0;
	}
	lua_getupvalue(L, -1, 2);	// cobject
	assert(lua_type(L, -1) == LUA_TUSERDATA);
	if (LUA_TTABLE != lua_getiuservalue(L, -1, 3)){// material invalid attrib list table
		luaL_error(L, "Invalid uservalue in 'cobject', uservalue in 3 should ba invalid material atrrib table");
	}
	const int iml_idx = lua_gettop(L);
	int n = (int)lua_rawlen(L, -1);
	if (mat->attrib != INVALID_ATTRIB) {
		lua_pushinteger(L, mat->attrib);
		lua_rawseti(L, iml_idx, ++n);
		mat->attrib = INVALID_ATTRIB;
	}

	//push material instance invalid attrib list to material invalid attrib list table
	int i;
	for (i=0;i<free_instance;i++) {
		if ( LUA_TNUMBER != lua_rawgeti(L, instance_index, i+1)){
			luaL_error(L, "Invalid data in invalid material instance table, number excepted");
		}
		lua_rawseti(L, iml_idx, ++n);
	}

	lua_pop(L, 2);				// cobject, material invalid attrib list
	return 0;
}

static int
linstance_gc(lua_State *L) {
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

static inline bgfx_texture_handle_t
check_get_texture_handle(lua_State *L, int texture_index, uint32_t handle){
	bgfx_texture_handle_t tex;
	lua_geti(L, texture_index, handle);
	tex.idx = luaL_optinteger(L, -1, handle) & 0xffff;
	lua_pop(L, 1);
	return tex;
}

static void
apply_attrib(lua_State *L, struct attrib_arena * cobject_, struct attrib *a, int texture_index) {
	switch(a->type){
		case ATTRIB_REF:
			apply_attrib(L, cobject_, al_attrib(cobject_, a->ref), texture_index);
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
			BGFX(encoder_set_image)(cobject_->eh->encoder, a->r.stage, tex, a->r.mip, a->r.access, BGFX_TEXTURE_FORMAT_UNKNOWN);
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
		}	break;
		default:
			luaL_error(L, "Invalid attrib type:%d", a->type);
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
		uint16_t num_attrib = 0;
		for (uint16_t id = mat->attrib; id != INVALID_ATTRIB; id = al_attrib_next_id(arena, id)){
			uint16_t apply_id = id;
			for (uint16_t pid = mi->patch_attrib; pid != INVALID_ATTRIB; pid = al_attrib_next_id(arena, pid)){
				struct attrib* pa = al_attrib(arena, pid);
				if (pa->patch == id){
					apply_id = pid;
					break;
				}
			}
			struct attrib *a = al_attrib(arena, apply_id);
			apply_attrib(L, arena, a, texture_index);
		}
	}

	return 0;
}

static int
linstance_get_material(lua_State *L){
	struct material_instance* mi = (struct material_instance*)lua_touserdata(L, 1);
	lua_pushvalue(L, lua_upvalueindex(1));	// upvalue 1 is material object
	return 1;
}

static int
linstance_get_state(lua_State *L){
	struct material_instance* mi = (struct material_instance*)lua_touserdata(L, 1);
	lua_pushvalue(L, lua_upvalueindex(1));	// upvalue 1 is material object
	struct material * mat = (struct material*)lua_touserdata(L, -1);
	return push_material_state(L, mat);
}

// 1: material
// 2: cobject
static void
create_material_instance_metatable(lua_State *L) {
	luaL_Reg l[] = {
		{ "__gc", 			linstance_gc		},
		{ "__newindex", 	linstance_set_attrib},
		{ "__call", 		linstance_apply_attrib},
		{ "get_material",	linstance_get_material},
		{ "get_state",		linstance_get_state},
		{ NULL, 		NULL },
	};
	luaL_newlibtable(L, l);
	lua_insert(L, -3);
	luaL_setfuncs(L, l, 2);
	lua_pushvalue(L, -1);
	lua_setfield(L, -1, "__index");
}

static inline uint16_t
fetch_material_attrib_value(lua_State *L, struct attrib_arena* arena, int arena_idx, 
	int sa_lookup_idx, int lookup_idx, const char*key, uint16_t lastid){
	if (LUA_TNIL != lua_getfield(L, sa_lookup_idx, key)){
		struct attrib* a = arena_alloc(L, arena_idx);
		a->type = ATTRIB_REF;
		a->ref = (uint16_t)lua_tointeger(L, -1);
		a->next = lastid;
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
lmaterial_copy(lua_State *L){
	struct material* temp_mat = (struct material*)lua_touserdata(L, 1);
	struct material* new_mat = (struct material*)lua_newuserdatauv(L, sizeof(*new_mat), 3);
	new_mat->attrib = temp_mat->attrib;
	if (!lua_isnoneornil(L, 2)){
		get_state(L, 2, &new_mat->state, &new_mat->rgba);
	} else {
		new_mat->state = temp_mat->state;
		new_mat->rgba = temp_mat->rgba;
	}

	//uv1
	lua_pushvalue(L, -1);	// material
	lua_getiuservalue(L, 1, 2); //cobject
	create_material_instance_metatable(L);
	lua_setiuservalue(L, -2, 1);

	//uv2
	lua_getiuservalue(L, 1, 2);
	lua_setiuservalue(L, -2, 2);

	//uv3
	lua_getiuservalue(L, 1, 3);
	lua_setiuservalue(L, -2, 3);

	verfiy(lua_getmetatable(L, 1));
	lua_setmetatable(L, -2);

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

	lua_newtable(L);
	const int lookup_idx = lua_gettop(L);

	//system attrib table
	if (lua_getiuservalue(L, arena_idx, 2) != LUA_TTABLE){
		luaL_error(L, "Invalid cobject");
	}
	const int sa_lookup_idx = lua_gettop(L);
	for (lua_pushnil(L); lua_next(L, 3) != 0; lua_pop(L, 1)) {
		const char* key = lua_tostring(L, -2);
		mat->attrib = fetch_material_attrib_value(L, arena, arena_idx, sa_lookup_idx, lookup_idx, key, mat->attrib);
	}
	lua_pop(L, 1);	//system attrib table

	lua_setiuservalue(L, -2, 3);	// push lookup table as uv3

	if (luaL_newmetatable(L, "ANT_MATERIAL")) {
		luaL_Reg l[] = {
			{ "__gc",		lmaterial_gc },
			{ "attribs", 	lmaterial_attribs },
			{ "instance", 	lmaterial_instance },
			{ "set_attrib",	lmaterial_set_attrib},
			{ "get_state",	lmaterial_get_state},
			{ "set_state",	lmaterial_set_state},
			{ "copy",		lmaterial_copy},
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
lsa_update(lua_State *L){
	luaL_checktype(L, 1, LUA_TTABLE);
	const char* name = luaL_checkstring(L, 2);
	if (LUA_TNUMBER != lua_getfield(L, 1, name)){
		lua_pop(L, 1);
		return luaL_error(L, "Invalid system attrib:%s", name);
	}
	const uint16_t id = (uint16_t)lua_tointeger(L, -1);
	const int arena_idx = lua_upvalueindex(1);
	struct attrib_arena* arena = (struct attrib_arena*)lua_touserdata(L, arena_idx);
	struct attrib* a = al_attrib(arena, id);
	update_attrib(L, arena, a, 3);
	lua_pop(L, 1);
	return 0;
}

static int
lsystem_attribs_new(lua_State *L){
	const int arena_idx = 1;
	CAPI_INIT(L, arena_idx);
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
	lua_setiuservalue(L, 1, 2);	// set system attrib table as cobject 1 user value
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

