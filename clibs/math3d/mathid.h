#ifndef MATH_ID_H
#define MATH_ID_H

#include <stdint.h>
#include <stddef.h>

struct math_context;

typedef struct { uint64_t idx; } math_t;
static const math_t MATH_NULL = { 0 };

#define MATH_TYPE_NULL 0
#define MATH_TYPE_MAT 1
#define MATH_TYPE_VEC4 2
#define MATH_TYPE_QUAT 3
#define MATH_TYPE_REF 4
#define MATH_TYPE_COUNT 5

struct math_context * math_new();
void math_delete(struct math_context *);
size_t math_memsize(struct math_context *);
void math_frame(struct math_context *);
math_t math_import(struct math_context *, const float *v, int type, int size);
math_t math_ref(struct math_context *, const float *v, int type, int size);
math_t math_premark(struct math_context *, int type, int size);
math_t math_mark(struct math_context *, math_t id);
void math_unmark(struct math_context *, math_t id);
const float * math_value(struct math_context *, math_t id);
float *math_init(struct math_context *, math_t id);
math_t math_index(struct math_context *, math_t id, int index);
int math_valid(struct math_context *, math_t id);
int math_marked(struct math_context *, math_t id);
void math_print(struct math_context *, math_t id);	// for debug only
const char * math_typename(int type);

static inline int
math_issame(math_t id1, math_t id2) {
	return id1.idx == id2.idx;
}

static inline int
math_isnull(math_t id) {
	return id.idx == MATH_NULL.idx;
}

static inline math_t
math_matrix(struct math_context *ctx, const float *v) {
	return math_import(ctx, v, MATH_TYPE_MAT, 1);
}

static inline math_t
math_vec4(struct math_context *ctx, const float *v) {
	return math_import(ctx, v, MATH_TYPE_VEC4, 1);
}

static inline math_t
math_quat(struct math_context *ctx, const float *v) {
	return math_import(ctx, v, MATH_TYPE_QUAT, 1);
}

struct math_id {
	uint32_t index		: 20;
	uint32_t size		: 12;	// array size - 1 (0 : single object), for ref type, it's index
	uint32_t frame      : 28;
	uint32_t type       : 3;
	uint32_t transient  : 1;	// 0: persisent
};

static inline math_t
math_identity(int type) {
	union {
		math_t id;
		struct math_id s;
	} u;
	u.id.idx = 0;
	u.s.type = type;
	return u.id;
}

static inline int
math_isidentity(math_t id) {
	union {
		math_t id;
		struct math_id s;
	} u;
	u.id = id;
	return (!u.s.transient && u.s.frame == 0);
}

int math_ref_size_(struct math_context *, struct math_id id);
int math_ref_type_(struct math_context *, struct math_id id);

static inline int
math_type(struct math_context *ctx, math_t id) {
	union {
		math_t id;
		struct math_id s;
	} u;
	u.id = id;
	if (u.s.type != MATH_TYPE_REF)
		return u.s.type;
	return math_ref_type_(ctx, u.s);
}

static inline int
math_size(struct math_context *ctx, math_t id) {
	union {
		math_t id;
		struct math_id s;
	} u;
	u.id = id;
	if (u.s.type != MATH_TYPE_REF)
		return u.s.size + 1;
	return math_ref_size_(ctx, u.s);
}

#endif
