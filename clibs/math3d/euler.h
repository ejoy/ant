#ifndef ejoy_euler_h
#define ejoy_euler_h
#include "util.h"

struct euler {
	float yaw;		// rotate y-axis
	float pitch;	// rotate x-axis	
	float roll;		// rotate z-axis
};

static inline float* 
euler_array(struct euler *e) {
	return &e->yaw;
}

static inline struct euler *
euler_to_degree(struct euler *e) {
	if (e->yaw)
		e->yaw = TO_DEGREE(e->yaw);
	if (e->pitch)
		e->pitch = TO_DEGREE(e->pitch);
	if (e->roll)
		e->roll = TO_DEGREE(e->roll);
	return e;
}

static inline struct euler *
euler_to_radian(struct euler *e) {
	if (e->yaw)
		e->yaw = TO_RADIAN(e->yaw);
	if (e->pitch)
		e->pitch = TO_RADIAN(e->pitch);
	if (e->roll)
		e->roll = TO_RADIAN(e->roll);

	return e;
}

static inline int
euler_is_identity(const struct euler *e){
	return e->yaw == 0 && e->pitch == 0 && e->roll == 0;
}
#endif //ejoy_euler_h