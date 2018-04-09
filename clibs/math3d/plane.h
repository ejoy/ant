#ifndef ejoy_plane_h
#define ejoy_plane_h

#include "vector3.h"

struct plane {
	struct vector3 normal;
	float dist;
};

static inline struct plane *
plane_init(struct plane *p, const struct vector3 *normal, float d ) {
	p->normal = *normal;
	// normalize
	float invLen = 1.0f / vector3_length(normal);
	p->normal.x *= invLen;
	p->normal.y *= invLen;
	p->normal.z *= invLen;
	p->dist = d * invLen;

	return p;
}

static inline struct plane *
plane_init_dot3(struct plane *p, const struct vector3 *v0, const struct vector3 *v1, const struct vector3 *v2) {
	struct vector3 a,b;
	vector3_vector(&a, v1, v0);
	vector3_vector(&b, v2, v0);

	vector3_cross(&p->normal, &a, &b);
	vector3_normalize(&p->normal);
	p->dist = -vector3_dot(&p->normal, v0);

	return p;
}

static inline float
plane_dist(const struct plane *p, const struct vector3 *v) {
	float d = vector3_dot(&p->normal, v);
	return d + p->dist;
}

#endif //ejoy_plane_h