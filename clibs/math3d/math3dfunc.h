#ifndef math3d_func_h
#define math3d_func_h

#include "linalg.h"

#define LINEAR_TYPE_NUM LINEAR_TYPE_COUNT

// math functions

void math3d_make_srt(struct lastack *LS, const float *s, const float *r, const float *t);
void math3d_make_quat_from_euler(struct lastack *LS, float x, float y, float z);
void math3d_make_quat_from_axis(struct lastack *LS, const float *axis, float radian);
int math3d_mul_object(struct lastack *LS, const float *lval, const float *rval, int ltype, int rtype, float tmp[16]);
void math3d_add_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]);
void math3d_sub_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]);
int math3d_decompose_matrix(struct lastack *LS, const float *mat);
int math3d_decompose_rot(const float mat[16], float quat[4]);
int math3d_decompose_scale(const float mat[16], float scale[4]);
void math3d_quat_to_matrix(struct lastack *LS, const float quat[4]);
void math3d_matrix_to_quat(struct lastack *LS, const float mat[16]);
float math3d_length(const float *v3);
void math3d_floor(struct lastack *LS, const float v[4]);
void math3d_ceil(struct lastack *LS, const float v[4]);
float math3d_dot(const float v1[4], const float v2[4]);
void math3d_cross(struct lastack *LS, const float v1[4], const float v2[4]);
void math3d_mulH(struct lastack *LS, const float mat[16], const float vec[4]);
void math3d_normalize_vector(struct lastack *LS, const float v[4]);
void math3d_normalize_quat(struct lastack *LS, const float v[4]);
void math3d_inverse_matrix(struct lastack *LS, const float mat[16]);
void math3d_inverse_quat(struct lastack *LS, const float quat[4]);
void math3d_transpose_matrix(struct lastack *LS, const float mat[16]);
void math3d_lookat_matrix(struct lastack *LS, int direction, const float eye[3], const float at[3], const float *up);
void math3d_reciprocal(struct lastack *LS, const float v[4]);
void math3d_quat_to_viewdir(struct lastack *LS, const float q[4]);
void math3d_rotmat_to_viewdir(struct lastack *LS, const float m[16]);
void math3d_viewdir_to_quat(struct lastack *LS, const float v[3]);
void math3d_frustumLH(struct lastack *LS, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth);
void math3d_orthoLH(struct lastack *LS, float left, float right, float bottom, float top, float near, float far, int homogeneous_depth);
void math3d_base_axes(struct lastack *LS, const float forward[4]);
void math3d_quat_transform(struct lastack *LS, const float quat[4], const float v[4]);
void math3d_rotmat_transform(struct lastack *LS, const float mat[16], const float v[4]);
#endif
