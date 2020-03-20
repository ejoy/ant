#ifndef math3d_lua_binding_h
#define math3d_lua_binding_h

#include "linalg.h"
#include <lua.h>

struct boxstack {
	struct lastack * LS;
	const void * refmeta;
};

struct refobject {
	int64_t id;
};

#define MATH3D_STACK "_MATHSTACK"

int math3d_homogeneous_depth();

// binding functions

const float * math3d_from_lua(lua_State *L, struct lastack *LS, int index, int type);
const float * math3d_from_lua_id(lua_State *L, struct lastack *LS, int index, int *type);

static inline struct lastack *
math3d_getLS(lua_State *L) {
	struct boxstack *bs = lua_touserdata(L, lua_upvalueindex(1));
	return bs->LS;
}

#endif
