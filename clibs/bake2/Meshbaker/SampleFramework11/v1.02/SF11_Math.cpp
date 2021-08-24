//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"
#include "SF11_Math.h"
#include "Utility.h"

namespace SampleFramework11
{

// == Float2 ======================================================================================

Float2::Float2()
{
    x = y = 0.0f;
}

Float2::Float2(float x_)
{
    x = y = x_;
}

Float2::Float2(float x_, float y_)
{
    x = x_;
    y = y_;
}

Float2::Float2(const XMFLOAT2& xy)
{
    x = xy.x;
    y = xy.y;
}

Float2::Float2(FXMVECTOR xy)
{
    XMStoreFloat2(reinterpret_cast<XMFLOAT2*>(this), xy);
}

Float2& Float2::operator+=(const Float2& other)
{
    x += other.x;
    y += other.y;
    return *this;
}

Float2 Float2::operator+(const Float2& other) const
{
    Float2 result;
    result.x = x + other.x;
    result.y = y + other.y;
    return result;
}

Float2& Float2::operator-=(const Float2& other)
{
    x -= other.x;
    y -= other.y;
    return *this;
}

Float2 Float2::operator-(const Float2& other) const
{
    Float2 result;
    result.x = x - other.x;
    result.y = y - other.y;
    return result;
}

Float2& Float2::operator*=(const Float2& other)
{
    x *= other.x;
    y *= other.y;
    return *this;
}

Float2 Float2::operator*(const Float2& other) const
{
    Float2 result;
    result.x = x * other.x;
    result.y = y * other.y;
    return result;
}

Float2& Float2::operator*=(float s)
{
    x *= s;
    y *= s;
    return *this;
}

Float2 Float2::operator*(float s) const
{
    Float2 result;
    result.x = x * s;
    result.y = y * s;
    return result;
}

Float2& Float2::operator/=(const Float2& other)
{
    x /= other.x;
    y /= other.y;
    return *this;
}

Float2 Float2::operator/(const Float2& other) const
{
    Float2 result;
    result.x = x / other.x;
    result.y = y / other.y;
    return result;
}

Float2& Float2::operator/=(float s)
{
    x /= s;
    y /= s;
    return *this;
}

Float2 Float2::operator/(float s) const
{
    Float2 result;
    result.x = x / s;
    result.y = y / s;
    return result;
}

bool Float2::operator==(const Float2& other) const
{
    return x == other.x && y == other.y;
}

bool Float2::operator!=(const Float2& other) const
{
    return x != other.x || y != other.y;
}

Float2 Float2::operator-() const
{
    Float2 result;
    result.x = -x;
    result.y = -y;

    return result;
}

XMVECTOR Float2::ToSIMD() const
{
    return XMLoadFloat2(reinterpret_cast<const XMFLOAT2*>(this));
}

Float2 Float2::Clamp(const Float2& val, const Float2& min, const Float2& max)
{
    Float2 retVal;
    retVal.x = SampleFramework11::Clamp(val.x, min.x, max.x);
    retVal.y = SampleFramework11::Clamp(val.y, min.y, max.y);
    return retVal;
}

float Float2::Length(const Float2& val)
{
    return std::sqrtf(val.x * val.x + val.y * val.y);
}

// == Float3 ======================================================================================

Float3::Float3()
{
    x = y = z = 0.0f;
}

Float3::Float3(float x_)
{
    x = y = z = x_;
}

Float3::Float3(float x_, float y_, float z_)
{
    x = x_;
    y = y_;
    z = z_;
}

Float3::Float3(Float2 xy, float z_)
{
    x = xy.x;
    y = xy.y;
    z = z_;
}

Float3::Float3(const XMFLOAT3& xyz)
{
    x = xyz.x;
    y = xyz.y;
    z = xyz.z;
}

Float3::Float3(FXMVECTOR xyz)
{
    XMStoreFloat3(reinterpret_cast<XMFLOAT3*>(this), xyz);
}

float Float3::operator[](unsigned int idx) const
{
    assert(idx < 3);
    return *(&x + idx);
}

Float3& Float3::operator+=(const Float3& other)
{
    x += other.x;
    y += other.y;
    z += other.z;
    return *this;
}

Float3 Float3::operator+(const Float3& other) const
{
    Float3 result;
    result.x = x + other.x;
    result.y = y + other.y;
    result.z = z + other.z;
    return result;
}

Float3& Float3::operator+=(float s)
{
    x += s;
    y += s;
    z += s;
    return *this;
}

Float3 Float3::operator+(float s) const
{
    Float3 result;
    result.x = x + s;
    result.y = y + s;
    result.z = z + s;
    return result;
}

Float3& Float3::operator-=(const Float3& other)
{
    x -= other.x;
    y -= other.y;
    z -= other.z;
    return *this;
}

Float3 Float3::operator-(const Float3& other) const
{
    Float3 result;
    result.x = x - other.x;
    result.y = y - other.y;
    result.z = z - other.z;
    return result;
}

Float3& Float3::operator-=(float s)
{
    x -= s;
    y -= s;
    z -= s;
    return *this;
}

Float3 Float3::operator-(float s) const
{
    Float3 result;
    result.x = x - s;
    result.y = y - s;
    result.z = z - s;
    return result;
}


Float3& Float3::operator*=(const Float3& other)
{
    x *= other.x;
    y *= other.y;
    z *= other.z;
    return *this;
}

Float3 Float3::operator*(const Float3& other) const
{
    Float3 result;
    result.x = x * other.x;
    result.y = y * other.y;
    result.z = z * other.z;
    return result;
}

Float3& Float3::operator*=(float s)
{
    x *= s;
    y *= s;
    z *= s;
    return *this;
}

Float3 Float3::operator*(float s) const
{
    Float3 result;
    result.x = x * s;
    result.y = y * s;
    result.z = z * s;
    return result;
}

Float3& Float3::operator/=(const Float3& other)
{
    x /= other.x;
    y /= other.y;
    z /= other.z;
    return *this;
}

Float3 Float3::operator/(const Float3& other) const
{
    Float3 result;
    result.x = x / other.x;
    result.y = y / other.y;
    result.z = z / other.z;
    return result;
}

Float3& Float3::operator/=(float s)
{
    x /= s;
    y /= s;
    z /= s;
    return *this;
}

Float3 Float3::operator/(float s) const
{
    Float3 result;
    result.x = x / s;
    result.y = y / s;
    result.z = z / s;
    return result;
}

bool Float3::operator==(const Float3& other) const
{
    return x == other.x && y == other.y && z == other.z;
}

bool Float3::operator!=(const Float3& other) const
{
    return x != other.x || y != other.y || z != other.z;
}

Float3 Float3::operator-() const
{
    Float3 result;
    result.x = -x;
    result.y = -y;
    result.z = -z;

    return result;
}

Float3 operator*(float a, const Float3& b)
{
    return Float3(a * b.x, a * b.y, a * b.z);
}

XMVECTOR Float3::ToSIMD() const
{
    return XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(this));
}

Float2 Float3::To2D() const
{
    return Float2(x, y);
}

float Float3::Length() const
{
    return Float3::Length(*this);
}

float Float3::Dot(const Float3& a, const Float3& b)
{
    return XMVectorGetX(XMVector3Dot(a.ToSIMD(), b.ToSIMD()));
}

Float3 Float3::Cross(const Float3& a, const Float3& b)
{
    Float3 result;
    XMStoreFloat3(reinterpret_cast<XMFLOAT3*>(&result), XMVector3Cross(a.ToSIMD(), b.ToSIMD()));
    return result;
}

Float3 Float3::Normalize(const Float3& a)
{
    Float3 result;
    XMStoreFloat3(reinterpret_cast<XMFLOAT3*>(&result), XMVector3Normalize(a.ToSIMD()));
    return result;
}

Float3 Float3::Transform(const Float3& v, const Float3x3& m)
{
    XMVECTOR vec = v.ToSIMD();
    vec = XMVector3TransformCoord(vec, m.ToSIMD());
    return Float3(vec);
}

Float3 Float3::Transform(const Float3& v, const Float4x4& m)
{
    XMVECTOR vec = v.ToSIMD();
    vec = XMVector3TransformCoord(vec, m.ToSIMD());
    return Float3(vec);
}

Float3 Float3::TransformDirection(const Float3&v, const Float4x4& m)
{
    XMVECTOR vec = v.ToSIMD();
    vec = XMVector3TransformNormal(vec, m.ToSIMD());
    return Float3(vec);
}

Float3 Float3::Transform(const Float3& v, const Quaternion& q)
{
    return Float3::Transform(v, q.ToFloat3x3());
}

Float3 Float3::Clamp(const Float3& val, const Float3& min, const Float3& max)
{
    Float3 retVal;
    retVal.x = SampleFramework11::Clamp(val.x, min.x, max.x);
    retVal.y = SampleFramework11::Clamp(val.y, min.y, max.y);
    retVal.z = SampleFramework11::Clamp(val.z, min.z, max.z);
    return retVal;
}

Float3 Float3::Perpendicular(const Float3& vec)
{
    Assert_(vec.Length() >= 0.00001f);

    Float3 perp;

    float x = std::abs(vec.x);
    float y = std::abs(vec.y);
    float z = std::abs(vec.z);
    float minVal = std::min(x, y);
    minVal = std::min(minVal, z);

    if(minVal == x)
        perp = Float3::Cross(vec, Float3(1.0f, 0.0f, 0.0f));
    else if(minVal == y)
        perp = Float3::Cross(vec, Float3(0.0f, 1.0f, 0.0f));
    else
        perp = Float3::Cross(vec, Float3(0.0f, 0.0f, 1.0f));

    return Float3::Normalize(perp);
}

Float3 Float3::Max(const Float3& a, const Float3& b)
{
	Float3 retVal;
	retVal.x = SampleFramework11::Max(a.x, b.x);
	retVal.y = SampleFramework11::Max(a.y, b.y);
	retVal.z = SampleFramework11::Max(a.z, b.z);
	return retVal;
}

float Float3::Distance(const Float3& a, const Float3& b)
{
    XMVECTOR x = a.ToSIMD();
    XMVECTOR y = b.ToSIMD();
    XMVECTOR length = XMVector3Length(XMVectorSubtract(x, y));
    return XMVectorGetX(length);
}

float Float3::Length(const Float3& v)
{
    XMVECTOR x =  v.ToSIMD();
    XMVECTOR length = XMVector3Length(x);
    return XMVectorGetX(length);
}

// == Float4 ======================================================================================

Float4::Float4()
{
    x = y = z = w = 0.0f;
}

Float4::Float4(float x_)
{
    x = y = z = w = x_;
}

Float4::Float4(float x_, float y_, float z_, float w_)
{
    x = x_;
    y = y_;
    z = z_;
    w = w_;
}

Float4::Float4(const Float3& xyz, float w_)
{
    x = xyz.x;
    y = xyz.y;
    z = xyz.z;
    w = w_;
}

Float4::Float4(const XMFLOAT4& xyzw)
{
    x = xyzw.x;
    y = xyzw.y;
    z = xyzw.z;
    w = xyzw.w;
}

Float4::Float4(FXMVECTOR xyzw)
{
    XMStoreFloat4(reinterpret_cast<XMFLOAT4*>(this), xyzw);
}

Float4& Float4::operator+=(const Float4& other)
{
    x += other.x;
    y += other.y;
    z += other.z;
    w += other.w;
    return *this;
}

Float4 Float4::operator+(const Float4& other) const
{
    Float4 result;
    result.x = x + other.x;
    result.y = y + other.y;
    result.z = z + other.z;
    result.w = w + other.w;
    return result;
}

Float4& Float4::operator-=(const Float4& other)
{
    x -= other.x;
    y -= other.y;
    z -= other.z;
    w -= other.w;
    return *this;
}

Float4 Float4::operator-(const Float4& other) const
{
    Float4 result;
    result.x = x - other.x;
    result.y = y - other.y;
    result.z = z - other.z;
    result.w = w - other.w;
    return result;
}

Float4& Float4::operator*=(const Float4& other)
{
    x *= other.x;
    y *= other.y;
    z *= other.z;
    w *= other.w;
    return *this;
}

Float4 Float4::operator*(const Float4& other) const
{
    Float4 result;
    result.x = x * other.x;
    result.y = y * other.y;
    result.z = z * other.z;
    result.w = w * other.w;
    return result;
}

Float4& Float4::operator/=(const Float4& other)
{
    x /= other.x;
    y /= other.y;
    z /= other.z;
    w /= other.w;
    return *this;
}

Float4 Float4::operator/(const Float4& other) const
{
    Float4 result;
    result.x = x / other.x;
    result.y = y / other.y;
    result.z = z / other.z;
    result.w = w / other.w;
    return result;
}

bool Float4::operator==(const Float4& other) const
{
    return x == other.x && y == other.y && z == other.z && w == other.w;
}

bool Float4::operator!=(const Float4& other) const
{
    return x != other.x || y != other.y || z != other.z || w != other.w;
}


Float4 Float4::operator-() const
{
    Float4 result;
    result.x = -x;
    result.y = -y;
    result.z = -z;
    result.w = -w;

    return result;
}

XMVECTOR Float4::ToSIMD() const
{
    return XMLoadFloat4(reinterpret_cast<const XMFLOAT4*>(this));
}

Float3 Float4::To3D() const
{
    return Float3(x, y, z);
}

Float2 Float4::To2D() const
{
    return Float2(x, y);
}

float Float4::Dot(const Float4& a, const Float4& b)
{
	return XMVectorGetX(XMVector4Dot(a.ToSIMD(), b.ToSIMD()));
}

Float4 Float4::Clamp(const Float4& val, const Float4& min, const Float4& max)
{
    Float4 retVal;
    retVal.x = SampleFramework11::Clamp(val.x, min.x, max.x);
    retVal.y = SampleFramework11::Clamp(val.y, min.y, max.y);
    retVal.z = SampleFramework11::Clamp(val.z, min.z, max.z);
    retVal.w = SampleFramework11::Clamp(val.w, min.w, max.w);
    return retVal;
}

Float4 Float4::Normalize(const Float4& a)
{
	Float4 result;
	XMStoreFloat4(reinterpret_cast<XMFLOAT4*>(&result), XMVector4Normalize(a.ToSIMD()));
	return result;
}

Float4 Float4::Transform(const Float4& v, const Float4x4& m)
{
    XMVECTOR vec = v.ToSIMD();
    vec = XMVector4Transform(vec, m.ToSIMD());
    return Float4(vec);
}

// == Quaternion ==================================================================================

Quaternion::Quaternion()
{
    *this = Quaternion::Identity();
}

Quaternion::Quaternion(float x_, float y_, float z_, float w_)
{
    x = x_;
    y = y_;
    z = z_;
    w = w_;
}

Quaternion::Quaternion(const Float3& axis, float angle)
{
    *this = Quaternion::FromAxisAngle(axis, angle);
}

Quaternion::Quaternion(const Float3x3& m)
{
    *this = XMQuaternionRotationMatrix(m.ToSIMD());
}

Quaternion::Quaternion(const XMFLOAT4& q)
{
    x = q.x;
    y = q.y;
    z = q.z;
    w = q.w;
}

Quaternion::Quaternion(FXMVECTOR q)
{
    XMStoreFloat4(reinterpret_cast<XMFLOAT4*>(this), q);
}

Quaternion& Quaternion::operator*=(const Quaternion& other)
{
    XMVECTOR q = ToSIMD();
    q = XMQuaternionMultiply(q, other.ToSIMD());
    XMStoreFloat4(reinterpret_cast<XMFLOAT4*>(this), q);

    return *this;
}

Quaternion Quaternion::operator*(const Quaternion& other) const
{
    Quaternion q = *this;
    q *= other;
    return q;
}

bool Quaternion::operator==(const Quaternion& other) const
{
    return x == other.x && y == other.y && z == other.z && w == other.w;
}

bool Quaternion::operator!=(const Quaternion& other) const
{
    return x != other.x || y != other.y || z != other.z || w != other.w;
}

Float3x3 Quaternion::ToFloat3x3() const
{
    return Float3x3(XMMatrixRotationQuaternion(ToSIMD()));
}

Float4x4 Quaternion::ToFloat4x4() const
{
    return Float4x4(XMMatrixRotationQuaternion(ToSIMD()));
}

Quaternion Quaternion::Identity()
{
    return Quaternion(0.0f, 0.0f, 0.0f, 1.0f);
}

Quaternion Quaternion::Invert(const Quaternion& q)
{
    return Quaternion(XMQuaternionInverse(q.ToSIMD()));
}

Quaternion Quaternion::FromAxisAngle(const Float3& axis, float angle)
{
    XMVECTOR q = XMQuaternionRotationAxis(axis.ToSIMD(), angle);
    return Quaternion(q);
}

Quaternion Quaternion::FromEuler(float x, float y, float z)
{
    XMVECTOR q = XMQuaternionRotationRollPitchYaw(x, y, z);
    return Quaternion(q);
}

Quaternion Quaternion::Normalize(const Quaternion& q)
{
    return Quaternion(XMQuaternionNormalize(q.ToSIMD()));
}

Float3x3 Quaternion::ToFloat3x3(const Quaternion& q)
{
    return q.ToFloat3x3();
}

Float4x4 Quaternion::ToFloat4x4(const Quaternion& q)
{
    return q.ToFloat4x4();
}

XMVECTOR Quaternion::ToSIMD() const
{
    return XMLoadFloat4(reinterpret_cast<const XMFLOAT4*>(this));
}

// == Float3x3 ====================================================================================

Float3x3::Float3x3()
{
    _11 = _22 = _33 = 1.00f;
    _12 = _13 = 0.0f;
    _21 = _23 = 0.0f;
    _31 = _32 = 0.0f;
}

Float3x3::Float3x3(const Float3& x, const Float3& y, const Float3& z)
{
    SetXBasis(x);
    SetYBasis(y);
    SetZBasis(z);
}

Float3x3::Float3x3(const XMFLOAT3X3& m)
{
    *static_cast<XMFLOAT3X3*>(this) = m;
}

Float3x3::Float3x3(CXMMATRIX m)
{
    XMStoreFloat3x3(this, m);
}

Float3x3& Float3x3::operator*=(const Float3x3& other)
{
    XMMATRIX result = this->ToSIMD() * other.ToSIMD();
    XMStoreFloat3x3(this, result);
    return *this;
}

Float3x3 Float3x3::operator*(const Float3x3& other) const
{
    XMMATRIX result = this->ToSIMD() * other.ToSIMD();
    return Float3x3(result);
}

Float3 Float3x3::Up() const
{
    return Float3(_21, _22, _23);
}

Float3 Float3x3::Down() const
{
    return Float3(-_21, -_22, -_23);
}

Float3 Float3x3::Left() const
{
    return Float3(-_11, -_12, -_13);
}

Float3 Float3x3::Right() const
{
    return Float3(_11, _12, _13);
}

Float3 Float3x3::Forward() const
{
    return Float3(_31, _32, _33);
}

Float3 Float3x3::Back() const
{
    return Float3(-_31, -_32, -_33);
}

void Float3x3::SetXBasis(const Float3& x)
{
    _11 = x.x;
    _12 = x.y;
    _13 = x.z;
}

void Float3x3::SetYBasis(const Float3& y)
{
    _21 = y.x;
    _22 = y.y;
    _23 = y.z;
}

void Float3x3::SetZBasis(const Float3& z)
{
    _31 = z.x;
    _32 = z.y;
    _33 = z.z;
}

Float3x3 Float3x3::Transpose(const Float3x3& m)
{
    return XMMatrixTranspose(m.ToSIMD());
}

Float3x3 Float3x3::Invert(const Float3x3& m)
{
    XMVECTOR det;
    return XMMatrixInverse(&det, m.ToSIMD());
}

Float3x3 Float3x3::ScaleMatrix(float s)
{
    Float3x3 m;
    m._11 = m._22 = m._33 = s;
    return m;
}

Float3x3 Float3x3::ScaleMatrix(const Float3& s)
{
    Float3x3 m;
    m._11 = s.x;
    m._22 = s.y;
    m._33 = s.z;
    return m;
}

XMMATRIX Float3x3::ToSIMD() const
{
    return XMLoadFloat3x3(this);
}

// == Float4x4 ====================================================================================

Float4x4::Float4x4()
{
    _11 = _22 = _33 = _44 = 1.00f;
    _12 = _13 = _14 = 0.0f;
    _21 = _23 = _24 = 0.0f;
    _31 = _32 = _34 = 0.0f;
    _41 = _42 = _43 = 0.0f;
}

Float4x4::Float4x4(const XMFLOAT4X4& m)
{
    *static_cast<XMFLOAT4X4*>(this) = m;
}

Float4x4::Float4x4(CXMMATRIX m)
{
    XMStoreFloat4x4(this, m);
}

Float4x4& Float4x4::operator*=(const Float4x4& other)
{
    XMMATRIX result = this->ToSIMD() * other.ToSIMD();
    XMStoreFloat4x4(this, result);
    return *this;
}

Float4x4 Float4x4::operator*(const Float4x4& other) const
{
    XMMATRIX result = this->ToSIMD() * other.ToSIMD();
    return Float4x4(result);
}

Float3 Float4x4::Up() const
{
    return Float3(_21, _22, _23);
}

Float3 Float4x4::Down() const
{
    return Float3(-_21, -_22, -_23);
}

Float3 Float4x4::Left() const
{
    return Float3(-_11, -_12, -_13);
}

Float3 Float4x4::Right() const
{
    return Float3(_11, _12, _13);
}

Float3 Float4x4::Forward() const
{
    return Float3(_31, _32, _33);
}

Float3 Float4x4::Back() const
{
    return Float3(-_31, -_32, -_33);
}

Float3 Float4x4::Translation() const
{
    return Float3(_41, _42, _43);
}

void Float4x4::SetTranslation(const Float3& t)
{
    _41 = t.x;
    _42 = t.y;
    _43 = t.z;
}

void Float4x4::SetXBasis(const Float3& x)
{
    _11 = x.x;
    _12 = x.y;
    _13 = x.z;
}

void Float4x4::SetYBasis(const Float3& y)
{
    _21 = y.x;
    _22 = y.y;
    _23 = y.z;
}

void Float4x4::SetZBasis(const Float3& z)
{
    _31 = z.x;
    _32 = z.y;
    _33 = z.z;
}

void Float4x4::Scale(const Float3& scale)
{
    _11 *= scale.x;
    _12 *= scale.x;
    _13 *= scale.x;

    _21 *= scale.y;
    _22 *= scale.y;
    _23 *= scale.y;

    _31 *= scale.z;
    _32 *= scale.z;
    _33 *= scale.z;
}

Float4x4 Float4x4::Transpose(const Float4x4& m)
{
    return XMMatrixTranspose(m.ToSIMD());
}

Float4x4 Float4x4::Invert(const Float4x4& m)
{
    XMVECTOR det;
    return XMMatrixInverse(&det, m.ToSIMD());
}

Float4x4 Float4x4::ScaleMatrix(float s)
{
    Float4x4 m;
    m._11 = m._22 = m._33 = s;
    return m;
}

Float4x4 Float4x4::ScaleMatrix(const Float3& s)
{
    Float4x4 m;
    m._11 = s.x;
    m._22 = s.y;
    m._33 = s.z;
    return m;
}

Float4x4 Float4x4::TranslationMatrix(const Float3& t)
{
    Float4x4 m;
    m.SetTranslation(t);
    return m;
}

bool Float4x4::operator==(const Float4x4& other) const
{
    const float* ours = reinterpret_cast<const float*>(this);
    const float* theirs = reinterpret_cast<const float*>(&other);
    for(uint64 i = 0; i < 16; ++i)
        if(ours[i] != theirs[i])
            return false;
    return true;
}

bool Float4x4::operator!=(const Float4x4& other) const
{
    const float* ours = reinterpret_cast<const float*>(this);
    const float* theirs = reinterpret_cast<const float*>(&other);
    for(uint64 i = 0; i < 16; ++i)
    if(ours[i] != theirs[i])
        return true;
    return false;
}

XMMATRIX Float4x4::ToSIMD() const
{
    return XMLoadFloat4x4(this);
}

std::string Float4x4::Print() const
{
    std::string result = "{ { " + ToAnsiString(_11) + ToAnsiString(_12) + ToAnsiString(_13) + ToAnsiString(_14) + "}";
    result += " { " + ToAnsiString(_21) + ToAnsiString(_22) + ToAnsiString(_23) + ToAnsiString(_24) + "}";
    result += " { " + ToAnsiString(_31) + ToAnsiString(_32) + ToAnsiString(_33) + ToAnsiString(_34) + "}";
    result += " { " + ToAnsiString(_41) + ToAnsiString(_42) + ToAnsiString(_43) + ToAnsiString(_44) + "} }";
    return result;
}

// == Uint2 =======================================================================================

Uint2::Uint2() : x(0), y(0)
{
}

Uint2::Uint2(uint32 x_, uint32 y_) : x(x_), y(y_)
{
}

bool Uint2::operator==(Uint2 other) const
{
    return x == other.x && y == other.y;
}

bool Uint2::operator!=(Uint2 other) const
{
    return x != other.x || y != other.y;
}

// == Int3 =======================================================================================

Uint3::Uint3() : x(0), y(0), z(0)
{
}

Uint3::Uint3(uint32 x_, uint32 y_, uint32 z_) : x(x_), y(y_), z(z_)
{
}

// == Uint4 =======================================================================================

Uint4::Uint4() : x(0), y(0), z(0), w(0)
{
}

Uint4::Uint4(uint32 x_, uint32 y_, uint32 z_, uint32 w_) : x(x_), y(y_), z(z_), w(w_)
{
}

// == Int2 =======================================================================================

Int2::Int2() : x(0), y(0)
{
}

Int2::Int2(int32 x_, int32 y_) : x(x_), y(y_)
{
}

bool Int2::operator==(Int2 other) const
{
    return x == other.x && y == other.y;
}

bool Int2::operator!=(Int2 other) const
{
    return x != other.x || y != other.y;
}

// == Int3 =======================================================================================

Int3::Int3() : x(0), y(0), z(0)
{
}

Int3::Int3(int32 x_, int32 y_, int32 z_) : x(x_), y(y_), z(z_)
{
}

// == Int4 =======================================================================================

Int4::Int4() : x(0), y(0), z(0), w(0)
{
}

Int4::Int4(int32 x_, int32 y_, int32 z_, int32 w_) : x(x_), y(y_), z(z_), w(w_)
{
}

// == Random ======================================================================================

void Random::SetSeed(uint32 seed)
{
    engine.seed(seed);
}

void Random::SeedWithRandomValue()
{
    std::random_device device;
    engine.seed(device());
}

uint32 Random::RandomUint()
{
    return engine();
}

float Random::RandomFloat()
{
    // return distribution(engine);
    return (RandomUint() & 0xFFFFFF) / float(1 << 24);
}

Float2 Random::RandomFloat2()
{
    return Float2(RandomFloat(), RandomFloat());
}

}