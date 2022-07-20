#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

#include <cmath>
#include <cassert>
#include <cstring>

extern "C" {
	#include "mathid.h"
	#include "math3dfunc.h"
}

#ifndef M_PI
#define M_PI 3.1415926536
#endif

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtx/quaternion.hpp>
#include <glm/ext/scalar_relational.hpp>
#include <glm/ext/vector_relational.hpp>
#include <glm/gtx/euler_angles.hpp>
#include <glm/ext/vector_common.hpp>
#include <glm/gtx/matrix_decompose.hpp>

static const glm::vec4 XAXIS(1, 0, 0, 0);
static const glm::vec4 YAXIS(0, 1, 0, 0);
static const glm::vec4 ZAXIS(0, 0, 1, 0);
static const glm::vec4 WAXIS(0, 0, 0, 1);

static const glm::vec4 NXAXIS = -XAXIS;
static const glm::vec4 NYAXIS = -YAXIS;
static const glm::vec4 NZAXIS = -ZAXIS;

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

static inline glm::mat4x4 &
allocmat(struct math_context *M, math_t *id) {
	*id = math_matrix(M, NULL);
	float * buf = math_init(M, *id);
	return *(glm::mat4x4 *)buf;
}

static inline glm::mat4x4 &
initmat(struct math_context *M, math_t id) {
	float * buf = math_init(M, id);
	return *(glm::mat4x4 *)buf;
}

static inline glm::quat &
allocquat(struct math_context *M, math_t *id) {
	*id = math_quat(M, NULL);
	float *buf = math_init(M, *id);
	return *(glm::quat *)buf;
}

static inline glm::vec4 &
allocvec4(struct math_context *M, math_t *id) {
	*id = math_vec4(M, NULL);
	float * buf = math_init(M, *id);
	return *(glm::vec4 *)buf;
}

static inline glm::vec4 &
initvec4(struct math_context *M, math_t id) {
	float * buf = math_init(M, id);
	return *(glm::vec4 *)buf;
}

static inline const glm::quat &
QUAT(struct math_context *M, math_t quat) {
	const float * v = math_value(M, quat);
	return *(const glm::quat *)(v);
}

static inline const glm::mat4x4 &
MAT(struct math_context *M, math_t mat) {
	const float *v = math_value(M, mat);
	return *(const glm::mat4x4 *)(v);
}

static inline const glm::vec4 &
VEC(struct math_context *M, math_t v4) {
	const float *v = math_value(M, v4);
	return *(const glm::vec4 *)(v);
}

static inline const glm::vec3 &
VEC3(struct math_context *M, math_t v3) {
	const float *v = math_value(M, v3);
	return *(const glm::vec3 *)(v);
}

math_t
math3d_quat_to_matrix(struct math_context *M, math_t quat) {
	math_t r;
	glm::mat4x4 &m = allocmat(M, &r);
	m = glm::mat4x4(QUAT(M, quat));
	return r;
}

math_t
math3d_matrix_to_quat(struct math_context *M, math_t mat) {
	math_t r;
	glm::quat &q = allocquat(M, &r);
	q = glm::quat_cast(MAT(M, mat));
	return r;
}

math_t
math3d_make_quat_from_axis(struct math_context *M, math_t axis_id, float radian) {
	math_t r;
	const float *axis = math_value(M, axis_id);
	glm::vec3 a(axis[0],axis[1],axis[2]);
	glm::quat &q = allocquat(M, &r);

	q = glm::angleAxis(radian, a);

	return r;
}

math_t
math3d_quat_between_2vectors(struct math_context *M, math_t a, math_t b) {
	math_t r;
	glm::quat &q = allocquat(M, &r);
	q = glm::quat(VEC3(M, a), VEC3(M, b));
	return r;
}

math_t
math3d_make_quat_from_euler(struct math_context *M, math_t euler) {
	glm::quat q(VEC3(M, euler));
	return math_quat(M, &q[0]);
}

math_t
math3d_make_srt(struct math_context *M, math_t s, math_t r, math_t t) {
	math_t id;
	glm::mat4x4 &srt = allocmat(M, &id);
	if (!math_isnull(s)) {
		srt = glm::mat4x4(1);
		const glm::vec3 &scale = VEC3(M, s);
		srt[0][0] = scale[0];
		srt[1][1] = scale[1];
		srt[2][2] = scale[2];
	}
	if (!math_isnull(r)) {
		const glm::quat &q = QUAT(M, r);
		if (!math_isnull(s)) {
			srt = glm::mat4x4(q) * srt;
		} else {
			srt = glm::mat4x4(q);
		}
	} else if (math_isnull(s)) {
		srt = glm::mat4x4(1);
	}
	if (!math_isnull(t)) {
		const glm::vec3 &translate = VEC3(M, t);
		srt[3][0] = translate[0];
		srt[3][1] = translate[1];
		srt[3][2] = translate[2];
		srt[3][3] = 1;
	}

	return id;
}

void
math3d_decompose_matrix(struct math_context *M, math_t mat, math_t v[3]) {
	const glm::mat4x4 &m = MAT(M, mat);
	v[0] = math_vec4(M, NULL);
	v[1] = math_quat(M, NULL);
	v[2] = math_vec4(M, NULL);

	float *scale = math_init(M, v[0]);
	float *quat = math_init(M, v[1]);
	float *trans = math_init(M, v[2]);

	glm::vec3 skew;
	glm::vec4 perspective;
	glm::decompose(m, *(glm::vec3*)scale, *(glm::quat *)quat, *(glm::vec3*)trans, skew, perspective);
}

// epsilon for pow2
//#define EPSILON 0.00001f
// glm::equal(dot , 1.0f, EPSILON)

static inline int
equal_one(float f) {
	union {
		float f;
		uint32_t n;
	} u;
	u.f = f;
	return ((u.n + 0x1f) & ~0x3f) == 0x3f800000;	// float 1
}

math_t
math3d_decompose_scale(struct math_context *M, math_t mat) {
	math_t id = math_vec4(M, NULL);
	float * scale = math_init(M, id);
	const glm::mat4& m = MAT(M, mat);
	int ii;
	scale[3] = 0;
	for (ii = 0; ii < 3; ++ii) {
		const float* v = &m[ii].x;
		float dot = glm::dot(*(const glm::vec3 *)v, *(const glm::vec3 *)v);
		if (equal_one(dot)) {
			scale[ii] = 1.0f;
		} else {
			scale[ii] = sqrtf(dot);
			if (scale[ii] == 0) {
				// invalid scale, use 1 instead
				scale[0] = scale[1] = scale[2] = 1.0f;
				return id;
			}
		}
		if (glm::determinant(m) < 0){
			scale[ii] *= -1;
		}
	}
	return id;
}

math_t
math3d_decompose_rot(struct math_context *M, math_t mat) {
	math_t id;
	glm::quat &q = allocquat(M, &id);
	glm::mat4 rotMat(MAT(M, mat));
	math_t s = math3d_decompose_scale(M, mat);
	const float *scale = math_value(M, s);
	int ii;
	for (ii = 0; ii < 3; ++ii) {
		rotMat[ii] /= scale[ii];
	}
	q = glm::quat_cast(rotMat);
	return id;
}

math_t
math3d_add_vec(struct math_context *M, math_t v1, math_t v2) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	r = VEC(M, v1) + VEC(M, v2);
	return id;
}

math_t
math3d_sub_vec(struct math_context *M, math_t v1, math_t v2) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	r = VEC(M, v1) - VEC(M, v2);
	return id;
}

math_t
math3d_mul_vec(struct math_context *M, math_t v1, math_t v2) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	r = VEC(M, v1) * VEC(M, v2);
	return id;
}

math_t
math3d_mul_quat(struct math_context *M, math_t v1, math_t v2) {
	if (math_isidentity(v1)) {
		return v2;
	}
	if (math_isidentity(v2)) {
		return v1;
	}
	math_t id;
	glm::quat &quat = allocquat(M, &id);
	quat = QUAT(M, v1) * QUAT(M, v2);
	return id;
}

math_t
math3d_mul_matrix(struct math_context *M, math_t v1, math_t v2) {
	if (math_isidentity(v1)) {
		return v2;
	}
	if (math_isidentity(v2)) {
		return v1;
	}
	math_t id;
	glm::mat4x4 &mat = allocmat(M, &id);
	mat = MAT(M, v1) * MAT(M, v2);
	return id;
}

math_t
math3d_mul_matrix_array(struct math_context *M, math_t mat, math_t array_mat, math_t output_ref) {
	if (math_isidentity(mat)) {
		// mul identity, copy array
		if (math_isnull(output_ref)) {
			return array_mat;
		} else {
			float * result = math_init(M, output_ref);
			const float * source = math_value(M, array_mat);
			int sz = math_size(M, array_mat);
			int sz_output = math_size(M, output_ref);
			if (sz_output < sz)
				sz = sz_output;
			memcpy(result, source, sz * 16 * sizeof(float));
			return output_ref;
		}
	}

	int sz = math_size(M, array_mat);
	if (math_isnull(output_ref)) {
		output_ref = math_import(M, NULL, MATH_TYPE_MAT, sz);
	} else {
		int output_sz = math_size(M, output_ref);
		if (output_sz < sz)
			sz = output_sz;
	}
	int i;
	const glm::mat4x4 &m = MAT(M, mat);
	for (i=0;i<sz;i++) {
		glm::mat4x4 &mat = initmat(M, math_index(M, output_ref, i));
		mat = m * MAT(M, math_index(M, array_mat, i));
	}
	return output_ref;
}

float
math3d_length(struct math_context *M, math_t v) {
	return glm::length(VEC3(M, v));
}

math_t
math3d_floor(struct math_context *M, math_t v) {
	math_t id = math_vec4(M, NULL);
	float *vv = math_init(M, id);
	const float *value = math_value(M, v);
	vv[0] = floor(value[0]);
	vv[1] = floor(value[1]);
	vv[2] = floor(value[2]);
	vv[3] = 0;
	return id;
}

math_t
math3d_ceil(struct math_context *M, math_t v) {
	math_t id = math_vec4(M, NULL);
	float *vv = math_init(M, id);
	const float *value = math_value(M, v);
	vv[0] = ceil(value[0]);
	vv[1] = ceil(value[1]);
	vv[2] = ceil(value[2]);
	vv[3] = 0;
	return id;
}

float
math3d_dot(struct math_context *M, math_t v1, math_t v2) {
	return glm::dot(VEC3(M, v1), VEC3(M, v2));
}

math_t
math3d_cross(struct math_context *M, math_t v1, math_t v2) {
	glm::vec3 c = glm::cross(VEC3(M, v1), VEC3(M, v2));
	math_t id = math_vec4(M, NULL);
	float *r = math_init(M, id);
	r[0] = c[0];
	r[1] = c[1];
	r[2] = c[2];
	r[3] = 0;

	return id;
}

math_t
math3d_normalize_vector(struct math_context *M, math_t id) {
	const float *v = math_value(M, id);
	glm::vec3 v3 = glm::normalize(*(const glm::vec3 *)(v));
	math_t result = math_vec4(M, NULL);
	float *r = math_init(M, result);
	r[0] = v3[0];
	r[1] = v3[1];
	r[2] = v3[2];
	r[3] = v[3];
	return result;
}

math_t
math3d_normalize_quat(struct math_context *M, math_t quat) {
	math_t id;
	glm::quat &q = allocquat(M, &id);
	q = glm::normalize(QUAT(M, quat));
	return id;
}

math_t
math3d_transpose_matrix(struct math_context *M, math_t mat) {
	math_t id;
	glm::mat4x4 &r = allocmat(M, &id);
	r = glm::transpose(MAT(M, mat));
	return id;
}

math_t
math3d_inverse_quat(struct math_context *M, math_t quat) {
	math_t id;
	glm::quat &q = allocquat(M, &id);
	q = glm::inverse(QUAT(M, quat));
	return id;
}

math_t
math3d_inverse_matrix(struct math_context *M, math_t mat) {
	math_t id;
	glm::mat4x4 &r = allocmat(M, &id);
	r = glm::inverse(MAT(M, mat));
	return id;
}

math_t
math3d_inverse_matrix_fast(struct math_context *M, math_t mat) {
	math_t id;
	glm::mat4x4 &r = allocmat(M, &id);
	auto &m = MAT(M, mat);
	glm::mat3x3 m3(m);

	auto d01 = glm::dot(m3[0], m3[1]);
	auto d12 = glm::dot(m3[1], m3[2]);
	auto d20 = glm::dot(m3[2], m3[0]);
	//assert(is_zero() && is_zero(glm::dot(m3[1], m3[2])) && is_zero(glm::dot(m3[2], m3[0])));
	assert(is_zero(d01, 10e-6f) && is_zero(d12, 10e-6f) && is_zero(d20, 10e-6f));
	glm::transpose(m3);
	r = glm::mat4(m3) * glm::translate(glm::mat4(1.f), glm::vec3(-m[3]));
	return id;
}

math_t
math3d_quat_transform(struct math_context *M, math_t quat, math_t v) {
	math_t id;
	glm::vec4 &vv = allocvec4(M, &id);
	vv = glm::rotate(QUAT(M, quat), VEC(M, v));
	return id;
}

math_t
math3d_rotmat_transform(struct math_context *M, math_t mat, math_t v) {
	math_t id;
	glm::vec4 &vv = allocvec4(M, &id);
	vv = MAT(M, mat) * VEC(M, v);
	return id;
}

math_t
math3d_mulH(struct math_context *M, math_t mat, math_t v) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	const float *vec = math_value(M, v);

	if (vec[3] != 1.f){
		glm::vec4 tmp ( vec[0], vec[1], vec[2], 1 );
		r = MAT(M, mat) * tmp;
	} else {
		r = MAT(M, mat) * (*(const glm::vec4 *)(vec));
	}

	if (r.w != 0) {
		r /= fabs(r.w);
		r.w = 1.f;
	}
	return id;
}

math_t
math3d_reciprocal(struct math_context *M, math_t v) {
	math_t id;
	glm::vec4 &vv = allocvec4(M, &id);
	const float *value = math_value(M, v);
	const glm::vec4 & vec = *(const glm::vec4 *)(value);

	vv = 1.f / vec;
	vv[3] = value[3];

	return id;
}

#include <cstdio>

math_t
math3d_lookat_matrix(struct math_context *M, int direction, math_t eye, math_t at, math_t up_id) {
	math_t id;
	glm::mat4x4 &m = allocmat(M, &id);
	const float *up;
	if (math_isnull(up_id)) {
		static const float default_up[3] = {0,1,0};
		up = default_up;
	} else {
		up = math_value(M, up_id);
	}
	const glm::vec3 &eyev = VEC3(M, eye);
	if (direction) {
		const glm::vec3 vat = eyev + VEC3(M, at);
		m = glm::lookAtLH(eyev, vat, *(const glm::vec3 *)(up));
	} else {
		m = glm::lookAtLH(eyev, VEC3(M, at), *(const glm::vec3 *)(up));
	}
	return id;
}

math_t
math3d_perspectiveLH(struct math_context *M, float fov, float aspect, float near, float far, int homogeneous_depth) {
	math_t id;
	glm::mat4x4 &mat = allocmat(M, &id);
	mat = homogeneous_depth ?
		glm::perspectiveLH_NO(fov, aspect, near, far) :
		glm::perspectiveLH_ZO(fov, aspect, near, far);
	return id;
}

math_t
math3d_frustumLH(struct math_context *M, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth) {
	math_t id;
	glm::mat4x4 &mat = allocmat(M, &id);
	mat = homogeneous_depth ?
		glm::frustumLH_NO(left, right, bottom, top, near, far) :
		glm::frustumLH_ZO(left, right, bottom, top, near, far);
	return id;
}

math_t
math3d_orthoLH(struct math_context *M, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth) {
	math_t id;
	glm::mat4x4 &mat = allocmat(M, &id);
	mat = homogeneous_depth ?
		glm::orthoLH_NO(left, right, bottom, top, near, far) :
		glm::orthoLH_ZO(left, right, bottom, top, near, far);
	return id;
}

math_t
math3d_base_axes(struct math_context *M, math_t forward_id) {
	math_t result = math_import(M, NULL, MATH_TYPE_VEC4, 2);

	glm::vec4 &up = initvec4(M, math_index(M, result, 0));
	glm::vec4 &right = initvec4(M, math_index(M, result, 1));

	const glm::vec4 &forward = VEC(M, forward_id);
	const glm::vec3 &forward3 = VEC3(M, forward_id);

	if (is_equal(forward, ZAXIS)) {
		up = YAXIS;
		right = XAXIS;
	} else {
		if (is_equal(forward, YAXIS)) {
			up = NZAXIS;
			right = XAXIS;
		} else if (is_equal(forward, NYAXIS)) {
			up = ZAXIS;
			right = XAXIS;
		} else {
			right = glm::vec4(glm::normalize(glm::cross(*(const glm::vec3 *)(&YAXIS.x), forward3)), 0);
			up = glm::vec4(glm::normalize(glm::cross(forward3, *(const glm::vec3 *)(&right.x))), 0);
		}
	}
	return result;
}

math_t
math3d_quat_to_viewdir(struct math_context *M, math_t quat) {
	math_t id;
	glm::vec4 &d = allocvec4(M, &id);
	d = glm::rotate(QUAT(M, quat), glm::vec4(0, 0, 1, 0));
	return id;
}

math_t
math3d_rotmat_to_viewdir(struct math_context *M, math_t mat) {
	math_t id;
	glm::vec4 &d = allocvec4(M, &id);
	d = MAT(M, mat) * glm::vec4(0, 0, 1, 0);
	return id;
}

math_t
math3d_viewdir_to_quat(struct math_context *M, math_t v) {
	float tmp[4] = {0, 0, 1, 0};
	math_t vv = math_vec4(M, tmp);
	return math3d_quat_between_2vectors(M, vv, v);
}

static math_t
minv(struct math_context *M, math_t v0, math_t v1) {
	const float * left = math_value(M, v0);
	const float * right = math_value(M, v1);
	float tmp[4];
	int left_n = 0;
	int right_n = 0;
	int i;
	for (i=0;i<3;i++) {
		if (left[i] <= right[i]) {
			if (left[i] == right[i])
				++right_n;
			++left_n;
			tmp[i] = left[i];
		} else {
			// left[i] > right[i]
			++right_n;
			tmp[i] = right[i];
		}
	}
	if (left_n == 3) {
		return v0;
	} else if (right_n == 3) {
		return v1;
	}
	tmp[3] = 0;
	return math_vec4(M, tmp);
}

static math_t
maxv(struct math_context *M, math_t v0, math_t v1) {
	const float * left = math_value(M, v0);
	const float * right = math_value(M, v1);
	float tmp[4];
	int left_n = 0;
	int right_n = 0;
	int i;
	for (i=0;i<3;i++) {
		if (left[i] >= right[i]) {
			if (left[i] == right[i])
				++right_n;
			++left_n;
			tmp[i] = left[i];
		} else {
			// left[i] < right[i]
			++right_n;
			tmp[i] = right[i];
		}
	}
	if (left_n == 3) {
		return v0;
	} else if (right_n == 3) {
		return v1;
	}
	tmp[3] = 0;
	return math_vec4(M, tmp);
}

void
math3d_minmax(struct math_context *M, math_t transform, math_t v, math_t minmax[2]) {
	if (!math_isnull(transform)) {
		const glm::vec4 &vv = VEC(M, v);
		glm::vec4 &result = allocvec4(M, &v);
		result = MAT(M, transform) * vv;
	}
	if (math_isnull(minmax[0])) {
		minmax[0] = v;
	} else {
		minmax[0] = minv(M, minmax[0], v);
	}
	if (math_isnull(minmax[1])) {
		minmax[1] = v;
	} else {
		minmax[1] = maxv(M, minmax[1], v);
	}
}

math_t
math3d_aabb_merge(struct math_context *M, math_t aabblhs, math_t aabbrhs) {
	math_t v[4] = {
		math_index(M, aabblhs, 0),
		math_index(M, aabblhs, 1),
		math_index(M, aabbrhs, 0),
		math_index(M, aabbrhs, 1),
	};
	int i;
	math_t min_id = v[0];
	math_t max_id = v[0];
	for (i=1;i<4;i++) {
		min_id = minv(M, min_id, v[i]);
		max_id = maxv(M, min_id, v[i]);
	}
	if (math_issame(min_id, v[0]) && math_issame(max_id, v[1])) {
		return aabblhs;
	}
	if (math_issame(min_id, v[2]) && math_issame(max_id, v[3])) {
		return aabbrhs;
	}
	math_t r = math_import(M, NULL, MATH_TYPE_VEC4, 2);
	float *value = math_init(M, r);
	memcpy(value, math_value(M, min_id), 4 * sizeof(float));
	memcpy(value+4, math_value(M, max_id), 4 * sizeof(float));
	return r;
}

math_t
math3d_lerp(struct math_context *M, math_t v0, math_t v1, float ratio) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	r = glm::lerp(VEC(M, v0), VEC(M, v1), ratio);
	return id;
}

math_t
math3d_quat_lerp(struct math_context *M, math_t v0, math_t v1, float ratio) {
	math_t id;
	glm::quat &r = allocquat(M, &id);
	r = glm::lerp(QUAT(M, v0), QUAT(M, v1), ratio);
	return id;
}

math_t
math3d_quat_slerp(struct math_context *M, math_t v0, math_t v1, float ratio) {
	math_t id;
	glm::quat &r = allocquat(M, &id);
	r = glm::slerp(QUAT(M, v0), QUAT(M, v1), ratio);
	return id;
}

// x: pitch(-90, 90), y: yaw(-180, 180), z: roll(-180, 180),
static glm::vec3
limit_euler_angles(const glm::quat& q) {
	static const float MY_PI = 3.14159265358979323846264338327950288f;
	float x_ = q.x;
	float y_ = q.y;
	float z_ = q.z;
	float w_ = q.w;
	// Derivation from http://www.geometrictools.com/Documentation/EulerAngles.pdf
	// Order of rotations: Z first, then X, then Y
	float check = 2.0f * (-y_ * z_ + w_ * x_);
	if (check < -0.995f) {
		return {
			-0.5f * MY_PI,
			0.0f,
			-atan2f(2.0f * (x_ * z_ - w_ * y_), 1.0f - 2.0f * (y_ * y_ + z_ * z_))
		};
	} else if (check > 0.995f) {
		return {
			0.5f * MY_PI,
			0.0f,
			atan2f(2.0f * (x_ * z_ - w_ * y_), 1.0f - 2.0f * (y_ * y_ + z_ * z_))
		};
	} else {
		return {
			asinf(check),
			atan2f(2.0f * (x_ * z_ + w_ * y_), 1.0f - 2.0f * (x_ * x_ + y_ * y_)),
			atan2f(2.0f * (x_ * y_ + w_ * z_), 1.0f - 2.0f * (x_ * x_ + z_ * z_))
		};
	}
}

math_t
math3d_quat_to_euler(struct math_context *M, math_t q) {
	math_t id;
	glm::vec4 &r = allocvec4(M, &id);
	r[3] = 0;
	glm::vec3 &eular = *(glm::vec3 *)(&r);
	eular = limit_euler_angles(QUAT(M, q)); // glm::eulerAngles(QUAT(q)); // 
	return id;
}

void
math3d_dir2radian(struct math_context *M, math_t rad, float radians[2]) {
	const float *v = math_value(M, rad);
	const float PI = float(M_PI);
	const float HALF_PI = 0.5f * PI;
	
	if (is_equal(v[1], 1.f)){
		radians[0] = -HALF_PI;
		radians[1] = 0.f;
	} else if (is_equal(v[1], -1.f)) {
		radians[0] = HALF_PI;
		radians[1] = 0.f;
	} else if (is_equal(v[0], 1.f)) {
		radians[0] = 0.f;
		radians[1] = HALF_PI;
	} else if (is_equal(v[0], -1.f)) {
		radians[0] = 0.f;
		radians[1] = -HALF_PI;
	} else if (is_equal(v[2], 1.f)) {
		radians[0] = 0.f;
		radians[1] = 0.f;
	} else if (is_equal(v[2], -1.f)) {
		radians[0] = 0.f;
		radians[1] = PI;
	} else {
		radians[0] = is_zero(v[1]) ? 0.f : std::asin(-v[1]);
		radians[1] = is_zero(v[0]) ? 0.f : std::atan2(v[0], v[2]);
	}
}

math_t
math3d_frustum_center(struct math_context *M, math_t points) {
	math_t id;
	glm::vec4 &c = allocvec4(M, &id);
	c = glm::vec4(0, 0, 0, 1);
	int ii;
	for (ii = 0; ii < 8; ++ii) {
		c += VEC(M, math_index(M, points, ii));
	}

	c /= 8.f;
	c.w = 1.f;

	return id;
}

float
math3d_frustum_max_radius(struct math_context *M, math_t points, math_t center) {
	float maxradius = 0;
	const glm::vec4 &c = VEC(M, center);
	int ii;
	for (ii = 0; ii < 8; ++ii) {
		const glm::vec4 &p = VEC(M, math_index(M, points, ii));
		maxradius = glm::max(glm::length(p - c), maxradius);
	}

	return maxradius;
}

math_t
math3d_frusutm_aabb(struct math_context *M, math_t points) {
	math_t aabb = math_import(M, NULL, MATH_TYPE_VEC4, 2);

	glm::vec4 & minv = initvec4(M, math_index(M, aabb, 0));
	glm::vec4 & maxv = initvec4(M, math_index(M, aabb, 1));
	
	minv = glm::vec4(std::numeric_limits<float>::max()), 
	maxv = glm::vec4(std::numeric_limits<float>::lowest());

	int ii = 0;
	for (ii = 0; ii < 8; ++ii){
		const auto &p = VEC(M, math_index(M, points, ii));
		minv = glm::min(minv, p);
		maxv = glm::max(maxv, p);
	}

	return aabb;
}

int
math3d_aabb_isvalid(struct math_context *M, math_t aabb) {
	const glm::vec3 &minv = VEC3(M, math_index(M, aabb, 0));
	const glm::vec3 &maxv = VEC3(M, math_index(M, aabb, 1));

	return (minv.x < maxv.x && minv.y < maxv.y && minv.z < maxv.z) ? 1 : 0;
}

math_t
math3d_aabb_transform(struct math_context *M, math_t trans, math_t aabb) {
	const auto& t = MAT(M, trans);

	const auto& minv = VEC(M, math_index(M, aabb, 0));
	const auto& maxv = VEC(M, math_index(M, aabb, 1));

	const glm::vec4 &right	= t[0];
	const glm::vec4 &up 	= t[1];
	const glm::vec4 &forward= t[2];
	const glm::vec4 &pos 	= t[3];

	const glm::vec4 xa = right * minv.x;
	const glm::vec4 xb = right * maxv.x;

	const glm::vec4 ya = up * minv.y;
	const glm::vec4 yb = up * maxv.y;

	const glm::vec4 za = forward * minv.z;
	const glm::vec4 zb = forward * maxv.z;

	math_t r = math_import(M, NULL, MATH_TYPE_VEC4, 2);

	auto &rmin = initvec4(M, math_index(M, r, 0));
	auto &rmax = initvec4(M, math_index(M, r, 1));

	rmin = glm::min(xa, xb) + glm::min(ya, yb) + glm::min(za, zb) + pos;
	rmax = glm::max(xa, xb) + glm::max(ya, yb) + glm::max(za, zb) + pos;

	return r;
}

math_t
math3d_aabb_center_extents(struct math_context *M, math_t aabb) {
	math_t result = math_import(M, NULL, MATH_TYPE_VEC4, 2);

	const glm::vec4 &minv = VEC(M, math_index(M, aabb, 0));
	const glm::vec4 &maxv = VEC(M, math_index(M, aabb, 1));

	glm::vec4 &center = initvec4(M, math_index(M, result, 0));
	glm::vec4 &extents = initvec4(M, math_index(M, result, 1));

	center = (maxv+minv)*0.5f;
	extents = (maxv-minv)*0.5f;

	return result;
}

static int
plane_intersect(const glm::vec4& plane, const glm::vec3 &min, const glm::vec3 &max) {
	float minD, maxD;
	if (plane.x > 0.0f) {
		minD = plane.x * min.x;
		maxD = plane.x * max.x;
	}
	else {
		minD = plane.x * max.x;
		maxD = plane.x * min.x;
	}

	if (plane.y > 0.0f) {
		minD += plane.y * min.y;
		maxD += plane.y * max.y;
	}
	else {
		minD += plane.y * max.y;
		maxD += plane.y * min.y;
	}

	if (plane.z > 0.0f) {
		minD += plane.z * min.z;
		maxD += plane.z * max.z;
	}
	else {
		minD += plane.z * max.z;
		maxD += plane.z * min.z;
	}

	// in front of the plane
	if (minD > -plane.w) {
		return 1;
	}

	// in back of the plane
	if (maxD < -plane.w) {
		return -1;
	}

	// straddle of the plane
	return 0;
}

int
math3d_aabb_intersect_plane(struct math_context *M, math_t aabb, math_t plane) {
	return plane_intersect(
		VEC(M, plane),
		VEC3(M, math_index(M, aabb, 0)),
		VEC3(M, math_index(M, aabb, 1))
	);
}

math_t
math3d_aabb_intersection(struct math_context *M, math_t aabb1, math_t aabb2) {
	math_t aabb[2] = {
		maxv(M, math_index(M, aabb1, 0),  math_index(M, aabb2, 0)),
		minv(M, math_index(M, aabb1, 1),  math_index(M, aabb2, 1)),
	};
	const float * v[2] = {
		math_value(M, aabb[0]),
		math_value(M, aabb[1]),
	};
	if (v[0] + 4 == v[1]) {
		// It's already a vector array
		if (v[0] == math_value(M, aabb1))
			return aabb1;
		if (v[0] == math_value(M, aabb2))
			return aabb2;
	}
	math_t r = math_import(M, NULL, MATH_TYPE_VEC4, 2);
	float * vv = math_init(M, r);
	memcpy(vv, v[0], 4 * sizeof(float));
	memcpy(vv+4, v[1], 4 * sizeof(float));
	return r;
}

int
math3d_aabb_test_point(struct math_context *M, math_t aabb, math_t v) {
	const float * aabb_value = math_value(M, aabb);
	const float * p = math_value(M, v);
	const float * minv = &aabb_value[0];
	const float * maxv = &aabb_value[4];

	int ii;
	for (ii=0;ii<3;++ii){
		if (minv[ii] > p[ii] || maxv[ii] < p[ii])
			return 0;
	}

	return 1;
}

void
math3d_aabb_points(struct math_context *M, math_t aabb, math_t points[8]) {
	const auto &minv = VEC(M, math_index(M, aabb, 0));
	const auto &maxv = VEC(M, math_index(M, aabb, 1));

	int i;
	for (i=0;i<8;i++) {
		points[i] = math_vec4(M, NULL);
	}

	glm::vec4 &p0 = initvec4(M, points[0]); p0 = minv;
	glm::vec4 &p1 = initvec4(M, points[1]); p1 = glm::vec4(minv.x, maxv.y, minv.z, 0);
	glm::vec4 &p2 = initvec4(M, points[2]); p2 = glm::vec4(maxv.x, minv.y, minv.z, 0);
	glm::vec4 &p3 = initvec4(M, points[3]); p3 = glm::vec4(maxv.x, maxv.y, minv.z, 0);
	                                  
	glm::vec4 &p4 = initvec4(M, points[4]); p4 = glm::vec4(minv.x, minv.y, maxv.z, 0);
	glm::vec4 &p5 = initvec4(M, points[5]); p5 = glm::vec4(minv.x, maxv.y, maxv.z, 0);
	glm::vec4 &p6 = initvec4(M, points[6]); p6 = glm::vec4(maxv.x, minv.y, maxv.z, 0);
	glm::vec4 &p7 = initvec4(M, points[7]); p7 = maxv;                                  
}

math_t
math3d_aabb_expand(struct math_context *M, math_t aabb, math_t e) {
	math_t r = math_import(M, NULL, MATH_TYPE_VEC4, 2);
	glm::vec4 &min = initvec4(M, math_index(M, r, 0));
	glm::vec4 &max = initvec4(M, math_index(M, r, 1));

	const glm::vec4 &v = VEC(M, e);

	min = VEC(M, math_index(M, aabb, 0)) - v;
	max = VEC(M, math_index(M, aabb, 1)) + v;

	return r;
}

// vplane [left, right, bottom, top, near, far]
enum PlaneName {
	PN_left = 0,
	PN_right,
	PN_bottom,
	PN_top,
	PN_near,
	PN_far,
};

math_t
math3d_frustum_planes(struct math_context *M, math_t m, int homogeneous_depth) {
	math_t result = math_import(M, NULL, MATH_TYPE_VEC4, 6);

	const auto &mat = MAT(M, m);
	const auto& c0 = mat[0], &c1 = mat[1], & c2 = mat[2], & c3 = mat[3];

	auto& leftplane = initvec4(M, math_index(M, result, PN_left));
	leftplane[0] = c0[0] + c0[3];
	leftplane[1] = c1[0] + c1[3];
	leftplane[2] = c2[0] + c2[3];
	leftplane[3] = c3[0] + c3[3];

	auto& rightplane = initvec4(M, math_index(M, result, PN_right));
	rightplane[0] = c0[3] - c0[0];
	rightplane[1] = c1[3] - c1[0];
	rightplane[2] = c2[3] - c2[0];
	rightplane[3] = c3[3] - c3[0];

	auto& bottomplane = initvec4(M, math_index(M, result, PN_bottom));
	bottomplane[0] = c0[3] + c0[1];
	bottomplane[1] = c1[3] + c1[1];
	bottomplane[2] = c2[3] + c2[1];
	bottomplane[3] = c3[3] + c3[1];

	auto& topplane = initvec4(M, math_index(M, result, PN_top));
	topplane[0] = c0[3] - c0[1];
	topplane[1] = c1[3] - c1[1];
	topplane[2] = c2[3] - c2[1];
	topplane[3] = c3[3] - c3[1];

	auto& nearplane = initvec4(M, math_index(M, result, PN_near));
	if (homogeneous_depth) {
		nearplane[0] = c0[3] + c0[2];
		nearplane[1] = c1[3] + c1[2];
		nearplane[2] = c2[3] + c2[2];
		nearplane[3] = c3[3] + c3[2];
	} else {
		nearplane[0] = c0[2];
		nearplane[1] = c1[2];
		nearplane[2] = c2[2];
		nearplane[3] = c3[2];
	}

	auto& farplane = initvec4(M, math_index(M, result, PN_far));
	farplane[0] = c0[3] - c0[2];
	farplane[1] = c1[3] - c1[2];
	farplane[2] = c2[3] - c2[2];
	farplane[3] = c3[3] - c3[2];

	// normalize
	int ii;
	for (ii = 0; ii < 6; ++ii){
		math_t v = math_index(M, result, ii);
		auto& p = initvec4(M, v);
		auto len = glm::length(VEC3(M, v));
		if (glm::abs(len) >= glm::epsilon<float>())
			p /= len;
	}

	return result;
}

int
math3d_frustum_intersect_aabb(struct math_context *M, math_t planes, math_t aabb) {
	int ii;

	const glm::vec3 &min =  VEC3(M, math_index(M, aabb, 0));
	const glm::vec3 &max =  VEC3(M, math_index(M, aabb, 1));

	for (ii = 0; ii < 6; ++ii){
		const auto &p = VEC(M, math_index(M, planes, ii));
		const int r = plane_intersect(p, min, max);
		// intersect or outside frustum
		if (r <= 0){
			return r;
		}
	}

	// aabb in front of all planes, mean inside frustum
	return 1;
}

// point: [
//	lbn, ltn, rbn, rtn, 
//	lbf, ltf, rbf, rtf, 
//]
static const glm::vec4 ndc_points_ZO[8] = {
	glm::vec4(-1.f,-1.f, 0.f, 1.f),
	glm::vec4(-1.f, 1.f, 0.f, 1.f),
	glm::vec4( 1.f,-1.f, 0.f, 1.f),
	glm::vec4( 1.f, 1.f, 0.f, 1.f),

	glm::vec4(-1.f,-1.f, 1.f, 1.f),
	glm::vec4(-1.f,1.f,  1.f, 1.f),
	glm::vec4(1.f, -1.f, 1.f, 1.f),
	glm::vec4(1.f, 1.f,  1.f, 1.f),
};

static const glm::vec4 ndc_points_NO[8] = {
	glm::vec4(-1.f,-1.f, -1.f, 1.f),
	glm::vec4(-1.f, 1.f, -1.f, 1.f),
	glm::vec4( 1.f, -1.f,-1.f, 1.f),
	glm::vec4( 1.f,  1.f,-1.f, 1.f),

	glm::vec4(-1.f,-1.f, 1.f, 1.f),
	glm::vec4(-1.f, 1.f, 1.f, 1.f),
	glm::vec4( 1.f,-1.f, 1.f, 1.f),
	glm::vec4( 1.f, 1.f, 1.f, 1.f),
};

math_t
math3d_frustum_points(struct math_context *M, math_t m, int homogeneous_depth) {
	math_t result = math_import(M, NULL, MATH_TYPE_VEC4, 8);
	auto invmat = glm::inverse(MAT(M, m));
	const auto &pp = homogeneous_depth ? ndc_points_NO : ndc_points_ZO;
	int ii;
	for (ii = 0; ii < 8; ++ii){
		auto &p = initvec4(M, math_index(M, result, ii));
		p = invmat * pp[ii];
		p /= p.w;
	}
	return result;
}

void
math3d_frustum_calc_near_far(struct math_context *M, math_t planes, float result[2]) {
	// todo
	result[0] = 0;
	result[1] = 0;
}

float
math3d_point2plane(struct math_context *M, math_t pt, math_t plane) {
	return glm::dot(VEC3(M, pt), VEC3(M, plane)) + VEC(M, plane)[3];
}
