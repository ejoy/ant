#include "material_arena.h"

#include "mathid.h"
#include "lua.h"
#include "lauxlib.h"
#include "luabgfx.h"

#include <stdint.h>
#include <assert.h>
#include <string.h>

#define INVALID_HANDLE 0xffff
#define MAX_ATTRIB_COUNT 0xffff
#define MAX_VEC (16 * 1024)
#define MAX_GLOBAL_COUNT ( MATERIAL_SYSTEM_ATTRIB_CHUNK * 64 )

#if !defined(MATERIAL_DEBUG)
#define MATERIAL_DEBUG 1
#endif

#define ATTRIB_HEARDER \
	attrib_id next; \
	name_id key; \
	uint8_t type;

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
			uint32_t vec;
			uint16_t n;
			uint16_t elem;
		} v;
	} u;
};

struct attrib_resource {
	ATTRIB_HEARDER
	uint8_t 		stage;
	uint8_t			mip;
	bgfx_access_t	access;
	uint32_t		handle;
};

typedef union {
	struct attrib_header	h;
	struct attrib_uniform	u;
	struct attrib_resource	r;
} attrib_type;

struct vec {
	float v[4];
};

struct attrib_arena {
	attrib_id freelist;
	int vec_n;
	int attrib_n;
	struct vec v[MAX_VEC];
	attrib_type g[MAX_GLOBAL_COUNT];
	attrib_type a[MAX_ATTRIB_COUNT];
};

size_t
attrib_arena_size() {
	return sizeof(struct attrib_arena);
}

void
attrib_arena_init(struct attrib_arena *A) {
	A->freelist = INVALID_ATTRIB;
	A->vec_n = 0;
	A->attrib_n = 0;
	int i;
	for (i=0;i<MAX_GLOBAL_COUNT;i++) {
		A->g[i].h.next = INVALID_ATTRIB;
		A->g[i].h.key = i;
		A->g[i].h.type = ATTRIB_NONE;
	}
}

static inline attrib_type *
get_attrib_from_id(struct attrib_arena *A, int id) {
	if (id < 0) {
		id = -id - 1;
		if (id >= MAX_GLOBAL_COUNT)
			return NULL;
		return &A->g[id];
	} else {
		if (id >= MAX_ATTRIB_COUNT)
			return NULL;
		return &A->a[id];
	}
}

static inline attrib_type *
get_attrib(struct attrib_arena *A, attrib_id id) {
	assert(id < MAX_ATTRIB_COUNT);
	return &A->a[id];
}

const char *
attrib_arena_init_uniform(struct attrib_arena *A, int id, bgfx_uniform_handle_t h, const float *v, int n, int elem) {
	attrib_type *a = get_attrib_from_id(A, id);
	if (a == NULL)
		return "Invalid attrib id";
	if (a->h.type == ATTRIB_NONE) {
		if (A->vec_n + n > MAX_VEC) {
			return "Too many vec for attribs";
		}
		// init
		a->h.type = ATTRIB_UNIFORM;
		a->u.u.v.vec = A->vec_n;
		a->u.u.v.n = n;
		a->u.u.v.elem = elem;
		A->vec_n += n;
	} else {
		if (a->h.type != ATTRIB_UNIFORM)
			return "Invalid attrib type UNIFORM";
		if (a->u.u.v.n != n)
			return "Invalid attrib UNIFORM size";
	}
	a->u.handle = h;
	memcpy(A->v + a->u.u.v.vec, v, n * sizeof(struct vec));
	return NULL;
}

const char *
attrib_arena_init_sampler(struct attrib_arena *A, int id, bgfx_uniform_handle_t h, uint32_t handle, uint8_t stage) {
	attrib_type *a = get_attrib_from_id(A, id);
	if (a == NULL)
		return "Invalid attrib id";
	if (a->h.type == ATTRIB_NONE) {
		// init
		a->h.type = ATTRIB_SAMPLER;
	} else {
		if (a->h.type != ATTRIB_SAMPLER)
			return "Invalid attrib type SAMPLER";
	}
	a->u.handle = h;
	a->u.u.t.handle = handle;
	a->u.u.t.stage = stage;
	return NULL;
}

// set image or buffer
static const char *
attrib_arena_init_resource_(struct attrib_arena *A, int id, int type, uint32_t handle, uint8_t stage, bgfx_access_t access, uint8_t mip) {
	attrib_type *a = get_attrib_from_id(A, id);
	if (a == NULL)
		return "Invalid attrib id";
	if (a->h.type == ATTRIB_NONE) {
		// init
		a->h.type = type;
	} else {
		if (a->h.type != type)
			return "Invalid attrib resource type";
	}
	a->r.stage = stage;
	a->r.access = access;
	a->r.mip = mip;
	a->r.handle = handle;
	return NULL;
}

const char *
attrib_arena_init_image(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access, uint8_t mip) {
	return attrib_arena_init_resource_(A, id, ATTRIB_IMAGE, handle, stage, access, mip);
}

const char *
attrib_arena_init_buffer(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access) {
	return attrib_arena_init_resource_(A, id, ATTRIB_BUFFER, handle, stage, access, 0);
}

static attrib_id
init_attrib(struct attrib_arena *A, attrib_id prev, attrib_id current, name_id key) {
	attrib_id next = INVALID_ATTRIB;
	if (prev != INVALID_ATTRIB) {
		attrib_type *p = get_attrib(A, prev);
		next = p->h.next;
		p->h.next = current;
	}
	attrib_type *a = get_attrib(A, current);
	a->h.key = key;
	a->h.next = next;
	a->h.type = ATTRIB_NONE;
	return current;
}

attrib_id
attrib_arena_new(struct attrib_arena *A, attrib_id prev, name_id key) {
	attrib_id r = A->freelist;
	if (r != INVALID_ATTRIB) {
		A->freelist = get_attrib(A, r)->h.next;
		return init_attrib(A, prev, r, key);
	}
	r = A->attrib_n++;
	if (r >= MAX_ATTRIB_COUNT)
		return INVALID_ATTRIB;
	return init_attrib(A, prev, r, key);
}

attrib_id
attrib_arena_delete(struct attrib_arena *A, attrib_id prev, attrib_id current) {
	attrib_type *a = get_attrib(A, current);
	attrib_id next = a->h.next;
	if (prev != INVALID_ATTRIB) {
		attrib_type *p = get_attrib(A, prev);
		p->h.next = next;
	}
	a->h.next = A->freelist;
	A->freelist = current;
	return next;
}

attrib_id
attrib_arena_clone(struct attrib_arena *A, attrib_id prev, attrib_id head, attrib_id node) {
	attrib_type *a = get_attrib(A, node);
	name_id key = a->h.key;

	attrib_id next = prev == INVALID_ATTRIB ? head : get_attrib(A, prev)->h.next;

	attrib_id r = attrib_arena_new(A, prev, key);
	if (r == INVALID_ATTRIB)
		return r;
	attrib_type * clone = get_attrib(A, r);
	clone->h.next = next;
	uint8_t type = a->h.type;
	if (type == ATTRIB_UNIFORM)
		type = ATTRIB_UNIFORM_INSTANCE;
	clone->h.type = type;
	switch (type) {
	case ATTRIB_SAMPLER:
		clone->u.handle = a->u.handle;
		clone->u.u = a->u.u;
		break;
	case ATTRIB_UNIFORM_INSTANCE:
		clone->u.handle = a->u.handle;
		clone->u.u.m = MATH_NULL;
		break;
	case ATTRIB_IMAGE:
	case ATTRIB_BUFFER:
		clone->r.stage = a->r.stage;
		clone->r.mip = a->r.mip;
		clone->r.access = a->r.access;
		clone->r.handle = a->r.handle;
		break;
	default:
		assert(0);
		break;
	}
	return r;
}

attrib_id
attrib_arena_find(struct attrib_arena *A, attrib_id head, name_id key, attrib_id *prev) {
	*prev = INVALID_ATTRIB;
	while (head != INVALID_ATTRIB) {
		attrib_type *a = get_attrib(A, head);
		if (a->h.key == key) {
			return head;
		}
		if (a->h.key > key) {
			return INVALID_ATTRIB;
		}
		*prev = head;
		head = a->h.next;
	}
	return INVALID_ATTRIB;
}

void
attrib_arena_set_uniform(struct attrib_arena *A, int id, const float *v) {
	attrib_type *a = get_attrib_from_id(A, id);
	assert(a);
	assert(a->h.type == ATTRIB_UNIFORM);
	int n = a->u.u.v.n;
	memcpy(A->v + a->u.u.v.vec, v, n * sizeof(struct vec));
}

math_t
attrib_arena_set_uniform_instance(struct attrib_arena *A, int id, math_t m) {
	attrib_type *a = get_attrib_from_id(A, id);
	assert(a);
	assert(a->h.type == ATTRIB_UNIFORM_INSTANCE);
	math_t r = a->u.u.m;
	a->u.u.m = m;
	return r;
}

void
attrib_arena_set_handle(struct attrib_arena *A, int id, uint32_t handle) {
	attrib_type *a = get_attrib_from_id(A, id);
	assert(a);
	switch (a->h.type) {
	case ATTRIB_SAMPLER:
		a->u.u.t.handle = handle;
		break;
	case ATTRIB_IMAGE:
	case ATTRIB_BUFFER:
		a->r.handle = handle;
		break;
	default:
		assert(0);
		break;
	}
}

void
attrib_arena_set_sampler(struct attrib_arena *A, int id, uint32_t handle, int stage) {
	attrib_type *a = get_attrib_from_id(A, id);
	assert(a);
	assert(a->h.type == ATTRIB_SAMPLER);
	a->u.u.t.handle = handle;
	a->u.u.t.stage = stage;
}

void
attrib_arena_set_resource(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access, uint8_t mip) {
	attrib_type *a = get_attrib_from_id(A, id);
	assert(a);
	assert(a->h.type == ATTRIB_IMAGE || a->h.type == ATTRIB_BUFFER);
	a->r.stage = stage;
	a->r.access = access;
	a->r.mip = mip;
	a->r.handle = handle;
}

#define BGFX(api) ctx->bgfx->api

static inline bgfx_texture_handle_t
check_get_texture_handle(struct attrib_arena_apply_context *ctx, uint32_t handle) {
	if ((0xffff0000 & handle) == 0) {
		return ctx->texture_get((int)handle);
	}
	bgfx_texture_handle_t r = {(uint16_t)handle};
	return r;
}

const char *
attrib_arena_apply(struct attrib_arena *A, int id, struct attrib_arena_apply_context *ctx) {
	attrib_type *a = get_attrib_from_id(A, id);
	if (a == NULL)
		return "Invalid attrib";
	switch(a->h.type){
		case ATTRIB_SAMPLER: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(ctx, a->u.u.t.handle);
			#if MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			#endif //MATERIAL_DEBUG
			BGFX(encoder_set_texture)(ctx->encoder, a->u.u.t.stage, a->u.handle, tex, UINT32_MAX);
		}	break;
		case ATTRIB_IMAGE: {
			const bgfx_texture_handle_t tex = check_get_texture_handle(ctx, a->r.handle);
			BGFX(encoder_set_image)(ctx->encoder, a->r.stage, tex, a->r.mip, a->r.access, BGFX_TEXTURE_FORMAT_COUNT);
		}	break;

		case ATTRIB_BUFFER: {
			const attrib_id id = a->r.handle & 0xffff;
			const uint16_t btype = a->r.handle >> 16;
			switch (btype) {
			case BGFX_HANDLE_VERTEX_BUFFER: {
				bgfx_vertex_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_vertex_buffer)(ctx->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
				bgfx_dynamic_vertex_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_dynamic_vertex_buffer)(ctx->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_INDEX_BUFFER: {
				bgfx_index_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_index_buffer)(ctx->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32:
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER: {
				bgfx_dynamic_index_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_dynamic_index_buffer)(ctx->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			case BGFX_HANDLE_INDIRECT_BUFFER: {
				bgfx_indirect_buffer_handle_t handle = { id };
				BGFX(encoder_set_compute_indirect_buffer)(ctx->encoder, a->r.stage, handle, a->r.access);
				break;
			}
			default:
				return "Invalid buffer type";
			}
		}	break;
		case ATTRIB_UNIFORM : {
			int n = a->u.u.v.elem;
			#if MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			assert(n <= info.num);
			#endif //MATERIAL_DEBUG
			BGFX(encoder_set_uniform)(ctx->encoder, a->u.handle, A->v + a->u.u.v.vec, n);
			break;
		}
		case ATTRIB_UNIFORM_INSTANCE: {
			const int n = ctx->math_size(ctx->math3d, a->u.u.m);
			#if MATERIAL_DEBUG
			bgfx_uniform_info_t info; BGFX(get_uniform_info)(a->u.handle, &info);
			assert(n <= info.num);
			#endif //MATERIAL_DEBUG
			BGFX(encoder_set_uniform)(ctx->encoder, a->u.handle, ctx->math_value(ctx->math3d, a->u.u.m), n);
		}	break;
		default:
			return "Invalid attrib type";
	}
	return NULL;
}

static inline attrib_id
get_next(struct attrib_arena *A, attrib_id *id) {
	attrib_id r = *id;
	if (r == INVALID_ATTRIB)
		return INVALID_ATTRIB;
	attrib_type *a = get_attrib(A, r);
	*id = a->h.next;
	return r;
}

static inline attrib_id
get_next_attrib(struct attrib_arena *A, attrib_id *id1, attrib_id *id2) {
	if (*id1 == INVALID_ATTRIB) {
		return get_next(A, id2);
	}
	if (*id2 == INVALID_ATTRIB) {
		return get_next(A, id1);
	}

	attrib_type* a1 = get_attrib(A, *id1);
	attrib_type* a2 = get_attrib(A, *id2);

	if (a1->h.key == a2->h.key) {
		get_next(A, id2);
		return get_next(A, id1);
	}
	if (a1->h.key < a2->h.key) {
		return get_next(A, id1);
	}
	return get_next(A, id2);
}

const char *
attrib_arena_apply_list(struct attrib_arena *A, attrib_id head, attrib_id patch, struct attrib_arena_apply_context *ctx) {
	attrib_id id;
	while ((id = get_next_attrib(A, &patch, &head)) != INVALID_ATTRIB) {
		const char * err = attrib_arena_apply(A, id, ctx);
		if (err)
			return err;
	}
	return NULL;
}

static inline const char *
apply_global8(struct attrib_arena *A, uint8_t mask, int base, struct attrib_arena_apply_context *ctx) {
	int i;
	int id = -base-1;
	for (i=0;mask != 0 && i<8;i++) {
		if (mask & 1) {
			const char * err = attrib_arena_apply(A, id, ctx);
			if (err)
				return err;
		}
		mask >>= 1;
		--id;
	}
	return NULL;
}

static inline const char *
apply_global16(struct attrib_arena *A, uint16_t mask, int base, struct attrib_arena_apply_context *ctx) {
	if (mask == 0)
		return NULL;
	uint8_t mask8[2] = { mask & 0xff, mask >> 8 };
	const char * err = apply_global8(A, mask8[0], base, ctx);
	if (err)
		return err;
	err = apply_global8(A, mask8[1], base + 8, ctx);
	return err;
}

static inline const char *
apply_global32(struct attrib_arena *A, uint32_t mask, int base, struct attrib_arena_apply_context *ctx) {
	if (mask == 0)
		return NULL;
	uint16_t mask16[2] = { mask & 0xffff, mask >> 16 };
	const char * err = apply_global16(A, mask16[0], base, ctx);
	if (err)
		return err;
	err = apply_global16(A, mask16[1], base + 16, ctx);
	return err;
}

const char *
attrib_arena_apply_global(struct attrib_arena *A, uint64_t mask, int base, struct attrib_arena_apply_context *ctx) {
	if (mask == 0)
		return NULL;
	uint32_t mask32[2] = { mask & 0xffffffff , mask >> 32 };
	const char * err = apply_global32(A, mask32[0], base, ctx);
	if (err)
		return err;
	err = apply_global32(A, mask32[1], base + 32, ctx);
	return err;
}

math_t
attrib_arena_remove(struct attrib_arena *A, attrib_id *prev) {
	if (*prev == INVALID_ATTRIB)
		return MATH_NULL;
	attrib_id current = *prev;
	attrib_type * a = get_attrib(A, current);
	if (a == NULL) {
		*prev = INVALID_ATTRIB;
		return MATH_NULL;
	}
	*prev = a->h.next;

	a->h.next = A->freelist;
	A->freelist = current;

	if (a->h.type == ATTRIB_UNIFORM_INSTANCE) {
		return a->u.u.m;
	} else {
		return MATH_NULL;
	}
}

int
attrib_arena_type(struct attrib_arena *A, int id) {
	attrib_type *a = get_attrib_from_id(A, id);
	if (a == NULL)
		return ATTRIB_NONE;
	return a->h.type;
}
