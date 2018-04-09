#ifndef ejoy_vector4_h
#define ejoy_vector4_h

#include "vector3.h"

struct vector4 {
	float x, y, z, w;
};

static inline float *
vector4_array(struct vector4 *v) {
	return (float *)v;
}

static inline struct vector3*
to_vector3(struct vector4* v) {
	return (struct vector3*)v;
}

static inline const struct vector3*
to_cvector3(const struct vector4* v) {
	return (const struct vector3*)v;
}

#endif //ejoy_vector4_h