#ifndef ejoy_quaternion_h
#define ejoy_quaternion_h
#include <assert.h>
#include "util.h"

struct quaternion {
	float x, y, z, w;
};

static inline struct quaternion *
quaternion_mul(struct quaternion *q, const struct quaternion *a, const struct quaternion *b) {
	const float ax = a->x;
	const float ay = a->y;
	const float az = a->z;
	const float aw = a->w;

	const float bx = b->x;
	const float by = b->y;
	const float bz = b->z;
	const float bw = b->w;

	q->w = aw * bw - ax * bx - ay * by - az * bz;
	q->x = aw * bx + ax * bw + ay * bz - az * by;
	q->y = aw * by - ax * bz + ay * bw + az * bx;
	q->z = aw * bz + ax * by - ay * bx + az * bw;

	return q;
}

static inline struct quaternion *
quaternion_init_from_axis_angle(struct quaternion *q, const float axis[3], float angle){

	const float rad = TO_RADIAN(angle) * 0.5f;
	const float s = sinf(rad);

	float sLen = axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2];
	if (sLen == 0)
		sLen = 0.0001f;
	
	float invL = 1 / sqrtf(sLen);

	q->w = cosf(rad);
	q->x = s * axis[0] * invL;
	q->y = s * axis[1] * invL;
	q->z = s * axis[2] * invL;

	return q;
}

static inline struct quaternion *
quaternion_init_from_euler(struct quaternion *q, const struct euler *e) {
	const float yawRad = TO_RADIAN(e->yaw * 0.5f);
	const float pitchRad = TO_RADIAN(e->pitch * 0.5f);
	const float rollRad = TO_RADIAN(e->roll * 0.5f);

	struct quaternion roll	= { 0, 0, sinf(rollRad),	cosf(rollRad) };
	struct quaternion pitch = { sinf(pitchRad), 0, 0,	cosf(pitchRad) };
	struct quaternion yaw	= { 0, sinf(yawRad), 0,		cosf( yawRad) };
	quaternion_mul(q, &yaw, &pitch);
	quaternion_mul(q, q, &roll);
	return q;
}

static inline float
quaternion_square_length(const struct quaternion * q){
	return q->w * q->w + q->x * q->x + q->y * q->y + q->z * q->z;
}

static inline float
quaternion_length(const struct quaternion * q){
	return sqrtf(quaternion_square_length(q));
}

static inline int
quaternion_is_unit(const struct quaternion * q){
	return is_equal(quaternion_length(q), 1);	
}

static inline struct quaternion *
quaternion_normalize(struct quaternion *q){
	float sLen = quaternion_square_length(q);
	if (sLen == 0)
		return q;
	
	float invLen = 1.f / sqrtf(sLen);
	q->w *= invLen;
	q->x *= invLen;
	q->y *= invLen;
	q->z *= invLen;
	return q;
}


static inline struct quaternion *
quaternion_init(struct quaternion *q, float w, float x, float y, float z){
	q->w = w;
	q->x = x;
	q->y = y;
	q->z = z;

	return q;
}

static inline struct quaternion * 
quaternion_inverse(struct quaternion * q){
	q->x = -q->x;
	q->y = -q->y;
	q->z = -q->z;
	return q;
}
static inline struct quaternion *
quaternion_slerp(struct quaternion *q, const struct quaternion *a, const struct quaternion *b, float t) {
	float cosTheta = a->x * b->x + a->y * b->y + a->z * b->z + a->w * b->w;
	if (cosTheta < 0) {
		cosTheta = -cosTheta; 
		q->x = -b->x; q->y = -b->y;
		q->z = -b->z; q->w = -b->w;
	} else {
		*q = *b;
	}
	float scale0 = 1 - t, scale1 = t;
	if( (1 - cosTheta) > 0.001f ) {
		// use spherical interpolation
		float theta = acosf( cosTheta );
		float sinTheta = sinf( theta );
		scale0 = sinf( (1 - t) * theta ) / sinTheta;
		scale1 = sinf( t * theta ) / sinTheta;
	}

	q->x = a->x * scale0 + q->x * scale1;
	q->y = a->y * scale0 + q->y * scale1;
	q->z = a->z * scale0 + q->z * scale1;
	q->w = a->w * scale0 + q->w * scale1;

	return q;
}

static inline struct quaternion *
quaternion_nslerp(struct quaternion *q, const struct quaternion *a, const struct quaternion *b, float t) {
	// Normalized linear quaternion interpolation
	// Note: NLERP is faster than SLERP and commutative but does not yield constant velocity

	float cosTheta = a->x * b->x + a->y * b->y + a->z * b->z + a->w * b->w;
	
	if( cosTheta < 0 ) {
		q->x = a->x + (-b->x - a->x) * t;
		q->y = a->y + (-b->y - a->y) * t;
		q->z = a->z + (-b->z - a->z) * t;
		q->w = a->w + (-b->w - a->w) * t;
	} else {
		q->x = a->x + (b->x - a->x) * t;
		q->y = a->y + (b->y - a->y) * t;
		q->z = a->z + (b->z - a->z) * t;
		q->w = a->w + (b->w - a->w) * t;
	}

	float invLen = 1.0f / sqrtf( q->x * q->x + q->y * q->y + q->z * q->z + q->w * q->w );

	q->x *= invLen;
	q->y *= invLen;
	q->z *= invLen;
	q->w *= invLen;

	return q;
}

// reverse and normalize
static inline struct quaternion *
quaternion_inverted(struct quaternion * q) {
	float len = q->x * q->x + q->y * q->y + q->z * q->z + q->w * q->w;
	if( len > 0 ) {
		float invLen = - 1.0f / len;
		q->x *= invLen;
		q->y *= invLen;
		q->z *= invLen;
		q->w *= invLen;
		q->w = -q->w;
	} else {
		q->x = q->y = q->z = q->w = 0;
	}
	return q;
}

static inline void
quaternion_rotate_vec4(struct vector4 *r, const struct quaternion *q, const struct vector4 *v){
	/*
		the formula is : 
		q' = q * p * q^
		where:
			q is the rotating quaternion with unit length
			q^ is the reverse rotating quaternion
			p is a pure quaternion, it construct from a position where w need to set as 0

		we using left hand coordinate(z to screen, x to right, y to up)
		so quaternion multiplication from [left to right]
		actually, we have a more efficient way to multi quaternion and rotate vector
		we can derive from quaternion multiplication formula :
		q0 = [w0, v0] = [w0 + x0i + y0j + z0j]
		q1 = [w1, v1] = [w1 + x1i + y1j + z1j]
		q2 = q0 * q1 = [w0*w1 + v0 dot v1, w0*v1 + w1*v0 + v0 cross v1]
		so:
			q4 = q2 * q3
		the code is :
		{
			struct vector3 qv = {q->x, q->y, q->z};	// the pure quaternion
			struct vector3 uv, uuv;
			vector3_cross(&uv, qv, (const struct vector3*)v);			
			vector3_cross(&uuv, qv, &uv);
			struct vector3 result;
			vector3_add(&result, 
						vector3_mul_number(
							vector3_add(&result, vector3_mul_number(&uv, q->w), &uuv),
							2);	//v + ((uv * q.w) + uuv) * 2.f;
		}
	*/
	struct quaternion p;
	quaternion_init(&p, 0, v->x, v->y, v->z);	// to pure quaternion

	struct quaternion inv_q = *q;
	quaternion_inverse(&inv_q);

	struct quaternion prefix;
	quaternion_mul(&prefix, q, &p);
	struct quaternion result;
	quaternion_mul(&result, &prefix, &inv_q);	// result is pure quaternion
	assert(is_zero(result.w));

	r->x = result.x;
	r->y = result.y;
	r->z = result.z;
}
static inline void
vec4_rotate_quaternion(struct vector4 *r, const struct vector4 *v, const struct quaternion *q) {
	struct quaternion p = *q;
	quaternion_inverse(&p);
	quaternion_rotate_vec4(r, &p, v);
}


#endif //ejoy_quaternion_h