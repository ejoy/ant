#ifndef math3d_util_h
#define math3d_util_h

extern "C"{
	#include "math3d.h"
};

#include "glm/glm.hpp"

glm::vec4
get_vec_value(lua_State* L, struct lastack* LS, int index);

void
assign_ref(lua_State* L, struct refobject* ref, int64_t rid);

float
get_table_item(lua_State* L, int tblidx, int idx);

template<typename VecType>
void
get_table_value(lua_State* L, int tblidx, int num, VecType& v) {
	for (int ii = 0; ii < num; ++ii) {
		v[ii] = get_table_item(L, tblidx, ii + 1);
	}
}

#define tov3(v4)	((const glm::vec3*)(&(v4.x)))

#endif //math3d_util_h