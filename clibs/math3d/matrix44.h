#ifndef ejoy_matrix44_h
#define ejoy_matrix44_h

#include "util.h"
#include "vector3.h"
#include "vector4.h"

#include "quaternion.h"

union matrix44 {
	float c[4][4];
	float x[16];
};

#define C m->c

static inline union matrix44 *
matrix44_identity(union matrix44 * m) {
	C[0][0] = 1; C[1][0] = 0; C[2][0] = 0; C[3][0] = 0;
	C[0][1] = 0; C[1][1] = 1; C[2][1] = 0; C[3][1] = 0;
	C[0][2] = 0; C[1][2] = 0; C[2][2] = 1; C[3][2] = 0;
	C[0][3] = 0; C[1][3] = 0; C[2][3] = 0; C[3][3] = 1;

	return m;
}

static inline union matrix44 *
matrix44_from_quaternion(union matrix44 *m, const struct quaternion *q) {
	const float x = q->x;
	const float y = q->y;
	const float z = q->z;
	const float w = q->w;

	const float x2  =  x + x;
	const float y2  =  y + y;
	const float z2  =  z + z;
	const float x2x = x2 * x;
	const float x2y = x2 * y;
	const float x2z = x2 * z;
	const float x2w = x2 * w;
	const float y2y = y2 * y;
	const float y2z = y2 * z;
	const float y2w = y2 * w;
	const float z2z = z2 * z;
	const float z2w = z2 * w;

	C[0][0] = 1.0f - (y2y + z2z);
	C[0][1] =         x2y - z2w;
	C[0][2] =         x2z + y2w;
	C[0][3] = 0.0f;

	C[1][0] =         x2y + z2w;
	C[1][1] = 1.0f - (x2x + z2z);
	C[1][2] =         y2z - x2w;
	C[1][3] = 0.0f;

	C[2][0] =         x2z - y2w;
	C[2][1] =         y2z + x2w;
	C[2][2] = 1.0f - (x2x + y2y);
	C[2][3] = 0.0f;

	C[3][0] = 0.0f;
	C[3][1] = 0.0f;
	C[3][2] = 0.0f;
	C[3][3] = 1.0f;

	return m;
}

static inline union matrix44 *
matrix44_transmat(union matrix44 *m, float x, float y, float z) {
	matrix44_identity(m);
	C[3][0] = x;
	C[3][1] = y;
	C[3][2] = z;

	return m;
}

static inline union matrix44 *
matrix44_trans(union matrix44 *m, float x, float y, float z) {
	C[3][0] += x;
	C[3][1] += y;
	C[3][2] += z;

	return m;
}

static inline union matrix44 *
matrix44_scalemat(union matrix44 *m, float x, float y, float z) {
	matrix44_identity(m);
	C[0][0] = x;
	C[1][1] = y;
	C[2][2] = z;

	return m;
}

static inline union matrix44 *
matrix44_scale(union matrix44 *m, float x, float y, float z) {
	C[0][0] *= x;
	C[0][1] *= y;
	C[0][2] *= z;

	C[1][0] *= x;
	C[1][1] *= y;
	C[1][2] *= z;

	C[2][0] *= x;
	C[2][1] *= y;
	C[2][2] *= z;

	return m;
}

static inline union matrix44 *
matrix44_perspective(union matrix44 *m, float l, float r, float b, float t, float n, float f, int homogeneousDepth) {
	matrix44_identity(m);
	float *mx = m->x;
	const float diff = f - n;
	const float aa = (homogeneousDepth ? (f + n) : f) / diff;
	const float bb = homogeneousDepth ? 2.0f * f * n / diff : n * aa;

	mx[0] = 2.0f * n / (r - l);
	mx[5] = 2.0f * n / (t - b);
	mx[8] = -(r + l) / (r - l);
	mx[9] = -(t + b) / (t - b);
	mx[10] = aa;
	mx[11] = 1.0f;
	mx[14] = -bb;
	mx[15] = 0;

	return m;
}

static inline union matrix44 *
matrix44_ortho(union matrix44 *m, float l, float r, float b, float t, float n, float f, int homogeneousDepth) {
	matrix44_identity(m);
	float *mx = m->x;

	mx[0] = 2.0f / (r - l);
	mx[5] = 2.0f / (t - b);
	mx[10] = (homogeneousDepth ? 2.0f : 1.0f)/ (f - n);
	mx[12] = -(r + l) / (r - l);
	mx[13] = -(t + b) / (t - b);
	mx[14] = (homogeneousDepth ? (f + n) : n) / (n - f);

	return m;
}

// Left hand
static inline union matrix44 * 
matrix44_lookat_eye_direction(union matrix44 *m, struct vector3 *eye, struct vector3 *direction, struct vector3 *up_) {
	struct vector3 view, right;
	struct vector3 up;
	if (up_) {
		up = *up_;
	} else {
		up.x = 0;
		up.y = 1.0f;
		up.z = 0;
	}
	view = *direction;
	vector3_normalize(&view);
	vector3_normalize(vector3_cross(&right, &up, &view));
	vector3_cross(&up, &view, &right);

	float *mx = m->x;
	mx[0] = right.x;
	mx[1] = up.x;
	mx[2] = view.x;
	mx[3] = 0.0f;

	mx[4] = right.y;
	mx[5] = up.y;
	mx[6] = view.y;
	mx[7] = 0.0f;

	mx[8] = right.z;
	mx[9] = up.z;
	mx[10] = view.z;
	mx[11] = 0.0f;

	mx[12] = -vector3_dot(&right, eye);
	mx[13] = -vector3_dot(&up, eye);
	mx[14] = -vector3_dot(&view, eye);
	mx[15] = 1.f;

	return m;
}

static inline union matrix44 *
matrix44_lookat(union matrix44 *m, struct vector3 *eye, struct vector3 *at, struct vector3 *up_) {
	struct vector3 view;	
	return matrix44_lookat_eye_direction(m, eye, vector3_vector(&view, at, eye), up_);
}

static inline union matrix44 *
matrix44_fastmul43(union matrix44 *m, const union matrix44 *m1, const union matrix44 *m2) {
	// Note: m may not be the same as m1 or m2

	const float *m2x = m1->x;
	const float *m1x = m2->x;
	float *mx = m->x;
		
	mx[0] = m1x[0] * m2x[0] + m1x[4] * m2x[1] + m1x[8] * m2x[2];
	mx[1] = m1x[1] * m2x[0] + m1x[5] * m2x[1] + m1x[9] * m2x[2];
	mx[2] = m1x[2] * m2x[0] + m1x[6] * m2x[1] + m1x[10] * m2x[2];
	mx[3] = 0.0f;

	mx[4] = m1x[0] * m2x[4] + m1x[4] * m2x[5] + m1x[8] * m2x[6];
	mx[5] = m1x[1] * m2x[4] + m1x[5] * m2x[5] + m1x[9] * m2x[6];
	mx[6] = m1x[2] * m2x[4] + m1x[6] * m2x[5] + m1x[10] * m2x[6];
	mx[7] = 0.0f;

	mx[8] = m1x[0] * m2x[8] + m1x[4] * m2x[9] + m1x[8] * m2x[10];
	mx[9] = m1x[1] * m2x[8] + m1x[5] * m2x[9] + m1x[9] * m2x[10];
	mx[10] = m1x[2] * m2x[8] + m1x[6] * m2x[9] + m1x[10] * m2x[10];
	mx[11] = 0.0f;

	mx[12] = m1x[0] * m2x[12] + m1x[4] * m2x[13] + m1x[8] * m2x[14] + m1x[12] * m2x[15];
	mx[13] = m1x[1] * m2x[12] + m1x[5] * m2x[13] + m1x[9] * m2x[14] + m1x[13] * m2x[15];
	mx[14] = m1x[2] * m2x[12] + m1x[6] * m2x[13] + m1x[10] * m2x[14] + m1x[14] * m2x[15];
	mx[15] = 1.0f;

	return m;
}

static inline void
vector4_mul_matrix44(float * r, const float *v, const union matrix44 *m) {
	r[0] = v[0] * C[0][0] + v[1] * C[1][0] + v[2] * C[2][0] + v[3] * C[3][0];
	r[1] = v[0] * C[0][1] + v[1] * C[1][1] + v[2] * C[2][1] + v[3] * C[3][1];
	r[2] = v[0] * C[0][2] + v[1] * C[1][2] + v[2] * C[2][2] + v[3] * C[3][2];
	r[3] = v[0] * C[0][3] + v[1] * C[1][3] + v[2] * C[2][3] + v[3] * C[3][3];
}

static inline union matrix44 *
matrix44_mul(union matrix44 *m, const union matrix44 *m1, const union matrix44 *m2) {
	union matrix44 mf;

	vector4_mul_matrix44(mf.c[0], m1->c[0], m2);
	vector4_mul_matrix44(mf.c[1], m1->c[1], m2);
	vector4_mul_matrix44(mf.c[2], m1->c[2], m2);
	vector4_mul_matrix44(mf.c[3], m1->c[3], m2);

	*m = mf;

	return m;
}

static inline union matrix44 *
matrix44_rot_axis(union matrix44 *m, const struct vector3 *axis, float angle) {
	struct quaternion q;
	quaternion_init_from_axis_angle(&q, &axis->x, TO_RADIAN(angle));
	return matrix44_from_quaternion(m, &q);
}

extern union matrix44 *
matrix44_rot(union matrix44 *m, const struct euler *e);

// vector * matrix
static inline struct vector3 *
vector3_mul(struct vector3 *v, const union matrix44 *m) {
	float x = v->x * C[0][0] + v->y * C[1][0] + v->z * C[2][0] + C[3][0];
	float y = v->x * C[0][1] + v->y * C[1][1] + v->z * C[2][1] + C[3][1];
	float z = v->x * C[0][2] + v->y * C[1][2] + v->z * C[2][2] + C[3][2];

	v->x = x;
	v->y = y;
	v->z = z;

	return v;
}

static inline struct vector3 *
vector3_mulH(struct vector3 *v, const union matrix44 *m) {
	float ww = v->x * C[0][3] + v->y * C[1][3] + v->z * C[2][3] + C[3][3];
	ww = fabs(ww);
	vector3_mul(v, m);
	v->x /= ww;
	v->y /= ww;
	v->z /= ww;
	return v;
}

static inline struct vector4 *
vector4_mul(struct vector4 *v, const union matrix44 *m) {
	float tmp[4];
	vector4_mul_matrix44(tmp, (const float *)v,m);

	v->x = tmp[0];
	v->y = tmp[1];
	v->z = tmp[2];
	v->w = tmp[3];
	return v;
}

static inline void
vector4_mul_scalar(float *r, const struct vector4 *v, float scalar) {
	r[0] = v->x * scalar;
	r[1] = v->y * scalar;
	r[2] = v->z * scalar;
	r[3] = v->w;	
}

static inline struct vector3 *
vector3_mul33(struct vector3 *v, const union matrix44 *m) {
	float x = v->x * C[0][0] + v->y * C[1][0] + v->z * C[2][0];
	float y = v->x * C[0][1] + v->y * C[1][1] + v->z * C[2][1];
	float z = v->x * C[0][2] + v->y * C[1][2] + v->z * C[2][2];

	v->x = x;
	v->y = y;
	v->z = z;

	return v;
}

static inline union matrix44 *
matrix44_transposed(union matrix44 *m) {
	int x,y;
	for (y = 0; y < 4; ++y ) {
		for(x = y + 1; x < 4; ++x ) {
			float tmp = C[x][y];
			C[x][y] = C[y][x];
			C[y][x] = tmp;
		}
	}

	return m;
}

static inline float 
matrix44_determinant(const union matrix44 *m) {
	return 
		C[0][3]*C[1][2]*C[2][1]*C[3][0] - C[0][2]*C[1][3]*C[2][1]*C[3][0] - C[0][3]*C[1][1]*C[2][2]*C[3][0] + C[0][1]*C[1][3]*C[2][2]*C[3][0] +
		C[0][2]*C[1][1]*C[2][3]*C[3][0] - C[0][1]*C[1][2]*C[2][3]*C[3][0] - C[0][3]*C[1][2]*C[2][0]*C[3][1] + C[0][2]*C[1][3]*C[2][0]*C[3][1] +
		C[0][3]*C[1][0]*C[2][2]*C[3][1] - C[0][0]*C[1][3]*C[2][2]*C[3][1] - C[0][2]*C[1][0]*C[2][3]*C[3][1] + C[0][0]*C[1][2]*C[2][3]*C[3][1] +
		C[0][3]*C[1][1]*C[2][0]*C[3][2] - C[0][1]*C[1][3]*C[2][0]*C[3][2] - C[0][3]*C[1][0]*C[2][1]*C[3][2] + C[0][0]*C[1][3]*C[2][1]*C[3][2] +
		C[0][1]*C[1][0]*C[2][3]*C[3][2] - C[0][0]*C[1][1]*C[2][3]*C[3][2] - C[0][2]*C[1][1]*C[2][0]*C[3][3] + C[0][1]*C[1][2]*C[2][0]*C[3][3] +
		C[0][2]*C[1][0]*C[2][1]*C[3][3] - C[0][0]*C[1][2]*C[2][1]*C[3][3] - C[0][1]*C[1][0]*C[2][2]*C[3][3] + C[0][0]*C[1][1]*C[2][2]*C[3][3];
}

static inline union matrix44 *
matrix44_inverted(union matrix44 *dst, const union matrix44 *m) {
	float d = matrix44_determinant(m);
	if( d == 0 ) {
		*dst = *m;
		return dst;
	}
	d = 1.0f / d;
		
	dst->c[0][0] = d * (C[1][2]*C[2][3]*C[3][1] - C[1][3]*C[2][2]*C[3][1] + C[1][3]*C[2][1]*C[3][2] - C[1][1]*C[2][3]*C[3][2] - C[1][2]*C[2][1]*C[3][3] + C[1][1]*C[2][2]*C[3][3]);
	dst->c[0][1] = d * (C[0][3]*C[2][2]*C[3][1] - C[0][2]*C[2][3]*C[3][1] - C[0][3]*C[2][1]*C[3][2] + C[0][1]*C[2][3]*C[3][2] + C[0][2]*C[2][1]*C[3][3] - C[0][1]*C[2][2]*C[3][3]);
	dst->c[0][2] = d * (C[0][2]*C[1][3]*C[3][1] - C[0][3]*C[1][2]*C[3][1] + C[0][3]*C[1][1]*C[3][2] - C[0][1]*C[1][3]*C[3][2] - C[0][2]*C[1][1]*C[3][3] + C[0][1]*C[1][2]*C[3][3]);
	dst->c[0][3] = d * (C[0][3]*C[1][2]*C[2][1] - C[0][2]*C[1][3]*C[2][1] - C[0][3]*C[1][1]*C[2][2] + C[0][1]*C[1][3]*C[2][2] + C[0][2]*C[1][1]*C[2][3] - C[0][1]*C[1][2]*C[2][3]);
	dst->c[1][0] = d * (C[1][3]*C[2][2]*C[3][0] - C[1][2]*C[2][3]*C[3][0] - C[1][3]*C[2][0]*C[3][2] + C[1][0]*C[2][3]*C[3][2] + C[1][2]*C[2][0]*C[3][3] - C[1][0]*C[2][2]*C[3][3]);
	dst->c[1][1] = d * (C[0][2]*C[2][3]*C[3][0] - C[0][3]*C[2][2]*C[3][0] + C[0][3]*C[2][0]*C[3][2] - C[0][0]*C[2][3]*C[3][2] - C[0][2]*C[2][0]*C[3][3] + C[0][0]*C[2][2]*C[3][3]);
	dst->c[1][2] = d * (C[0][3]*C[1][2]*C[3][0] - C[0][2]*C[1][3]*C[3][0] - C[0][3]*C[1][0]*C[3][2] + C[0][0]*C[1][3]*C[3][2] + C[0][2]*C[1][0]*C[3][3] - C[0][0]*C[1][2]*C[3][3]);
	dst->c[1][3] = d * (C[0][2]*C[1][3]*C[2][0] - C[0][3]*C[1][2]*C[2][0] + C[0][3]*C[1][0]*C[2][2] - C[0][0]*C[1][3]*C[2][2] - C[0][2]*C[1][0]*C[2][3] + C[0][0]*C[1][2]*C[2][3]);
	dst->c[2][0] = d * (C[1][1]*C[2][3]*C[3][0] - C[1][3]*C[2][1]*C[3][0] + C[1][3]*C[2][0]*C[3][1] - C[1][0]*C[2][3]*C[3][1] - C[1][1]*C[2][0]*C[3][3] + C[1][0]*C[2][1]*C[3][3]);
	dst->c[2][1] = d * (C[0][3]*C[2][1]*C[3][0] - C[0][1]*C[2][3]*C[3][0] - C[0][3]*C[2][0]*C[3][1] + C[0][0]*C[2][3]*C[3][1] + C[0][1]*C[2][0]*C[3][3] - C[0][0]*C[2][1]*C[3][3]);
	dst->c[2][2] = d * (C[0][1]*C[1][3]*C[3][0] - C[0][3]*C[1][1]*C[3][0] + C[0][3]*C[1][0]*C[3][1] - C[0][0]*C[1][3]*C[3][1] - C[0][1]*C[1][0]*C[3][3] + C[0][0]*C[1][1]*C[3][3]);
	dst->c[2][3] = d * (C[0][3]*C[1][1]*C[2][0] - C[0][1]*C[1][3]*C[2][0] - C[0][3]*C[1][0]*C[2][1] + C[0][0]*C[1][3]*C[2][1] + C[0][1]*C[1][0]*C[2][3] - C[0][0]*C[1][1]*C[2][3]);
	dst->c[3][0] = d * (C[1][2]*C[2][1]*C[3][0] - C[1][1]*C[2][2]*C[3][0] - C[1][2]*C[2][0]*C[3][1] + C[1][0]*C[2][2]*C[3][1] + C[1][1]*C[2][0]*C[3][2] - C[1][0]*C[2][1]*C[3][2]);
	dst->c[3][1] = d * (C[0][1]*C[2][2]*C[3][0] - C[0][2]*C[2][1]*C[3][0] + C[0][2]*C[2][0]*C[3][1] - C[0][0]*C[2][2]*C[3][1] - C[0][1]*C[2][0]*C[3][2] + C[0][0]*C[2][1]*C[3][2]);
	dst->c[3][2] = d * (C[0][2]*C[1][1]*C[3][0] - C[0][1]*C[1][2]*C[3][0] - C[0][2]*C[1][0]*C[3][1] + C[0][0]*C[1][2]*C[3][1] + C[0][1]*C[1][0]*C[3][2] - C[0][0]*C[1][1]*C[3][2]);
	dst->c[3][3] = d * (C[0][1]*C[1][2]*C[2][0] - C[0][2]*C[1][1]*C[2][0] + C[0][2]*C[1][0]*C[2][1] - C[0][0]*C[1][2]*C[2][1] - C[0][1]*C[1][0]*C[2][2] + C[0][0]*C[1][1]*C[2][2]);
		
	return dst;
}

static inline struct vector3 *
matrix44_gettrans(const union matrix44 *m, struct vector3 *trans) {
	// Getting translation is trivial
	trans->x = C[3][0];
	trans->y = C[3][1];
	trans->z = C[3][2];

	return trans;
}

static inline struct vector3 *
matrix44_getscale(const union matrix44 *m, struct vector3 *scale) {
	// Scale is length of columns
	scale->x = sqrtf( C[0][0] * C[0][0] + C[0][1] * C[0][1] + C[0][2] * C[0][2] );
	scale->y = sqrtf( C[1][0] * C[1][0] + C[1][1] * C[1][1] + C[1][2] * C[1][2] );
	scale->z = sqrtf( C[2][0] * C[2][0] + C[2][1] * C[2][1] + C[2][2] * C[2][2] );

	return scale;
}

extern void
matrix44_decompose(const union matrix44 *m, struct vector3 *trans, struct vector3 *rot, struct vector3 *scale );

static inline float *
matrix44_to33(const union matrix44 *m, float m33[9]) {
	m33[0] = C[0][0]; m33[1] = C[0][1]; m33[2] = C[0][2];
	m33[3] = C[1][0]; m33[4] = C[1][1]; m33[5] = C[1][2];
	m33[6] = C[2][0]; m33[7] = C[2][1]; m33[8] = C[2][2];

	return m33;
}

#endif //ejoy_matrix44_h