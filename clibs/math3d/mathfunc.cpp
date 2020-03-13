#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

#include <cmath>

extern "C" {
	#include "linalg.h"
	#include "math3dfunc.h"
}

#include "util.h"

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtx/quaternion.hpp>
#include <glm/ext/scalar_relational.hpp>
#include <glm/ext/vector_relational.hpp>
#include <glm/gtx/euler_angles.hpp>
#include <glm/ext/vector_common.hpp>

static const glm::vec4 XAXIS(1, 0, 0, 0);
static const glm::vec4 YAXIS(0, 1, 0, 0);
static const glm::vec4 ZAXIS(0, 0, 1, 0);
static const glm::vec4 WAXIS(0, 0, 0, 1);

static const glm::vec4 NXAXIS = -XAXIS;
static const glm::vec4 NYAXIS = -YAXIS;
static const glm::vec4 NZAXIS = -ZAXIS;

void
math3d_make_srt(struct lastack *LS, const float *scale, const float *rot, const float *translate) {
	glm::mat4x4 srt;
	if (scale) {
		srt = glm::mat4x4(1);
		srt[0][0] = scale[0];
		srt[1][1] = scale[1];
		srt[2][2] = scale[2];
	}
	if (rot) {
		const glm::quat * q = (const glm::quat *)rot;
		if (scale) {
			srt = glm::mat4x4(*q) * srt;
		} else {
			srt = glm::mat4x4(*q);
		}
	} else if (scale == NULL) {
		srt = glm::mat4x4(1);
	}
	if (translate) {
		srt[3][0] = translate[0];
		srt[3][1] = translate[1];
		srt[3][2] = translate[2];
		srt[3][3] = 1;
	}
	lastack_pushmatrix(LS, &srt[0][0]);
}

void
math3d_make_quat_from_euler(struct lastack *LS, float x, float y, float z) {
	glm::vec3 r(x,y,z);
	glm::quat q(r);
	lastack_pushquat(LS, &q[0]);
}

void
math3d_make_quat_from_axis(struct lastack *LS, const float *axis, float radian) {
	glm::vec3 a(axis[0],axis[1],axis[2]);
	glm::quat q = glm::angleAxis(radian, a);
	
	lastack_pushquat(LS, &q[0]);
}

#define BINTYPE(v1, v2) (((v1) << LINEAR_TYPE_BITS_NUM) + (v2))
#define MAT(v) (*(const glm::mat4x4 *)(v))
#define VEC(v) (*(const glm::vec4 *)(v))
#define VEC3(v) (*(const glm::vec3 *)(v))
#define QUAT(v) (*(const glm::quat *)(v))

int
math3d_mul_object(struct lastack *LS, const float *val0, const float *val1, int ltype, int rtype, float tmp[16]) {
	int type = BINTYPE(ltype, rtype);

	glm::mat4x4 &mat = *(glm::mat4x4 *)tmp;
	glm::vec4 &vec = *(glm::vec4 *)tmp;

	switch (type) {
	case BINTYPE(LINEAR_TYPE_MAT,LINEAR_TYPE_MAT):
		mat = MAT(val0) * MAT(val1);
		return LINEAR_TYPE_MAT;
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_NUM):
		vec = VEC(val0) * val1[0];
		return LINEAR_TYPE_VEC4;
	case BINTYPE(LINEAR_TYPE_NUM, LINEAR_TYPE_VEC4):
		vec = val0[0] * VEC(val1);
		return LINEAR_TYPE_VEC4;
	case BINTYPE(LINEAR_TYPE_QUAT, LINEAR_TYPE_QUAT): {
		glm::quat &quat = *(glm::quat *)tmp;
		quat = QUAT(val0) * QUAT(val1);
		return LINEAR_TYPE_QUAT;
	}
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_VEC4):
		vec = VEC(val0) * VEC(val1);
		return LINEAR_TYPE_VEC4;
	}

	return LINEAR_TYPE_NONE;
}

void
math3d_add_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]){
	*(glm::vec4*)r = VEC(lhs) + VEC(rhs);
}

void
math3d_sub_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]){
	*(glm::vec4*)r = VEC(lhs) - VEC(rhs);
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

int
math3d_decompose_scale(const float mat[16], float scale[4]) {
	int ii;
	scale[3] = 0;
	for (ii = 0; ii < 3; ++ii) {
		const float * v = (const float *)&MAT(mat)[ii];
		float dot = glm::dot(VEC3(v),VEC3(v));
		if (equal_one(dot)) {
			scale[ii] = 1.0f;
		} else {
			scale[ii] = sqrtf(dot);
			if (scale[ii] == 0) {
				// invalid scale, use 1 instead
				scale[0] = scale[1] = scale[2] = 1.0f;
				return 1;
			}
		}
	}
	if (scale[0] == 1.0f && scale[1] == 1.0f && scale[2] == 1.0f) {
		return 1;
	}
	return 0;
}

void
math3d_decompose_rot(const float mat[16], float quat[4]) {
	glm::quat &q = *(glm::quat *)quat;
	glm::mat3x3 rotMat(MAT(mat));
	float scale[4];
	if (math3d_decompose_scale(mat, scale) == 0) {
		int ii;
		for (ii = 0; ii < 3; ++ii) {
			rotMat[ii] /= scale[ii];
		}
	}
	q = glm::quat_cast(rotMat);
}

void
math3d_decompose_matrix(struct lastack *LS, const float *mat) {
	const glm::mat4x4 &m = *(const glm::mat4x4 *)mat;
	float trans[4] = { m[3][0] , m[3][1], m[3][2], 1 };
	float scale[4];
	glm::mat3x3 rotMat(m);
	if (!math3d_decompose_scale(mat, scale)) {
		int ii;
		for (ii = 0; ii < 3; ++ii) {
			rotMat[ii] /= scale[ii];
		}
	}
	glm::quat q = glm::quat_cast(rotMat);
	lastack_pushvec4(LS, trans);
	lastack_pushquat(LS, &q.x);
	lastack_pushvec4(LS, scale);
}

float
math3d_length(const float *v) {
	return glm::length(VEC3(v));
}

void
math3d_floor(struct lastack *LS, const float v[4]) {
	glm::vec4 vv(glm::floor(VEC3(v)), 0.f);
	lastack_pushvec4(LS, &vv.x);
}

void
math3d_ceil(struct lastack *LS, const float v[4]) {
	glm::vec4 vv(glm::ceil(VEC3(v)), 0.f);
	lastack_pushvec4(LS, &vv.x);
}

float
math3d_dot(const float v1[4], const float v2[4]) {
	return glm::dot(VEC3(v1), VEC3(v2));
}

void
math3d_cross(struct lastack *LS, const float v1[4], const float v2[4]) {
	glm::vec4 r(glm::cross(VEC3(v1), VEC3(v2)), 0);
	lastack_pushvec4(LS, &r.x);
}

void
math3d_mulH(struct lastack *LS, const float mat[16], const float vec[4]) {
	glm::vec4 r;

	if (vec[3] != 1.f){
		float tmp[4] = { vec[0], vec[1], vec[2], 1 };
		r = MAT(mat) * VEC(tmp);
	} else {
		r = MAT(mat) * VEC(vec);
	}

	if (r.w != 0) {
		r /= fabs(r.w);
		r.w = 1.f;
	}

	lastack_pushvec4(LS, &r.x);
}

void
math3d_normalize_vector(struct lastack *LS, const float v[4]) {
	glm::vec4 r(glm::normalize(VEC3(v)), v[3]);
	lastack_pushvec4(LS, &r.x);
}

void
math3d_normalize_quat(struct lastack *LS, const float v[4]) {
	glm::quat q = glm::normalize(QUAT(v));
	lastack_pushquat(LS, &q.x);
}

void
math3d_transpose_matrix(struct lastack *LS, const float mat[16]) {
	glm::mat4x4 r = glm::transpose(MAT(mat));
	lastack_pushmatrix(LS, &r[0][0]);
}

void
math3d_inverse_matrix(struct lastack *LS, const float mat[16]) {
	glm::mat4x4 r = glm::inverse(MAT(mat));		
	lastack_pushmatrix(LS, &r[0][0]);
}

void
math3d_inverse_quat(struct lastack *LS, const float quat[4]) {
	glm::quat q = glm::inverse(QUAT(quat));
	lastack_pushquat(LS, &q.x);
}

void
math3d_lookat_matrix(struct lastack *LS, int direction, const float eye[3], const float at[3], const float *up) {
	glm::mat4x4 m;
	if (up == NULL) {
		static const float default_up[3] = {0,1,0};
		up = default_up;
	}
	if (direction) {
		const glm::vec3 vat = VEC3(eye) + VEC3(at);
		m = glm::lookAtLH(VEC3(eye), vat, VEC3(up));
	} else {
		m = glm::lookAtLH(VEC3(eye), VEC3(at), VEC3(up));
	}
	lastack_pushmatrix(LS, &m[0][0]);
}

void
math3d_quat_to_matrix(struct lastack *LS, const float quat[4]) {
	glm::mat4x4 m = glm::mat4x4(QUAT(quat));
	lastack_pushmatrix(LS, &m[0][0]);
}

void
math3d_matrix_to_quat(struct lastack *LS, const float mat[16]) {
	glm::quat q = glm::quat_cast(MAT(mat));
	lastack_pushquat(LS, &q.x);
}

void
math3d_reciprocal(struct lastack *LS, const float v[4]) {
	glm::vec4 vv = VEC(v);
	vv = 1.f / vv;
	vv[3] = v[3];
	lastack_pushvec4(LS, &vv.x);
}

void
math3d_quat_to_viewdir(struct lastack *LS, const float q[4]) {
	glm::vec4 d = glm::rotate(QUAT(q), glm::vec4(0, 0, 1, 0));
	lastack_pushvec4(LS, &d.x);
}

void
math3d_rotmat_to_viewdir(struct lastack *LS, const float m[16]) {
	glm::vec4 d = MAT(m) * glm::vec4(0, 0, 1, 0);
	lastack_pushvec4(LS, &d.x);
}

void
math3d_viewdir_to_quat(struct lastack *LS, const float v[3]) {
	glm::quat q(glm::vec3(0, 0, 1), VEC3(v));
	lastack_pushquat(LS, &q.x);
}

void
math3d_frustumLH(struct lastack *LS, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth) {
	glm::mat4x4 mat = homogeneous_depth ?
		glm::frustumLH_NO(left, right, bottom, top, near, far) :
		glm::frustumLH_ZO(left, right, bottom, top, near, far);
	lastack_pushmatrix(LS, &mat[0][0]);
}

void
math3d_orthoLH(struct lastack *LS, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth) {
	glm::mat4x4 mat = homogeneous_depth ?
		glm::orthoLH_NO(left, right, bottom, top, near, far) :
		glm::orthoLH_ZO(left, right, bottom, top, near, far);
	lastack_pushmatrix(LS, &mat[0][0]);
}

void
math3d_base_axes(struct lastack *LS, const float forward[4]) {
	glm::vec4 right, up;

	if (is_equal(VEC(forward), ZAXIS)) {
		up = YAXIS;
		right = XAXIS;
	} else {
		if (is_equal(VEC(forward), YAXIS)) {
			up = NZAXIS;
			right = XAXIS;
		} else if (is_equal(VEC(forward), NYAXIS)) {
			up = ZAXIS;
			right = XAXIS;
		} else {
			right = glm::vec4(glm::normalize(glm::cross(VEC3(&YAXIS.x), VEC3(forward))), 0);
			up = glm::vec4(glm::normalize(glm::cross(VEC3(forward), VEC3(&right.x))), 0);
		}
	}

	lastack_pushvec4(LS, &up.x);
	lastack_pushvec4(LS, &right.x);
}

void
math3d_quat_transform(struct lastack *LS, const float quat[4], const float v[4]){
	const glm::vec4 vv = glm::rotate(QUAT(quat), VEC(v));
	lastack_pushvec4(LS, &vv.x);
}

void
math3d_rotmat_transform(struct lastack *LS, const float mat[16], const float v[4]){
	const glm::vec4 vv = MAT(mat) * VEC(v);
	lastack_pushvec4(LS, &vv.x);
}

void
math3d_minmax(struct lastack *LS, const float mat[16], const float v[4], float minv[4], float maxv[4]){
	const glm::vec4 vv = mat ? MAT(mat) * VEC(v) : VEC(v);
	*(glm::vec4*)maxv = glm::max(vv, VEC(maxv));
	*(glm::vec4*)minv = glm::min(vv, VEC(minv));
}

void 
math3d_lerp(struct lastack *LS, const float v0[4], const float v1[4], float ratio, float r[4]){
	*(glm::vec4*)r = glm::lerp(VEC(v0), VEC(v1), ratio);
}
