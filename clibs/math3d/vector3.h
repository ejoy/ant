#ifndef ejoy_vector3_h
#define ejoy_vector3_h

#include <math.h>
#include "euler.h"

struct vector3 {
	float x, y, z;
};

static inline float *
vector3_array(struct vector3 *v) {
	return (float *)v;
}

static inline float
vector3_dot(const struct vector3 *a, const struct vector3 *b) {
	return a->x * b->x + a->y * b->y + a->z * b->z;
}

static inline struct vector3 *
vector3_invert(struct vector3 * v) {
	v->x = -v->x;
	v->y = -v->y;
	v->z = -v->z;
	return v;
}


static inline struct vector3*
vector3_add(struct vector3* r, const struct vector3* v0, const struct vector3* v1) {
	r->x = v0->x + v1->x;
	r->y = v0->y + v1->y;
	r->z = v0->z + v1->z;
	return r;
}

static inline struct vector3*
vector3_mul_number(struct vector3 *v, float n) {
	v->x *= n;
	v->y *= n;
	v->z *= n;
	return v;
}

static inline struct vector3 *
vector3_cross(struct vector3 *v, const struct vector3 *a, const struct vector3 *b) {
	float x = a->y * b->z - a->z * b->y;
	float y = a->z * b->x - a->x * b->z;
	float z = a->x * b->y - a->y * b->x;

	v->x = x;
	v->y = y;
	v->z = z;

	return v;
}

static inline struct vector3 *
vector3_vector(struct vector3 *v, const struct vector3 *p1, const struct vector3 *p2) {
	v->x = p1->x - p2->x;
	v->y = p1->y - p2->y;
	v->z = p1->z - p2->z;

	return v;
}

static inline float
vector3_length(const struct vector3 *v) {
	return sqrtf(v->x * v->x + v->y * v->y + v->z * v->z );
}

static inline struct vector3 *
vector3_normalize(struct vector3 *v) {
	float invLen = 1.0f / vector3_length(v);
	v->x *= invLen;
	v->y *= invLen;
	v->z *= invLen;

	return v;
}

static inline struct vector3 *
vector3_lerp(struct vector3 *v, const struct vector3 *a, const struct vector3 *b, float f) {
	v->x = a->x + (b->x - a->x) * f;
	v->y = a->y + (b->y - a->y) * f;
	v->z = a->z + (b->z - a->z) * f;
	return v;
}

static inline struct euler *
vector3_to_rotation(struct euler *e, const struct vector3 *r) {
	// Assumes that the unrotated view vector is (0, 0, 1)
	e->pitch = -asinf(r->y);	// left hand coordinate, need negative the asinf result
	e->yaw = (r->x != 0 || r->z != 0) ? atan2f(r->x, r->z) : 0;
	e->roll = 0;

	return e;
}

#endif //ejoy_vector3_h