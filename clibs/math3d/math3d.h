#ifndef math3d_lua_binding_h
#define math3d_lua_binding_h

#include "mathid.h"
#include <lua.h>

struct math3d_api {
	struct math_context * MC;
	const void * refmeta;
	const float * (*from_lua)(lua_State *L, struct math_context *MC, int index, int type);
	const float * (*from_lua_id)(lua_State *L, struct math_context *MC, int index, int *type);
	float * (*getptr)(struct math_context *MC, math_t id, int *type);
	void (*push)(lua_State *L, struct math_context *MC, const float *v, int type);
	void (*ref)(lua_State *L, struct math_context *MC, const float *v, int type);
	math_t (*mark_id)(lua_State *L, struct math_context *MC, int idx);
	void (*unmark_id)(struct math_context *MC, math_t id);
};

#define MATH3D_CONTEXT "_MATHCONTEXT"

// binding functions

static inline const float *
math3d_from_lua(lua_State *L, struct math3d_api *M, int index, int type) {
	return M->from_lua(L, M->MC, index, type);
}

static inline const float *
math3d_from_lua_id(lua_State *L, struct math3d_api *M, int index, int *type) {
	return M->from_lua_id(L, M->MC, index, type);
}

static inline void
math3d_push(lua_State *L, struct math3d_api *M, const float *v, int type) {
	M->push(L, M->MC, v, type);
}

static inline void
math3d_ref(lua_State *L, struct math3d_api *M, const float *v, int type) {
	M->ref(L, M->MC, v, type);
}

static inline math_t
math3d_mark_id(lua_State *L, struct math3d_api *M, int idx) {
	return M->mark_id(L, M->MC, idx);
}

static inline void
math3d_unmark_id(struct math3d_api *M, math_t id) {
	M->unmark_id(M->MC, id);
}

static inline const float *
math3d_value(struct math3d_api *M, math_t id, int *type) {
	return M->getptr(M->MC, id, type);
}

static inline float *
math3d_init(struct math3d_api *M, math_t id, int *type) {
	return M->getptr(M->MC, id, type);
}

#endif
