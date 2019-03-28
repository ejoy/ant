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

#endif

#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif
