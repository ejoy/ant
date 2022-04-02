#ifndef math3d_lua_binding_h
#define math3d_lua_binding_h

#include "linalg.h"
#include <lua.h>

struct math3d_api {
	struct lastack * LS;
	const void * refmeta;
	const float * (*from_lua)(lua_State *L, struct lastack *LS, int index, int type);
	const float * (*from_lua_id)(lua_State *L, struct lastack *LS, int index, int *type);
	const float * (*value)(struct lastack *LS, int64_t id, int *type);
	void (*push)(lua_State *L, struct lastack *LS, const float *v, int type);
	int64_t (*mark_id)(lua_State *L, struct lastack *LS, int idx);
	void (*unmark_id)(struct lastack *LS, int64_t id);
};

#define MATH3D_STACK "_MATHSTACK"

// binding functions

static inline const float *
math3d_from_lua(lua_State *L, struct math3d_api *S, int index, int type) {
	return S->from_lua(L, S->LS, index, type);
}

static inline const float *
math3d_from_lua_id(lua_State *L, struct math3d_api *S, int index, int *type) {
	return S->from_lua_id(L, S->LS, index, type);
}

static inline void
math3d_push(lua_State *L, struct math3d_api *S, const float *v, int type) {
	S->push(L, S->LS, v, type);
}

static inline int64_t
math3d_mark_id(lua_State *L, struct math3d_api *S, int idx) {
	return S->mark_id(L, S->LS, idx);
}

static inline void
math3d_unmark_id(struct math3d_api *S, int64_t id) {
	S->unmark_id(S->LS, id);
}

static inline const float *
math3d_value(struct math3d_api *S, int64_t id, int *type) {
	return S->value(S->LS, id, type);
}

#endif
