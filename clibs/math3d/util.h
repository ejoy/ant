#ifndef math3d_util_h
#define math3d_util_h

extern "C"{
	#include "math3d.h"
};

#include "glm/glm.hpp"
#include "glm/gtc/constants.hpp"
#include "glm/ext/scalar_constants.hpp"
#include "glm/ext/scalar_relational.hpp"
#include "glm/ext/vector_relational.hpp"

glm::vec4
get_vec_value(lua_State* L, struct lastack* LS, int index);

glm::quat
get_quat_value(lua_State* L, struct lastack* LS, int index);

glm::mat4x4
get_mat_value(lua_State* L, struct lastack* LS, int index);

void
assign_ref(lua_State* L, struct refobject* ref, int64_t rid);

float
get_table_item(lua_State* L, int tblidx, int idx);

template<typename VecType> void
get_table_value(lua_State* L, int tblidx, int num, VecType& v) {
	for (int ii = 0; ii < num; ++ii) {
		v[ii] = get_table_item(L, tblidx, ii + 1);
	}
}

template<>
void
get_table_value(lua_State* L, int tblidx, int num, glm::mat4x4& v);

#define tov3(v4)	((const glm::vec3*)(&(v4.x)))

template<typename T>
inline bool
is_zero(const T& a, const T& e = T(glm::epsilon<float>())) {
	return glm::all(glm::equal(a, glm::zero<T>(), e));
}

inline bool
is_zero(const float& a, float e = glm::epsilon<float>()) {
	return glm::equal(a, glm::zero<float>(), e);
}

template<typename T>
inline bool
is_equal(const T& a, const T& b, const T& e = T(glm::epsilon<float>())) {
	return is_zero(a - b, e);
}

#endif //math3d_util_h