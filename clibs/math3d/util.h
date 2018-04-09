#ifndef ejoy_math3d_util_h
#define ejoy_math3d_util_h
#include <math.h>

#define TO_RADIAN(_DEGREE)	(_DEGREE) * (M_PI / 180)
#define TO_DEGREE(_RADIAN)	(_RADIAN) *(180 / M_PI)

#define MIN_THRESHOLD 0.00001f

static inline int is_zero_with_threshold(float value, float threshold){
	return -threshold <= value && value <= threshold;
}

static inline int is_zero(float value){
	return is_zero_with_threshold(value, MIN_THRESHOLD);
}

static inline int is_equal_with_threshold(float lhs, float rhs, float threshold){
	return is_zero_with_threshold(lhs - rhs, threshold);
}

static inline int is_equal(float lhs, float rhs){
	return is_equal_with_threshold(lhs, rhs, MIN_THRESHOLD);
}

static inline float
minf(float a, float b) {
	return a < b ? a : b;
}

static inline float
maxf(float a, float b) {
	return a > b ? a : b;
}

#endif //ejoy_math3d_util_h