#ifndef VARIANT_LENGTH_ARRAY_H
#define VARIANT_LENGTH_ARRAY_H

#include <stddef.h>

#define VLA_STACK_SIZE 244

#define VLA_TYPE_STACK 0
#define VLA_TYPE_HEAP 1
#define VLA_TYPE_LUA 2
#define VLA_TYPE_MASK 0xf
#define VLA_TYPE_NEEDCLOSE 0x10
#define VLA_COMMON_HEADER int type;	int n; int cap;

struct vla_header { VLA_COMMON_HEADER };
struct vla_stack;
struct vla_heap;
struct vla_lua;

union vla_handle {
	struct vla_header *h;
	struct vla_stack *s;
	struct vla_heap *m;
	struct vla_lua *l;
};

typedef union vla_handle vla_handle_t;

struct vla_stack {
	VLA_COMMON_HEADER
	unsigned char buffer[VLA_STACK_SIZE];
	vla_handle_t extra;
};

static inline vla_handle_t
vla_stack_new_(struct vla_stack *s, int esize) {
	s->type = VLA_TYPE_STACK;
	s->n = 0;
	s->cap = (VLA_STACK_SIZE + esize - 1) / esize;
	s->extra.h = NULL;
	vla_handle_t ret;
	ret.s = s;
	return ret;
};

#define vla_stack_handle(name, type) \
	struct vla_stack name##_stack_; \
	vla_handle_t name = vla_stack_new_(&name##_stack_, sizeof(type))

vla_handle_t vla_heap_new(int n, int esize);
vla_handle_t vla_lua_new(void *L, int n, int esize);

#define vla_new(type, n, L) (L == NULL ? vla_heap_new(n, sizeof(type)) : vla_lua_new(L, n, sizeof(type)))

void vla_handle_map_(vla_handle_t h, void **p);

static inline void
vla_using_(vla_handle_t h, void **p) {
	if ((h.h->type & VLA_TYPE_MASK) == VLA_TYPE_STACK && h.s->extra.h == NULL)
		*p = (void *)h.s->buffer;
	else
		vla_handle_map_(h, p);

}

int vla_init_lua_(void *L);

#define vla_using(name, type, h, L) \
	type * name; \
	vla_handle_t * name##_ref_ = &h; \
	int name##_lua_ = 0; (void) name##_lua_; \
	if (L) { name##_lua_ = vla_init_lua_(L); } \
	vla_using_(h, (void **)&name)

#define vla_sync(name) vla_using_( *name##_ref_, (void **)&name)

void vla_handle_close_(vla_handle_t h);

static inline void
vla_close_handle(vla_handle_t h) {
	if (h.h && (h.h->type & VLA_TYPE_NEEDCLOSE)) {
		vla_handle_close_(h);
	}
}

#define vla_close(name) vla_close_handle(*name##_ref_)

void vla_handle_resize_(void *L, vla_handle_t *h, int n, int esize, int *lua_id);

static inline void
vla_resize_(void *L, void **p, vla_handle_t *h, int n, int esize, int *lua_id) {
	if (n <= h->h->cap)
		h->h->n = n;
	else {
		vla_handle_resize_(L, h, n, esize, lua_id);
		vla_handle_map_(*h, p);
	}
}

#define vla_resize(name, n, L) vla_resize_(L, (void **)&name, name##_ref_, n, sizeof(*name), &name##_lua_)

#define vla_size(name) (name##_ref_->h->n)

#define vla_push(name, v, L) vla_resize(name, vla_size(name) + 1, L); name[vla_size(name)-1] = v

#define vla_luaid(name, L) (lua_isnoneornil(L, name##_lua_) ? 0 : name##_lua_)

#endif