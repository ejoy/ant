#ifndef math3d_func_h
#define math3d_func_h

#include "linalg.h"

int math3d_homogeneous_depth();

// math functions

void math3d_make_srt(struct lastack *LS, const float *s, const float *r, const float *t);
void math3d_make_quat_from_euler(struct lastack *LS, float x, float y, float z);
void math3d_make_quat_from_axis(struct lastack *LS, const float *axis, float radian);
void math3d_mul_matrix(struct lastack *LS, const float lval[16], const float rval[16], float result[16]);
void math3d_mul_vec4(struct lastack *LS, const float lval[4], const float rval[4], float result[4]);
void math3d_mul_quat(struct lastack *LS, const float lval[4], const float rval[4], float result[4]);
void math3d_add_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]);
void math3d_sub_vec(struct lastack *LS, const float lhs[4], const float rhs[4], float r[4]);
void math3d_decompose_matrix(struct lastack *LS, const float *mat);
void math3d_decompose_rot(const float mat[16], float quat[4]);
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
void math3d_inverse_matrix_fast(struct lastack *LS, const float mat[16]);
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
void math3d_minmax(struct lastack *LS, const float mat[16], const float v[4], float minv[4], float maxv[4]);
void math3d_lerp(struct lastack *LS, const float v0[4], const float v1[4], float ratio, float r[4]);
void math3d_quat_to_euler(struct lastack *LS, const float q[4], float euler[4]);
void math3d_dir2radian(struct lastack *LS, const float v[4], float radians[2]);
//aabb
void math3d_aabb_append(struct lastack *LS, const float v[4], float *raabb);
void math3d_aabb_merge(struct lastack *LS, const float *aabblhs, const float *aabbrhs, float *raabb);
int math3d_aabb_isvalid(struct lastack *LS, const float *aabb);
void math3d_aabb_transform(struct lastack *LS, const float trans[16], const float aabb[16], float raabb[16]);
void math3d_aabb_center_extents(struct lastack *LS, const float *aabb, float center[4], float extents[4]);
float math3d_aabb_diagonal_length(struct lastack *LS, const float *aabb);
int math3d_aabb_intersect_plane(struct lastack *LS, const float *aabb, const float plane[4]);

//frustum
void math3d_frustum_planes(struct lastack *LS, const float m[16], float *planes[6]);
void math3d_frustum_points(struct lastack *LS, const float m[16], float *points[8]);
int math3d_frustum_intersect_aabb(struct lastack *LS, const float* planes[6], const float *aabb);
void math3d_frusutm_aabb(struct lastack *LS, const float* points[8], float *aabb);
void math3d_frustum_center(struct lastack *LS, const float *points[8], float *center);
float math3d_frustum_max_radius(struct lastack *LS, const float *points[8], const float center[4]);
void math3d_frustum_calc_near_far(struct lastack *LS, const float *planes[6], float nearfar[2]);

//primitive
float math3d_point2plane(struct lastack *LS, const float pt[4], const float plane[4]);
#endif
