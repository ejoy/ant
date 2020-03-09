#define LUA_LIB
#define GLM_ENABLE_EXPERIMENTAL

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include "linalg.h"
	#include "math3d.h"
	#include "math.h"
}

#include "util.h"

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtx/quaternion.hpp>
#include <glm/ext/scalar_relational.hpp>
#include <glm/ext/vector_relational.hpp>
#include <glm/gtx/euler_angles.hpp>

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
#define MAT(v) (*(const glm::mat4x4 *)v)
#define VEC(v) (*(const glm::vec4 *)v)
#define VEC3(v) (*(const glm::vec3 *)v)
#define QUAT(v) (*(const glm::quat *)v)

int
math3d_mul_object(struct lastack *LS, const float *val0, const float *val1, int ltype, int rtype, float tmp[16]) {
	int type = BINTYPE(ltype, rtype);

	glm::mat4x4 &mat = *(glm::mat4x4 *)tmp;
	glm::vec4 &vec = *(glm::vec4 *)tmp;

	switch (type) {
	case BINTYPE(LINEAR_TYPE_MAT,LINEAR_TYPE_MAT):
		mat = MAT(val0) * MAT(val1);
		return LINEAR_TYPE_MAT;
	case BINTYPE(LINEAR_TYPE_MAT, LINEAR_TYPE_VEC4):
		vec = MAT(val0) * VEC(val1);
		return LINEAR_TYPE_VEC4;
	case BINTYPE(LINEAR_TYPE_VEC4, LINEAR_TYPE_MAT):
		vec = VEC(val0) *MAT(val1);			
		return LINEAR_TYPE_VEC4;
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

int
math3d_decompose_scale(const float mat[16], float scale[4]) {
	int ii;
	for (ii = 0; ii < 3; ++ii)
		scale[ii] = glm::length(MAT(mat)[ii]);
	if (scale[0] == 0 || scale[1] == 0 || scale[2] == 0) {
		return 1;
	}
	scale[3] = 0;
	return 0;
}

int
math3d_decompose_rot(const float mat[16], float quat[4]) {
	float scale[4];
	if (math3d_decompose_scale(mat, scale)) {
		return 1;
	} else {
		glm::quat &q = *(glm::quat *)quat;
		glm::mat3x3 rotMat(MAT(mat));
		int ii;
		for (ii = 0; ii < 3; ++ii) {
			rotMat[ii] /= scale[ii];
		}
		q = glm::quat_cast(rotMat);
		return 0;
	}
}

int
math3d_decompose_matrix(struct lastack *LS, const float *mat) {
	const glm::mat4x4 &m = *(const glm::mat4x4 *)mat;
	float trans[4] = { m[3][0] , m[3][1], m[3][2], 1 };
	int ii;
	float scale[4];
	if (math3d_decompose_scale(mat, scale)) {
		return 1;
	}
	
	glm::mat3x3 rotMat(m);
	for (ii = 0; ii < 3; ++ii) {
		rotMat[ii] /= scale[ii];
	}
	glm::quat q = glm::quat_cast(rotMat);
	lastack_pushvec4(LS, trans);
	lastack_pushquat(LS, &q.x);
	lastack_pushvec4(LS, scale);
	return 0;
}

float
math3d_length(const float *v) {
	return glm::length(VEC(v));
}

void
math3d_floor(struct lastack *LS, const float v[4]) {
	glm::vec4 vv = glm::floor(VEC(v));
	lastack_pushvec4(LS, &vv.x);
}

void
math3d_ceil(struct lastack *LS, const float v[4]) {
	glm::vec4 vv = glm::ceil(VEC(v));
	lastack_pushvec4(LS, &vv.x);
}

float
math3d_dot(const float v1[4], const float v2[4]) {
	return glm::dot(VEC(v1), VEC(v2));
}

void
math3d_cross(struct lastack *LS, const float v1[4], const float v2[4]) {
	glm::vec4 r(glm::cross(VEC3(v1), VEC3(v2)), 0);
	lastack_pushvec4(LS, &r.x);
}

void
math3d_mulH(struct lastack *LS, const float mat[16], const float vec[4]) {
	glm::vec4 r = MAT(mat) * VEC(vec);	
	if (!r.w != 0) {
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
math3d_lookat_matrix(struct lastack *LS, int direction, const float at[3], const float eye[3], const float *up) {
	glm::mat4x4 m;
	if (up == NULL) {
		const float default_up[3] = {0,1,0};
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
	glm::mat m = glm::mat4x4(QUAT(quat));
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
			right = glm::vec4(glm::normalize(glm::cross(VEC3(&YAXIS), VEC3(forward))), 0);
			up = glm::vec4(glm::normalize(glm::cross(VEC3(forward), VEC3(&right.x))), 0);
		}
	}

	lastack_pushvec4(LS, &up.x);
	lastack_pushvec4(LS, &right.x);
}

void
math3d_rotate_vector(struct lastack *LS, const float v[4]){
	
}