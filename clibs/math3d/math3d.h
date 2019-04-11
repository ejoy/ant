#ifndef math3d_lua_binding_h
#define math3d_lua_binding_h

#define LINALG "LINALG"
#define LINALG_REF "LINALG_REF"

struct boxstack {
	struct lastack *LS;	
};

struct refobject {
	struct lastack *LS;
	int64_t id;
};

int64_t
get_stack_id(lua_State *L, struct lastack *LS, int index);

#ifndef _MSC_VER
#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif
#endif // !_MSC_VER

#endif
