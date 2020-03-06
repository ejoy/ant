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

const float * math3d_get_value(lua_State *L, struct lastack *LS, int index, int request_type);
const char * math3d_typename(uint32_t t);
int64_t math3d_stack_id(struct lua_State *L, struct lastack *LS, int index);
struct lastack* math3d_getLS(struct lua_State* L, int index);

#ifndef _MSC_VER
#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif
#endif // !_MSC_VER

#endif
