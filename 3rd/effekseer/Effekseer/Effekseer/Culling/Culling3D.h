
#ifndef __CULLING3D_CULLING3D_H__
#define __CULLING3D_CULLING3D_H__

#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

namespace Culling3D
{
/**
@brief	最大値取得
*/
template <typename T, typename U>
T Max(T t, U u)
{
	if (t > (T)u)
	{
		return t;
	}
	return u;
}

/**
@brief	最小値取得
*/
template <typename T, typename U>
T Min(T t, U u)
{
	if (t < (T)u)
	{
		return t;
	}
	return u;
}

/**
@brief	範囲内値取得
*/
template <typename T, typename U, typename V>
T Clamp(T t, U max_, V min_)
{
	if (t > (T)max_)
	{
		t = (T)max_;
	}

	if (t < (T)min_)
	{
		t = (T)min_;
	}

	return t;
}

template <class T>
void SafeAddRef(T& t)
{
	if (t != nullptr)
	{
		t->AddRef();
	}
}

template <class T>
void SafeRelease(T& t)
{
	if (t != nullptr)
	{
		t->Release();
		t = nullptr;
	}
}

template <class T>
void SafeSubstitute(T& target, T& value)
{
	SafeAddRef(value);
	SafeRelease(target);
	target = value;
}

template <typename T>
inline void SafeDelete(T*& p)
{
	if (p != nullptr)
	{
		delete (p);
		(p) = nullptr;
	}
}

template <typename T>
inline void SafeDeleteArray(T*& p)
{
	if (p != nullptr)
	{
		delete[](p);
		(p) = nullptr;
	}
}

class World;
class Object;

struct Vector3DF
{
	float X;
	float Y;
	float Z;

	Vector3DF();
	Vector3DF(float x, float y, float z);

	bool operator==(const Vector3DF& o);
	bool operator!=(const Vector3DF& o);

	Vector3DF operator-();

	Vector3DF operator+(const Vector3DF& o) const;

	Vector3DF operator-(const Vector3DF& o) const;

	Vector3DF operator*(const Vector3DF& o) const;

	Vector3DF operator/(const Vector3DF& o) const;

	Vector3DF operator*(const float& o) const;

	Vector3DF operator/(const float& o) const;

	Vector3DF& operator+=(const Vector3DF& o);

	Vector3DF& operator-=(const Vector3DF& o);

	Vector3DF& operator*=(const Vector3DF& o);

	Vector3DF& operator/=(const Vector3DF& o);

	Vector3DF& operator*=(const float& o);

	Vector3DF& operator/=(const float& o);

	/**
	@brief	このベクトルの長さを取得する。
	*/
	float GetLength() const
	{
		return sqrtf(GetSquaredLength());
	}

	/**
	@brief	このベクトルの長さの二乗を取得する。
	*/
	float GetSquaredLength() const
	{
		return X * X + Y * Y + Z * Z;
	}

	/**
	@brief	このベクトルの長さを設定する。
	*/
	void SetLength(float value)
	{
		float length = GetLength();
		(*this) *= (value / length);
	}

	/**
	@brief	このベクトルの単位ベクトルを取得する。
	*/
	Vector3DF GetNormal()
	{
		float length = GetLength();
		return Vector3DF(X / length, Y / length, Z / length);
	}

	/**
	@brief	このベクトルの単位ベクトル化する。
	*/
	void Normalize()
	{
		float length = GetLength();
		(*this) /= length;
	}

	/**
	@brief	内積を取得する。
	*/
	static float Dot(const Vector3DF& v1, const Vector3DF& v2);

	/**
	@brief	外積を取得する。
	@note
	右手系の場合、右手の親指がv1、人差し指がv2としたとき、中指の方向を返す。<BR>
	左手系の場合、左手の親指がv1、人差し指がv2としたとき、中指の方向を返す。<BR>
	*/
	static Vector3DF Cross(const Vector3DF& v1, const Vector3DF& v2);

	/**
	@brief	2点間の距離を取得する。
	*/
	static float Distance(const Vector3DF& v1, const Vector3DF& v2);
};

struct Matrix44
{
	float Values[4][4];

	Matrix44();
	Matrix44& SetInverted();
	Vector3DF Transform3D(const Vector3DF& in) const;

	/**
	@brief	カメラ行列(右手系)を設定する。
	@param	eye	カメラの位置
	@param	at	カメラの注視点
	@param	up	カメラの上方向
	@return	このインスタンスへの参照
	*/
	Matrix44& SetLookAtRH(const Vector3DF& eye, const Vector3DF& at, const Vector3DF& up);

	/**
	@brief	カメラ行列(左手系)を設定する。
	@param	eye	カメラの位置
	@param	at	カメラの注視点
	@param	up	カメラの上方向
	@return	このインスタンスへの参照
	*/
	Matrix44& SetLookAtLH(const Vector3DF& eye, const Vector3DF& at, const Vector3DF& up);

	/**
	@brief	射影行列(右手系)を設定する。
	@param	ovY	Y方向への視野角(ラジアン)
	@param	aspect	画面のアスペクト比
	@param	zn	最近距離
	@param	zf	最遠距離
	@return	このインスタンスへの参照
	*/
	Matrix44& SetPerspectiveFovRH(float ovY, float aspect, float zn, float zf);

	/**
	@brief	OpenGL用射影行列(右手系)を設定する。
	@param	ovY	Y方向への視野角(ラジアン)
	@param	aspect	画面のアスペクト比
	@param	zn	最近距離
	@param	zf	最遠距離
	@return	このインスタンスへの参照
	*/
	Matrix44& SetPerspectiveFovRH_OpenGL(float ovY, float aspect, float zn, float zf);

	/**
	@brief	射影行列(左手系)を設定する。
	@param	ovY	Y方向への視野角(ラジアン)
	@param	aspect	画面のアスペクト比
	@param	zn	最近距離
	@param	zf	最遠距離
	@return	このインスタンスへの参照
	*/
	Matrix44& SetPerspectiveFovLH(float ovY, float aspect, float zn, float zf);

	/**
	@brief	正射影行列(右手系)を設定する。
	@param	width	横幅
	@param	height	縦幅
	@param	zn	最近距離
	@param	zf	最遠距離
	@return	このインスタンスへの参照
	*/
	Matrix44& SetOrthographicRH(float width, float height, float zn, float zf);

	/**
	@brief	正射影行列(左手系)を設定する。
	@param	width	横幅
	@param	height	縦幅
	@param	zn	最近距離
	@param	zf	最遠距離
	@return	このインスタンスへの参照
	*/
	Matrix44& SetOrthographicLH(float width, float height, float zn, float zf);

	Matrix44 operator*(const Matrix44& right) const;

	Vector3DF operator*(const Vector3DF& right) const;

	/**
	@brief	乗算を行う。
	@param	o	出力先
	@param	in1	行列1
	@param	in2	行列2
	@return	出力先の参照
	*/
	static Matrix44& Mul(Matrix44& o, const Matrix44& in1, const Matrix44& in2);
};

enum eObjectShapeType
{
	OBJECT_SHAPE_TYPE_NONE,
	OBJECT_SHAPE_TYPE_SPHERE,
	OBJECT_SHAPE_TYPE_CUBOID,
	OBJECT_SHAPE_TYPE_ALL,
};

class IReference
{
public:
	/**
	@brief	参照カウンタを加算する。
	@return	加算後の参照カウンタ
	*/
	virtual int AddRef() = 0;

	/**
	@brief	参照カウンタを取得する。
	@return	参照カウンタ
	*/
	virtual int GetRef() = 0;

	/**
	@brief	参照カウンタを減算する。0になった時、インスタンスを削除する。
	@return	減算後の参照カウンタ
	*/
	virtual int Release() = 0;
};

class World : public IReference
{
public:
	virtual void AddObject(Object* o) = 0;
	virtual void RemoveObject(Object* o) = 0;

	virtual void CastRay(Vector3DF from, Vector3DF to) = 0;

	virtual void Culling(const Matrix44& cameraProjMat, bool isOpenGL) = 0;
	virtual int32_t GetObjectCount() = 0;
	virtual Object* GetObject(int32_t index) = 0;

	virtual bool Reassign() = 0;

	virtual void Dump(const char* path, const Matrix44& cameraProjMat, bool isOpenGL) = 0;

	static World* Create(float xSize, float ySize, float zSize, int32_t layerCount);
};

class Object : public IReference
{
public:
	virtual Vector3DF GetPosition() = 0;
	virtual void SetPosition(Vector3DF pos) = 0;
	virtual void ChangeIntoAll() = 0;
	virtual void ChangeIntoSphere(float radius) = 0;
	virtual void ChangeIntoCuboid(Vector3DF size) = 0;

	virtual void* GetUserData() = 0;
	virtual void SetUserData(void* data) = 0;

	static Object* Create();
};
} // namespace Culling3D

#endif