
#ifndef __EFFEKSEER_MATRIX44_H__
#define __EFFEKSEER_MATRIX44_H__

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
	@brief	行列
	@note
	右手系<BR>
	左手系<BR>
	V[x,y,z,1] * M の形<BR>
	[0,0][0,1][0,2][0,3]
	[1,0][1,1][1,2][1,3]
	[2,0][2,1][2,2][2,3]
	[3,0][3,1][3,2][3,3]
*/
#pragma pack(push, 1)
struct Matrix44
{
private:
public:
	/**
		@brief	コンストラクタ
	*/
	Matrix44();

	/**
		@brief	行列の値
	*/
	float Values[4][4];

	/**
		@brief	単位行列化
	*/
	Matrix44& Indentity();

	/**
	@brief	転置行列化
	*/
	Matrix44& Transpose();

	/**
		@brief	カメラ行列化(右手系)
	*/
	Matrix44& LookAtRH(const Vector3D& eye, const Vector3D& at, const Vector3D& up);

	/**
		@brief	カメラ行列化(左手系)
	*/
	Matrix44& LookAtLH(const Vector3D& eye, const Vector3D& at, const Vector3D& up);

	/**
		@brief	射影行列化(右手系)
	*/
	Matrix44& PerspectiveFovRH(float ovY, float aspect, float zn, float zf);

	/**
		@brief	OpenGL用射影行列化(右手系)
	*/
	Matrix44& PerspectiveFovRH_OpenGL(float ovY, float aspect, float zn, float zf);

	/**
		@brief	射影行列化(左手系)
	*/
	Matrix44& PerspectiveFovLH(float ovY, float aspect, float zn, float zf);

	/**
	 @brief	OpenGL用射影行列化(左手系)
	 */
	Matrix44& PerspectiveFovLH_OpenGL(float ovY, float aspect, float zn, float zf);

	/**
		@brief	正射影行列化(右手系)
	*/
	Matrix44& OrthographicRH(float width, float height, float zn, float zf);

	/**
		@brief	正射影行列化(左手系)
	*/
	Matrix44& OrthographicLH(float width, float height, float zn, float zf);

	/**
		@brief	拡大行列化
	*/
	void Scaling(float x, float y, float z);

	/**
		@brief	X軸回転行列(右手)
	*/
	void RotationX(float angle);

	/**
		@brief	Y軸回転行列(右手)
	*/
	void RotationY(float angle);

	/**
		@brief	Z軸回転行列(右手)
	*/
	void RotationZ(float angle);

	/**
		@brief	移動行列
	*/
	void Translation(float x, float y, float z);

	/**
		@brief	任意軸反時計回転行列
	*/
	void RotationAxis(const Vector3D& axis, float angle);

	/**
		@brief	クオータニオンから行列に変換
	*/
	void Quaternion(float x, float y, float z, float w);

	/**
		@brief	乗算
	*/
	static Matrix44& Mul(Matrix44& o, const Matrix44& in1, const Matrix44& in2);

	/**
		@brief	逆行列
	*/
	static Matrix44& Inverse(Matrix44& o, const Matrix44& in);
};

#pragma pack(pop)
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_MATRIX44_H__
