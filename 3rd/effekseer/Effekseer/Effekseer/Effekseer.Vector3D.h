
#ifndef __EFFEKSEER_VECTOR3D_H__
#define __EFFEKSEER_VECTOR3D_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	3次元ベクトル
*/
struct Vector3D
{
public:
	/**
		@brief	X
	*/
	float X;

	/**
		@brief	Y
	*/
	float Y;

	/**
		@brief	Z
	*/
	float Z;

	/**
		@brief	コンストラクタ
	*/
	Vector3D();

	/**
		@brief	コンストラクタ
	*/
	Vector3D(float x, float y, float z);

	Vector3D operator-();

	Vector3D operator+(const Vector3D& o) const;

	Vector3D operator-(const Vector3D& o) const;

	Vector3D operator*(const float& o) const;

	Vector3D operator/(const float& o) const;

	Vector3D operator*(const Vector3D& o) const;

	Vector3D operator/(const Vector3D& o) const;

	Vector3D& operator+=(const Vector3D& o);

	Vector3D& operator-=(const Vector3D& o);

	Vector3D& operator*=(const float& o);

	Vector3D& operator/=(const float& o);

	bool operator==(const Vector3D& o);

	/**
		@brief	加算
	*/
	static void Add(Vector3D* pOut, const Vector3D* pIn1, const Vector3D* pIn2);

	/**
		@brief	減算
	*/
	static Vector3D& Sub(Vector3D& o, const Vector3D& in1, const Vector3D& in2);

	/**
		@brief	長さ
	*/
	static float Length(const Vector3D& in);

	/**
		@brief	長さの二乗
	*/
	static float LengthSq(const Vector3D& in);

	/**
		@brief	内積
	*/
	static float Dot(const Vector3D& in1, const Vector3D& in2);

	/**
		@brief	単位ベクトル
	*/
	static void Normal(Vector3D& o, const Vector3D& in);

	/**
		@brief	外積
		@note
		右手系の場合、右手の親指がin1、人差し指がin2としたとき、中指の方向を返す。<BR>
		左手系の場合、左手の親指がin1、人差し指がin2としたとき、中指の方向を返す。<BR>
	*/
	static Vector3D& Cross(Vector3D& o, const Vector3D& in1, const Vector3D& in2);

	static Vector3D& Transform(Vector3D& o, const Vector3D& in, const Matrix43& mat);

	static Vector3D& Transform(Vector3D& o, const Vector3D& in, const Matrix44& mat);

	static Vector3D& TransformWithW(Vector3D& o, const Vector3D& in, const Matrix44& mat);

	/**
		@brief 
		\~English	Convert Vector3D into std::array<float,4>
		\~Japanese	Vector3D から std::array<float,4> に変換する。
	*/
	std::array<float, 4> ToFloat4() const
	{
		std::array<float, 4> fc{X, Y, Z, 1.0f};
		return fc;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_VECTOR3D_H__
