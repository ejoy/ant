
#ifndef __EFFEKSEER_MATRIX43_H__
#define __EFFEKSEER_MATRIX43_H__

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

struct Matrix44;

/**
	@brief	4x3行列
	@note
	右手系(回転:反時計回り)<BR>
	V[x,y,z,1] * M の形でベクトルとの乗算が可能である。<BR>
	[0,0][0,1][0,2]<BR>
	[1,0][1,1][1,2]<BR>
	[2,0][2,1][2,2]<BR>
	[3,0][3,1][3,2]<BR>
*/
struct Matrix43
{
private:
public:
	/**
		@brief	行列の値
	*/
	float Value[4][3];

	/**
		@brief	単位行列化を行う。
	*/
	void Indentity();

	/**
		@brief	拡大行列化を行う。
		@param	x	[in]	X方向拡大率
		@param	y	[in]	Y方向拡大率
		@param	z	[in]	Z方向拡大率
	*/
	void Scaling(float x, float y, float z);

	/**
		@brief	反時計周り方向のX軸回転行列化を行う。
		@param	angle	[in]	角度(ラジアン)
	*/
	void RotationX(float angle);

	/**
		@brief	反時計周り方向のY軸回転行列化を行う。
		@param	angle	[in]	角度(ラジアン)
	*/
	void RotationY(float angle);

	/**
		@brief	反時計周り方向のZ軸回転行列化を行う。
		@param	angle	[in]	角度(ラジアン)
	*/
	void RotationZ(float angle);

	/**
		@brief	反時計周り方向のXYZ軸回転行列化を行う。
		@param	rx	[in]	角度(ラジアン)
		@param	ry	[in]	角度(ラジアン)
		@param	rz	[in]	角度(ラジアン)
	*/
	void RotationXYZ(float rx, float ry, float rz);

	/**
		@brief	反時計周り方向のZXY軸回転行列化を行う。
		@param	rz	[in]	角度(ラジアン)
		@param	rx	[in]	角度(ラジアン)
		@param	ry	[in]	角度(ラジアン)
	*/
	void RotationZXY(float rz, float rx, float ry);

	/**
		@brief	任意軸に対する反時計周り方向回転行列化を行う。
		@param	axis	[in]	回転軸
		@param	angle	[in]	角度(ラジアン)
	*/
	void RotationAxis(const Vector3D& axis, float angle);

	/**
		@brief	任意軸に対する反時計周り方向回転行列化を行う。
		@param	axis	[in]	回転軸
		@param	s	[in]	サイン
		@param	c	[in]	コサイン
	*/
	void RotationAxis(const Vector3D& axis, float s, float c);

	/**
		@brief	移動行列化を行う。
		@param	x	[in]	X方向移動
		@param	y	[in]	Y方向移動
		@param	z	[in]	Z方向移動
	*/
	void Translation(float x, float y, float z);

	/**
		@brief	行列を、拡大、回転、移動の行列とベクトルに分解する。
		@param	s	[out]	拡大行列
		@param	r	[out]	回転行列
		@param	t	[out]	位置
	*/
	void GetSRT(Vector3D& s, Matrix43& r, Vector3D& t) const;

	/**
		@brief	行列から拡大ベクトルを取得する。
		@param	s	[out]	拡大ベクトル
	*/
	void GetScale(Vector3D& s) const;

	/**
		@brief	行列から回転行列を取得する。
		@param	s	[out]	回転行列
	*/
	void GetRotation(Matrix43& r) const;

	/**
		@brief	行列から移動ベクトルを取得する。
		@param	t	[out]	移動ベクトル
	*/
	void GetTranslation(Vector3D& t) const;

	/**
		@brief	行列の拡大、回転、移動を設定する。
		@param	s	[in]	拡大行列
		@param	r	[in]	回転行列
		@param	t	[in]	位置
	*/
	void SetSRT(const Vector3D& s, const Matrix43& r, const Vector3D& t);

	/**
		@brief	convert into matrix44
	*/
	void ToMatrix44(Matrix44& dst);

	/**
		@brief	check whether all values are not valid number(not nan, not inf)
	*/
	bool IsValid() const;

	/**
		@brief	行列同士の乗算を行う。
		@param	out	[out]	結果
		@param	in1	[in]	乗算の左側
		@param	in2	[in]	乗算の右側
	*/
	static void Multiple(Matrix43& out, const Matrix43& in1, const Matrix43& in2);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_MATRIX43_H__
