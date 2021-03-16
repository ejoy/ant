

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.Matrix43.h"
#include "Effekseer.Math.h"
#include "Effekseer.Matrix44.h"
#include "Effekseer.Vector3D.h"
#include <limits>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#if (defined(_M_IX86_FP) && _M_IX86_FP >= 2) || defined(__SSE__)
#define EFK_SSE2
#include <emmintrin.h>
#elif defined(__ARM_NEON__)
#define EFK_NEON
#include <arm_neon.h>
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#if defined(_MSC_VER)
#define EFK_ALIGN_AS(n) __declspec(align(n))
#else
#define EFK_ALIGN_AS(n) alignas(n)
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::Indentity()
{
	static const Matrix43 indentity = {{{1.0f, 0.0f, 0.0f}, {0.0f, 1.0f, 0.0f}, {0.0f, 0.0f, 1.0f}, {0.0f, 0.0f, 0.0f}}};
	memcpy(Value, indentity.Value, sizeof(indentity));
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::Scaling(float x, float y, float z)
{
	memset(Value, 0, sizeof(float) * 12);
	Value[0][0] = x;
	Value[1][1] = y;
	Value[2][2] = z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationX(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Value[0][0] = 1.0f;
	Value[0][1] = 0.0f;
	Value[0][2] = 0.0f;

	Value[1][0] = 0.0f;
	Value[1][1] = c;
	Value[1][2] = s;

	Value[2][0] = 0.0f;
	Value[2][1] = -s;
	Value[2][2] = c;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationY(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Value[0][0] = c;
	Value[0][1] = 0.0f;
	Value[0][2] = -s;

	Value[1][0] = 0.0f;
	Value[1][1] = 1.0f;
	Value[1][2] = 0.0f;

	Value[2][0] = s;
	Value[2][1] = 0.0f;
	Value[2][2] = c;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationZ(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Value[0][0] = c;
	Value[0][1] = s;
	Value[0][2] = 0.0f;

	Value[1][0] = -s;
	Value[1][1] = c;
	Value[1][2] = 0.0f;

	Value[2][0] = 0.0f;
	Value[2][1] = 0.0f;
	Value[2][2] = 1;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationXYZ(float rx, float ry, float rz)
{
	float cx, sx, cy, sy, cz, sz;

	if (rx != 0.0f)
	{
		::Effekseer::SinCos(rx, sx, cx);
	}
	else
	{
		sx = 0.0f;
		cx = 1.0f;
	}
	if (ry != 0.0f)
	{
		::Effekseer::SinCos(ry, sy, cy);
	}
	else
	{
		sy = 0.0f;
		cy = 1.0f;
	}
	if (rz != 0.0f)
	{
		::Effekseer::SinCos(rz, sz, cz);
	}
	else
	{
		sz = 0.0f;
		cz = 1.0f;
	}

	Value[0][0] = cy * cz;
	Value[0][1] = cy * sz;
	Value[0][2] = -sy;

	Value[1][0] = sx * sy * -sz + cx * -sz;
	Value[1][1] = sx * sy * sz + cx * cz;
	Value[1][2] = sx * cy;

	Value[2][0] = cx * sy * cz + sx * sz;
	Value[2][1] = cx * sy * sz - sx * cz;
	Value[2][2] = cx * cy;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationZXY(float rz, float rx, float ry)
{
	float cx, sx, cy, sy, cz, sz;

	if (rx != 0.0f)
	{
		::Effekseer::SinCos(rx, sx, cx);
	}
	else
	{
		sx = 0.0f;
		cx = 1.0f;
	}
	if (ry != 0.0f)
	{
		::Effekseer::SinCos(ry, sy, cy);
	}
	else
	{
		sy = 0.0f;
		cy = 1.0f;
	}
	if (rz != 0.0f)
	{
		::Effekseer::SinCos(rz, sz, cz);
	}
	else
	{
		sz = 0.0f;
		cz = 1.0f;
	}

	Value[0][0] = cz * cy + sz * sx * sy;
	Value[0][1] = sz * cx;
	Value[0][2] = cz * -sy + sz * sx * cy;

	Value[1][0] = -sz * cy + cz * sx * sy;
	Value[1][1] = cz * cx;
	Value[1][2] = -sz * -sy + cz * sx * cy;

	Value[2][0] = cx * sy;
	Value[2][1] = -sx;
	Value[2][2] = cx * cy;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationAxis(const Vector3D& axis, float angle)
{
	const float c = cosf(angle);
	const float s = sinf(angle);
	const float cc = 1.0f - c;

	Value[0][0] = cc * (axis.X * axis.X) + c;
	Value[0][1] = cc * (axis.X * axis.Y) + (axis.Z * s);
	Value[0][2] = cc * (axis.Z * axis.X) - (axis.Y * s);

	Value[1][0] = cc * (axis.X * axis.Y) - (axis.Z * s);
	Value[1][1] = cc * (axis.Y * axis.Y) + c;
	Value[1][2] = cc * (axis.Y * axis.Z) + (axis.X * s);

	Value[2][0] = cc * (axis.Z * axis.X) + (axis.Y * s);
	Value[2][1] = cc * (axis.Y * axis.Z) - (axis.X * s);
	Value[2][2] = cc * (axis.Z * axis.Z) + c;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::RotationAxis(const Vector3D& axis, float s, float c)
{
	const float cc = 1.0f - c;

	Value[0][0] = cc * (axis.X * axis.X) + c;
	Value[0][1] = cc * (axis.X * axis.Y) + (axis.Z * s);
	Value[0][2] = cc * (axis.Z * axis.X) - (axis.Y * s);

	Value[1][0] = cc * (axis.X * axis.Y) - (axis.Z * s);
	Value[1][1] = cc * (axis.Y * axis.Y) + c;
	Value[1][2] = cc * (axis.Y * axis.Z) + (axis.X * s);

	Value[2][0] = cc * (axis.Z * axis.X) + (axis.Y * s);
	Value[2][1] = cc * (axis.Y * axis.Z) - (axis.X * s);
	Value[2][2] = cc * (axis.Z * axis.Z) + c;

	Value[3][0] = 0.0f;
	Value[3][1] = 0.0f;
	Value[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::Translation(float x, float y, float z)
{
	Indentity();
	Value[3][0] = x;
	Value[3][1] = y;
	Value[3][2] = z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::GetSRT(Vector3D& s, Matrix43& r, Vector3D& t) const
{
#if defined(EFK_SSE2)
	t.X = Value[3][0];
	t.Y = Value[3][1];
	t.Z = Value[3][2];

	__m128 v0 = _mm_loadu_ps(&Value[0][0]);
	__m128 v1 = _mm_loadu_ps(&Value[1][0]);
	__m128 v2 = _mm_loadu_ps(&Value[2][0]);
	__m128 m0 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(1, 0, 1, 0));
	__m128 m1 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(3, 2, 3, 2));
	__m128 s0 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 0, 2, 0));
	__m128 s1 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 1, 3, 1));
	__m128 s2 = _mm_shuffle_ps(m1, v2, _MM_SHUFFLE(0, 2, 2, 0));
	s0 = _mm_mul_ps(s0, s0);
	s1 = _mm_mul_ps(s1, s1);
	s2 = _mm_mul_ps(s2, s2);
	__m128 vscq = _mm_add_ps(_mm_add_ps(s0, s1), s2);
	__m128 vsc = _mm_sqrt_ps(vscq);
	__m128 vscr = _mm_div_ps(vsc, vscq);
	EFK_ALIGN_AS(16)
	float sc[4];
	_mm_store_ps(sc, vsc);
	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];
	v0 = _mm_mul_ps(v0, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(0, 0, 0, 0)));
	v1 = _mm_mul_ps(v1, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(1, 1, 1, 1)));
	v2 = _mm_mul_ps(v2, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(2, 2, 2, 2)));
	_mm_storeu_ps(&r.Value[0][0], v0);
	_mm_storeu_ps(&r.Value[1][0], v1);
	_mm_storeu_ps(&r.Value[2][0], v2);
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#elif defined(EFK_NEON)
	t.X = Value[3][0];
	t.Y = Value[3][1];
	t.Z = Value[3][2];

	float32x4x3_t m = vld3q_f32(&Value[0][0]);
	float32x4_t vscq = vmulq_f32(m.val[0], m.val[0]);
	vscq = vmlaq_f32(vscq, m.val[1], m.val[1]);
	vscq = vmlaq_f32(vscq, m.val[2], m.val[2]);
	float32x4_t scr_rep = vrsqrteq_f32(vscq);
	float32x4_t scr_v = vmulq_f32(vrsqrtsq_f32(vmulq_f32(vscq, scr_rep), scr_rep), scr_rep);
	float32x4_t sc_v = vmulq_f32(scr_v, vscq);
	float sc[4];
	vst1q_f32(sc, sc_v);
	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];
	float32x4_t v0 = vld1q_f32(&Value[0][0]);
	float32x4_t v1 = vld1q_f32(&Value[1][0]);
	float32x4_t v2 = vld1q_f32(&Value[2][0]);
	vst1q_f32(&r.Value[0][0], vmulq_lane_f32(v0, vget_low_f32(scr_v), 0));
	vst1q_f32(&r.Value[1][0], vmulq_lane_f32(v1, vget_low_f32(scr_v), 1));
	vst1q_f32(&r.Value[2][0], vmulq_lane_f32(v2, vget_high_f32(scr_v), 0));
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#else
	t.X = Value[3][0];
	t.Y = Value[3][1];
	t.Z = Value[3][2];

	float sc[3];
	for (int m = 0; m < 3; m++)
	{
		sc[m] = std::sqrt(Value[m][0] * Value[m][0] + Value[m][1] * Value[m][1] + Value[m][2] * Value[m][2]);
	}

	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];

	for (int m = 0; m < 3; m++)
	{
		for (int n = 0; n < 3; n++)
		{
			r.Value[m][n] = Value[m][n] / sc[m];
		}
	}
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::GetScale(Vector3D& s) const
{
#ifdef SSE_MODULE
	SIMD::Mat44f mat;
	mat.X.SetX(Value[0][0]);
	mat.X.SetY(Value[0][1]);
	mat.X.SetZ(Value[0][2]);
	mat.Y.SetX(Value[1][0]);
	mat.Y.SetY(Value[1][1]);
	mat.Y.SetZ(Value[1][2]);
	mat.Z.SetX(Value[2][0]);
	mat.Z.SetY(Value[2][1]);
	mat.Z.SetZ(Value[2][2]);
	mat.W.SetX(0.0f);
	mat.W.SetY(0.0f);
	mat.W.SetZ(0.0f);

	mat.Transpose();

	auto x2 = mat.X * mat.X;
	auto y2 = mat.Y * mat.Y;
	auto z2 = mat.Z * mat.Z;
	auto s2 = x2 + y2 + z2;
	auto sq = sqrt(s2);
	s.X = sq.GetX();
	s.Y = sq.GetY();
	s.Z = sq.GetZ();

#else

#if defined(EFK_SSE2)
	__m128 v0 = _mm_loadu_ps(&Value[0][0]);
	__m128 v1 = _mm_loadu_ps(&Value[1][0]);
	__m128 v2 = _mm_loadu_ps(&Value[2][0]);
	__m128 m0 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(1, 0, 1, 0));
	__m128 m1 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(3, 2, 3, 2));
	__m128 s0 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 0, 2, 0));
	__m128 s1 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 1, 3, 1));
	__m128 s2 = _mm_shuffle_ps(m1, v2, _MM_SHUFFLE(0, 2, 2, 0));
	s0 = _mm_mul_ps(s0, s0);
	s1 = _mm_mul_ps(s1, s1);
	s2 = _mm_mul_ps(s2, s2);
	__m128 vscq = _mm_add_ps(_mm_add_ps(s0, s1), s2);
	__m128 sc_v = _mm_sqrt_ps(vscq);
	EFK_ALIGN_AS(16)
	float sc[4];
	_mm_store_ps(sc, sc_v);
	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];
#elif defined(EFK_NEON)
	float32x4x3_t m = vld3q_f32(&Value[0][0]);
	float32x4_t vscq = vmulq_f32(m.val[0], m.val[0]);
	vscq = vmlaq_f32(vscq, m.val[1], m.val[1]);
	vscq = vmlaq_f32(vscq, m.val[2], m.val[2]);
	float32x4_t scr_rep = vrsqrteq_f32(vscq);
	float32x4_t scr_v = vmulq_f32(vrsqrtsq_f32(vmulq_f32(vscq, scr_rep), scr_rep), scr_rep);
	float32x4_t sc_v = vmulq_f32(scr_v, vscq);
	float sc[4];
	vst1q_f32(sc, sc_v);
	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];
#else
	float sc[3];
	for (int m = 0; m < 3; m++)
	{
		sc[m] = std::sqrt(Value[m][0] * Value[m][0] + Value[m][1] * Value[m][1] + Value[m][2] * Value[m][2]);
	}

	s.X = sc[0];
	s.Y = sc[1];
	s.Z = sc[2];
#endif

#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::GetRotation(Matrix43& r) const
{
#if defined(EFK_SSE2)
	__m128 v0 = _mm_loadu_ps(&Value[0][0]);
	__m128 v1 = _mm_loadu_ps(&Value[1][0]);
	__m128 v2 = _mm_loadu_ps(&Value[2][0]);
	__m128 m0 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(1, 0, 1, 0));
	__m128 m1 = _mm_shuffle_ps(v0, v1, _MM_SHUFFLE(3, 2, 3, 2));
	__m128 s0 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 0, 2, 0));
	__m128 s1 = _mm_shuffle_ps(m0, v2, _MM_SHUFFLE(0, 1, 3, 1));
	__m128 s2 = _mm_shuffle_ps(m1, v2, _MM_SHUFFLE(0, 2, 2, 0));
	s0 = _mm_mul_ps(s0, s0);
	s1 = _mm_mul_ps(s1, s1);
	s2 = _mm_mul_ps(s2, s2);
	__m128 vscq = _mm_add_ps(_mm_add_ps(s0, s1), s2);
	__m128 vsc = _mm_sqrt_ps(vscq);
	__m128 vscr = _mm_div_ps(vsc, vscq);
	v0 = _mm_mul_ps(v0, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(0, 0, 0, 0)));
	v1 = _mm_mul_ps(v1, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(1, 1, 1, 1)));
	v2 = _mm_mul_ps(v2, _mm_shuffle_ps(vscr, vscr, _MM_SHUFFLE(2, 2, 2, 2)));
	_mm_storeu_ps(&r.Value[0][0], v0);
	_mm_storeu_ps(&r.Value[1][0], v1);
	_mm_storeu_ps(&r.Value[2][0], v2);
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#elif defined(EFK_NEON)
	float32x4x3_t m = vld3q_f32(&Value[0][0]);
	float32x4_t vscq = vmulq_f32(m.val[0], m.val[0]);
	vscq = vmlaq_f32(vscq, m.val[1], m.val[1]);
	vscq = vmlaq_f32(vscq, m.val[2], m.val[2]);
	float32x4_t scr_rep = vrsqrteq_f32(vscq);
	float32x4_t scr_v = vmulq_f32(vrsqrtsq_f32(vmulq_f32(vscq, scr_rep), scr_rep), scr_rep);
	float32x4_t v0 = vld1q_f32(&Value[0][0]);
	float32x4_t v1 = vld1q_f32(&Value[1][0]);
	float32x4_t v2 = vld1q_f32(&Value[2][0]);
	vst1q_f32(&r.Value[0][0], vmulq_lane_f32(v0, vget_low_f32(scr_v), 0));
	vst1q_f32(&r.Value[1][0], vmulq_lane_f32(v1, vget_low_f32(scr_v), 1));
	vst1q_f32(&r.Value[2][0], vmulq_lane_f32(v2, vget_high_f32(scr_v), 0));
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#else
	float sc[3];
	for (int m = 0; m < 3; m++)
	{
		sc[m] = std::sqrt(Value[m][0] * Value[m][0] + Value[m][1] * Value[m][1] + Value[m][2] * Value[m][2]);
	}

	for (int m = 0; m < 3; m++)
	{
		for (int n = 0; n < 3; n++)
		{
			r.Value[m][n] = Value[m][n] / sc[m];
		}
	}
	r.Value[3][0] = 0.0f;
	r.Value[3][1] = 0.0f;
	r.Value[3][2] = 0.0f;
#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::GetTranslation(Vector3D& t) const
{
	t.X = Value[3][0];
	t.Y = Value[3][1];
	t.Z = Value[3][2];
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::SetSRT(const Vector3D& s, const Matrix43& r, const Vector3D& t)
{
	Value[0][0] = s.X * r.Value[0][0];
	Value[0][1] = s.X * r.Value[0][1];
	Value[0][2] = s.X * r.Value[0][2];
	Value[1][0] = s.Y * r.Value[1][0];
	Value[1][1] = s.Y * r.Value[1][1];
	Value[1][2] = s.Y * r.Value[1][2];
	Value[2][0] = s.Z * r.Value[2][0];
	Value[2][1] = s.Z * r.Value[2][1];
	Value[2][2] = s.Z * r.Value[2][2];
	Value[3][0] = t.X;
	Value[3][1] = t.Y;
	Value[3][2] = t.Z;
}

void Matrix43::ToMatrix44(Matrix44& dst)
{
	for (int m = 0; m < 4; m++)
	{
		for (int n = 0; n < 3; n++)
		{
			dst.Values[m][n] = Value[m][n];
		}
		dst.Values[m][3] = 0.0f;
	}

	dst.Values[3][3] = 1.0f;
}

bool Matrix43::IsValid() const
{
	for (int m = 0; m < 4; m++)
	{
		for (int n = 0; n < 3; n++)
		{
			if (isinf(Value[m][n]))
				return false;
			if (isnan(Value[m][n]))
				return false;
		}
	}
	return true;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix43::Multiple(Matrix43& out, const Matrix43& in1, const Matrix43& in2)
{
#if defined(EFK_SSE2)
	__m128 s1_v0 = _mm_loadu_ps(&in1.Value[0][0]);
	__m128 s1_v1 = _mm_loadu_ps(&in1.Value[1][0]);
	__m128 s1_v2 = _mm_loadu_ps(&in1.Value[2][0]);
	__m128 s1_v3 = _mm_loadu_ps(&in1.Value[3][0] - 1);
	__m128 s2_v0 = _mm_loadu_ps(&in2.Value[0][0]);
	__m128 s2_v1 = _mm_loadu_ps(&in2.Value[1][0]);
	__m128 s2_v2 = _mm_loadu_ps(&in2.Value[2][0]);
	__m128 s2_v3 = _mm_loadu_ps(&in2.Value[3][0] - 1);
	__m128 o_v3;

	{
		__m128 s1_00 = _mm_shuffle_ps(s1_v0, s1_v0, _MM_SHUFFLE(0, 0, 0, 0));
		__m128 s1_01 = _mm_shuffle_ps(s1_v0, s1_v0, _MM_SHUFFLE(1, 1, 1, 1));
		__m128 s1_02 = _mm_shuffle_ps(s1_v0, s1_v0, _MM_SHUFFLE(2, 2, 2, 2));
		__m128 o_m00 = _mm_mul_ps(s1_00, s2_v0);
		__m128 o_m01 = _mm_mul_ps(s1_01, s2_v1);
		__m128 o_m02 = _mm_mul_ps(s1_02, s2_v2);
		__m128 o_v0 = _mm_add_ps(_mm_add_ps(o_m00, o_m01), o_m02);
		_mm_storeu_ps(&out.Value[0][0], o_v0);
	}
	{
		__m128 s1_10 = _mm_shuffle_ps(s1_v1, s1_v1, _MM_SHUFFLE(0, 0, 0, 0));
		__m128 s1_11 = _mm_shuffle_ps(s1_v1, s1_v1, _MM_SHUFFLE(1, 1, 1, 1));
		__m128 s1_12 = _mm_shuffle_ps(s1_v1, s1_v1, _MM_SHUFFLE(2, 2, 2, 2));
		__m128 o_m10 = _mm_mul_ps(s1_10, s2_v0);
		__m128 o_m11 = _mm_mul_ps(s1_11, s2_v1);
		__m128 o_m12 = _mm_mul_ps(s1_12, s2_v2);
		__m128 o_v1 = _mm_add_ps(_mm_add_ps(o_m10, o_m11), o_m12);
		_mm_storeu_ps(&out.Value[1][0], o_v1);
	}
	{
		__m128 s1_20 = _mm_shuffle_ps(s1_v2, s1_v2, _MM_SHUFFLE(0, 0, 0, 0));
		__m128 s1_21 = _mm_shuffle_ps(s1_v2, s1_v2, _MM_SHUFFLE(1, 1, 1, 1));
		__m128 s1_22 = _mm_shuffle_ps(s1_v2, s1_v2, _MM_SHUFFLE(2, 2, 2, 2));
		__m128 o_m20 = _mm_mul_ps(s1_20, s2_v0);
		__m128 o_m21 = _mm_mul_ps(s1_21, s2_v1);
		__m128 o_m22 = _mm_mul_ps(s1_22, s2_v2);
		__m128 o_v2 = _mm_add_ps(_mm_add_ps(o_m20, o_m21), o_m22);
		_mm_storeu_ps(&out.Value[2][0], o_v2);
		o_v3 = _mm_shuffle_ps(o_v2, o_v2, _MM_SHUFFLE(2, 2, 2, 2));
	}
	{
		EFK_ALIGN_AS(16)
		const uint32_t mask_u32[4] = {0xffffffff, 0x00000000, 0x00000000, 0x00000000};
		__m128 mask = _mm_load_ps((const float*)mask_u32);
		s2_v0 = _mm_shuffle_ps(s2_v0, s2_v0, _MM_SHUFFLE(2, 1, 0, 0));
		s2_v1 = _mm_shuffle_ps(s2_v1, s2_v1, _MM_SHUFFLE(2, 1, 0, 0));
		s2_v2 = _mm_shuffle_ps(s2_v2, s2_v2, _MM_SHUFFLE(2, 1, 0, 0));
		__m128 s1_30 = _mm_shuffle_ps(s1_v3, s1_v3, _MM_SHUFFLE(1, 1, 1, 1));
		__m128 s1_31 = _mm_shuffle_ps(s1_v3, s1_v3, _MM_SHUFFLE(2, 2, 2, 2));
		__m128 s1_32 = _mm_shuffle_ps(s1_v3, s1_v3, _MM_SHUFFLE(3, 3, 3, 3));
		__m128 o_m30 = _mm_mul_ps(s1_30, s2_v0);
		__m128 o_m31 = _mm_mul_ps(s1_31, s2_v1);
		__m128 o_m32 = _mm_mul_ps(s1_32, s2_v2);
		__m128 o_v3p = _mm_add_ps(_mm_add_ps(o_m30, o_m31), _mm_add_ps(o_m32, s2_v3));
		o_v3 = _mm_or_ps(_mm_and_ps(mask, o_v3), _mm_andnot_ps(mask, o_v3p));
		_mm_storeu_ps(&out.Value[3][0] - 1, o_v3);
	}
#elif defined(EFK_NEON)
	float32x4_t s1_v0 = vld1q_f32(&in1.Value[0][0]);
	float32x4_t s1_v12 = vld1q_f32(&in1.Value[1][1]);
	float32x4_t s1_v3 = vld1q_f32(&in1.Value[2][2]);
	float32x4_t s1_v1 = vextq_f32(s1_v0, s1_v12, 3);
	float32x4_t s1_v2 = vextq_f32(s1_v12, s1_v3, 2);
	float32x4_t s2_v0 = vld1q_f32(&in2.Value[0][0]);
	float32x4_t s2_v12 = vld1q_f32(&in2.Value[1][1]);
	float32x4_t s2_v3 = vld1q_f32(&in2.Value[2][2]);
	float32x4_t s2_v1 = vextq_f32(s2_v0, s2_v12, 3);
	float32x4_t s2_v2 = vextq_f32(s2_v12, s2_v3, 2);
	float o_v3_0;
	{
		float32x4_t o_v0 = vmulq_lane_f32(s2_v0, vget_low_f32(s1_v0), 0);
		float32x4_t o_v1 = vmulq_lane_f32(s2_v0, vget_low_f32(s1_v1), 0);
		float32x4_t o_v2 = vmulq_lane_f32(s2_v0, vget_low_f32(s1_v2), 0);
		o_v0 = vmlaq_lane_f32(o_v0, s2_v1, vget_low_f32(s1_v0), 1);
		o_v1 = vmlaq_lane_f32(o_v1, s2_v1, vget_low_f32(s1_v1), 1);
		o_v2 = vmlaq_lane_f32(o_v2, s2_v1, vget_low_f32(s1_v2), 1);
		o_v0 = vmlaq_lane_f32(o_v0, s2_v2, vget_high_f32(s1_v0), 0);
		o_v1 = vmlaq_lane_f32(o_v1, s2_v2, vget_high_f32(s1_v1), 0);
		o_v2 = vmlaq_lane_f32(o_v2, s2_v2, vget_high_f32(s1_v2), 0);
		vst1q_f32(&out.Value[0][0], o_v0);
		vst1q_f32(&out.Value[1][0], o_v1);
		vst1q_f32(&out.Value[2][0], o_v2);
		o_v3_0 = vgetq_lane_f32(o_v2, 2);
	}
	{
		s2_v0 = vextq_f32(s2_v0, s2_v0, 3);
		s2_v1 = vextq_f32(s2_v1, s2_v1, 3);
		s2_v2 = vextq_f32(s2_v2, s2_v2, 3);
		float32x4_t o_v3 = vmlaq_lane_f32(s2_v3, s2_v0, vget_low_f32(s1_v3), 1);
		o_v3 = vmlaq_lane_f32(o_v3, s2_v1, vget_high_f32(s1_v3), 0);
		o_v3 = vmlaq_lane_f32(o_v3, s2_v2, vget_high_f32(s1_v3), 1);
		vst1q_f32(&out.Value[3][0] - 1, vsetq_lane_f32(o_v3_0, o_v3, 0));
	}
#elif 1
	Matrix43 temp1, temp2;
	// 共通の場合は一時変数にコピー
	const Matrix43& s1 = (&out == &in1) ? (temp1 = in1) : in1;
	const Matrix43& s2 = (&out == &in2) ? (temp2 = in2) : in2;

	out.Value[0][0] = s1.Value[0][0] * s2.Value[0][0] + s1.Value[0][1] * s2.Value[1][0] + s1.Value[0][2] * s2.Value[2][0];
	out.Value[0][1] = s1.Value[0][0] * s2.Value[0][1] + s1.Value[0][1] * s2.Value[1][1] + s1.Value[0][2] * s2.Value[2][1];
	out.Value[0][2] = s1.Value[0][0] * s2.Value[0][2] + s1.Value[0][1] * s2.Value[1][2] + s1.Value[0][2] * s2.Value[2][2];

	out.Value[1][0] = s1.Value[1][0] * s2.Value[0][0] + s1.Value[1][1] * s2.Value[1][0] + s1.Value[1][2] * s2.Value[2][0];
	out.Value[1][1] = s1.Value[1][0] * s2.Value[0][1] + s1.Value[1][1] * s2.Value[1][1] + s1.Value[1][2] * s2.Value[2][1];
	out.Value[1][2] = s1.Value[1][0] * s2.Value[0][2] + s1.Value[1][1] * s2.Value[1][2] + s1.Value[1][2] * s2.Value[2][2];

	out.Value[2][0] = s1.Value[2][0] * s2.Value[0][0] + s1.Value[2][1] * s2.Value[1][0] + s1.Value[2][2] * s2.Value[2][0];
	out.Value[2][1] = s1.Value[2][0] * s2.Value[0][1] + s1.Value[2][1] * s2.Value[1][1] + s1.Value[2][2] * s2.Value[2][1];
	out.Value[2][2] = s1.Value[2][0] * s2.Value[0][2] + s1.Value[2][1] * s2.Value[1][2] + s1.Value[2][2] * s2.Value[2][2];

	out.Value[3][0] = s1.Value[3][0] * s2.Value[0][0] + s1.Value[3][1] * s2.Value[1][0] + s1.Value[3][2] * s2.Value[2][0] + s2.Value[3][0];
	out.Value[3][1] = s1.Value[3][0] * s2.Value[0][1] + s1.Value[3][1] * s2.Value[1][1] + s1.Value[3][2] * s2.Value[2][1] + s2.Value[3][1];
	out.Value[3][2] = s1.Value[3][0] * s2.Value[0][2] + s1.Value[3][1] * s2.Value[1][2] + s1.Value[3][2] * s2.Value[2][2] + s2.Value[3][2];
#else
	Matrix43 temp;

	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 3; j++)
		{
			float v = 0.0f;
			for (int k = 0; k < 3; k++)
			{
				v += in1.Value[i][k] * in2.Value[k][j];
			}
			temp.Value[i][j] = v;
		}
	}

	for (int i = 0; i < 3; i++)
	{
		temp.Value[3][i] += in2.Value[3][i];
	}

	out = temp;
#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
