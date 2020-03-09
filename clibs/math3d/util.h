#ifndef math3d_util_h
#define math3d_util_h

#include "glm/glm.hpp"
#include "glm/gtc/constants.hpp"
#include "glm/ext/scalar_constants.hpp"
#include "glm/ext/scalar_relational.hpp"
#include "glm/ext/vector_relational.hpp"

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