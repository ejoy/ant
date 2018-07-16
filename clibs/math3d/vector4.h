#ifndef ejoy_vector4_h
#define ejoy_vector4_h

#include "vector3.h"
#include "util.h"
struct vector4 {
	float x, y, z, w;
};

static inline float *
vector4_array(struct vector4 *v) {
	return (float *)v;
}

static inline struct vector3*
to_vec3(struct vector4* v) {
	return (struct vector3*)v;
}

static inline const struct vector3*
to_cvector3(const struct vector4* v) {
	return (const struct vector3*)v;
}

static inline int
vector4_equal(const struct vector4 *lhs, const struct vector4 *rhs){
	return 	is_equal(lhs->x, rhs->x) && 
			is_equal(lhs->y, rhs->y) && 
			is_equal(lhs->z, rhs->z) && 
			is_equal(lhs->w, rhs->w);
}

extern struct vector4 X_v4;
extern struct vector4 Y_v4;
extern struct vector4 Z_v4;
extern struct vector4 W_v4;

#endif //ejoy_vector4_h