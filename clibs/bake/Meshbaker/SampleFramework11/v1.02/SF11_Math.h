
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"
#include "Assert_.h"

namespace SampleFramework11
{

// Forward declarations
struct Quaternion;
struct Float3x3;
struct Float4x4;

// Extension classes for XMFLOAT* classes

struct Float2
{
    float x, y;

    Float2();
    Float2(float x);
    Float2(float x, float y);
    Float2(const XMFLOAT2& xy);
    Float2(FXMVECTOR xy);

    Float2& operator+=(const Float2& other);
    Float2 operator+(const Float2& other) const;

    Float2& operator-=(const Float2& other);
    Float2 operator-(const Float2& other) const;

    Float2& operator*=(const Float2& other);
    Float2 operator*(const Float2& other) const;

    Float2& operator*=(float s);
    Float2 operator*(float s) const;

    Float2& operator/=(const Float2& other);
    Float2 operator/(const Float2& other) const;

    Float2& operator/=(float s);
    Float2 operator/(float s) const;

    bool operator==(const Float2& other) const;
    bool operator!=(const Float2& other) const;

    Float2 operator-() const;

    XMVECTOR ToSIMD() const;

    static Float2 Clamp(const Float2& val, const Float2& min, const Float2& max);
    static float Length(const Float2& val);
};

struct Float3
{
    float x, y, z;

    Float3();
    Float3(float x);
    Float3(float x, float y, float z);
    Float3(Float2 xy, float z);
    Float3(const XMFLOAT3& xyz);
    Float3(FXMVECTOR xyz);

    float operator[](unsigned int idx) const;
    Float3& operator+=(const Float3& other);
    Float3 operator+(const Float3& other) const;

    Float3& operator+=(float other);
    Float3 operator+(float other) const;

    Float3& operator-=(const Float3& other);
    Float3 operator-(const Float3& other) const;

    Float3& operator-=(float s);
    Float3 operator-(float s) const;

    Float3& operator*=(const Float3& other);
    Float3 operator*(const Float3& other) const;

    Float3& operator*=(float s);
    Float3 operator*(float s) const;

    Float3& operator/=(const Float3& other);
    Float3 operator/(const Float3& other) const;

    Float3& operator/=(float s);
    Float3 operator/(float s) const;

    bool operator==(const Float3& other) const;
    bool operator!=(const Float3& other) const;

    Float3 operator-() const;

    XMVECTOR ToSIMD() const;
    Float2 To2D() const;

    float Length() const;

    static float Dot(const Float3& a, const Float3& b);
    static Float3 Cross(const Float3& a, const Float3& b);
    static Float3 Normalize(const Float3& a);
    static Float3 Transform(const Float3& v, const Float3x3& m);
    static Float3 Transform(const Float3& v, const Float4x4& m);
    static Float3 TransformDirection(const Float3&v, const Float4x4& m);
    static Float3 Transform(const Float3& v, const Quaternion& q);
    static Float3 Clamp(const Float3& val, const Float3& min, const Float3& max);
    static Float3 Perpendicular(const Float3& v);
	static Float3 Max(const Float3& a, const Float3& b);
    static float Distance(const Float3& a, const Float3& b);
    static float Length(const Float3& v);
};

// Non-member operators of Float3
Float3 operator*(float a, const Float3& b);

struct Float4
{
    float x, y, z, w;

    Float4();
    Float4(float x);
    Float4(float x, float y, float z, float w);
    Float4(const Float3& xyz, float w = 0.0f);
    Float4(const XMFLOAT4& xyzw);
    Float4(FXMVECTOR xyzw);

    Float4& operator+=(const Float4& other);
    Float4 operator+(const Float4& other) const;

    Float4& operator-=(const Float4& other);
    Float4 operator-(const Float4& other) const;

    Float4& operator*=(const Float4& other);
    Float4 operator*(const Float4& other) const;

    Float4& operator/=(const Float4& other);
    Float4 operator/(const Float4& other) const;

    bool operator==(const Float4& other) const;
    bool operator!=(const Float4& other) const;

    Float4 operator-() const;

    XMVECTOR ToSIMD() const;
    Float3 To3D() const;
    Float2 To2D() const;

	static float Dot(const Float4& a, const Float4& b);
    static Float4 Clamp(const Float4& val, const Float4& min, const Float4& max);
	static Float4 Normalize(const Float4& a);
    static Float4 Transform(const Float4& v, const Float4x4& m);
};

struct Quaternion
{
    float x, y, z, w;

    Quaternion();
    Quaternion(float x, float y, float z, float w);
    Quaternion(const Float3& axis, float angle);
    Quaternion(const Float3x3& m);
    Quaternion(const XMFLOAT4& q);
    Quaternion(FXMVECTOR q);

    Quaternion& operator*=(const Quaternion& other);
    Quaternion operator*(const Quaternion& other) const;

    bool operator==(const Quaternion& other) const;
    bool operator!=(const Quaternion& other) const;

    Float3x3 ToFloat3x3() const;
    Float4x4 ToFloat4x4() const;

    static Quaternion Identity();
    static Quaternion Invert(const Quaternion& q);
    static Quaternion FromAxisAngle(const Float3& axis, float angle);
    static Quaternion FromEuler(float x, float y, float z);
    static Quaternion Normalize(const Quaternion& q);
    static Float3x3 ToFloat3x3(const Quaternion& q);
    static Float4x4 ToFloat4x4(const Quaternion& q);

    XMVECTOR ToSIMD() const;
};

struct Float3x3 : public XMFLOAT3X3
{
    Float3x3();
    Float3x3(const Float3& x, const Float3& y, const Float3& z);
    Float3x3(const XMFLOAT3X3& m);
    Float3x3(CXMMATRIX m);

    Float3x3& operator*=(const Float3x3& other);
    Float3x3 operator*(const Float3x3& other) const;

    Float3 Up() const;
    Float3 Down() const;
    Float3 Left() const;
    Float3 Right() const;
    Float3 Forward() const;
    Float3 Back() const;

    void SetXBasis(const Float3& x);
    void SetYBasis(const Float3& y);
    void SetZBasis(const Float3& z);

    static Float3x3 Transpose(const Float3x3& m);
    static Float3x3 Invert(const Float3x3& m);
    static Float3x3 ScaleMatrix(float s);
    static Float3x3 ScaleMatrix(const Float3& s);

    XMMATRIX ToSIMD() const;
};

struct Float4x4 : public XMFLOAT4X4
{
    Float4x4();
    Float4x4(const XMFLOAT4X4& m);
    Float4x4(CXMMATRIX m);

    Float4x4& operator*=(const Float4x4& other);
    Float4x4 operator*(const Float4x4& other) const;

    Float3 Up() const;
    Float3 Down() const;
    Float3 Left() const;
    Float3 Right() const;
    Float3 Forward() const;
    Float3 Back() const;

    Float3 Translation() const;
    void SetTranslation(const Float3& t);

    void SetXBasis(const Float3& x);
    void SetYBasis(const Float3& y);
    void SetZBasis(const Float3& z);

    void Scale(const Float3& scale);

    static Float4x4 Transpose(const Float4x4& m);
    static Float4x4 Invert(const Float4x4& m);
    static Float4x4 ScaleMatrix(float s);
    static Float4x4 ScaleMatrix(const Float3& s);
    static Float4x4 TranslationMatrix(const Float3& t);

    bool operator==(const Float4x4& other) const;
    bool operator!=(const Float4x4& other) const;

    XMMATRIX ToSIMD() const;

    std::string Print() const;
};

// Unsigned 32-bit integer vector classes
struct Uint2
{
    uint32 x;
    uint32 y;

    Uint2();
    Uint2(uint32 x, uint32 y);

    bool operator==(Uint2 other) const;
    bool operator!=(Uint2 other) const;
};

struct Uint3
{
    uint32 x;
    uint32 y;
    uint32 z;

    Uint3();
    Uint3(uint32 x, uint32 y, uint32 z);
};

struct Uint4
{
    uint32 x;
    uint32 y;
    uint32 z;
    uint32 w;

    Uint4();
    Uint4(uint32 x, uint32 y, uint32 z, uint32 w);
};

// Signed 32-bit integer vector classes
struct Int2
{
    int32 x;
    int32 y;

    Int2();
    Int2(int32 x, int32 y);

    bool operator==(Int2 other) const;
    bool operator!=(Int2 other) const;
};

struct Int3
{
    int32 x;
    int32 y;
    int32 z;

    Int3();
    Int3(int32 x, int32 y, int32 z);
};

struct Int4
{
    int32 x;
    int32 y;
    int32 z;
    int32 w;

    Int4();
    Int4(int32 x, int32 y, int32 z, int32 w);
};


// Conversion classes for reduced-precision representations
struct Half2
{
    uint16 x;
    uint16 y;

    Half2() : x(0), y(0)
    {
    }

    Half2(uint16 x, uint16 y) : x(x), y(y)
    {
    }

    Half2(float x, float y)
    {
        XMStoreHalf2(reinterpret_cast<XMHALF2*>(this), XMVectorSet(x, y, 0.0f, 0.0f));
    }

    Half2(const Float2& v)
    {
        XMStoreHalf2(reinterpret_cast<XMHALF2*>(this), v.ToSIMD());
    }

    XMVECTOR ToSIMD() const
    {
        return XMLoadHalf2(reinterpret_cast<const XMHALF2*>(this));
    }
};

struct Half4
{
    uint16 x;
    uint16 y;
    uint16 z;
    uint16 w;

    Half4() : x(0), y(0), z(0), w(0)
    {
    }

    Half4(uint16 x, uint16 y, uint16 z, uint16 w) : x(x), y(y), z(z), w(w)
    {
    }

    Half4(float x, float y, float z, float w)
    {
        XMStoreHalf4(reinterpret_cast<XMHALF4*>(this), XMVectorSet(x, y, z, w));
    }

    Half4(const Float4& v)
    {
        XMStoreHalf4(reinterpret_cast<XMHALF4*>(this), v.ToSIMD());
    }

    XMVECTOR ToSIMD() const
    {
        return XMLoadHalf4(reinterpret_cast<const XMHALF4*>(this));
    }

    Float3 ToFloat3() const
    {
        return Float3(ToSIMD());
    }

    Float4 ToFloat4() const
    {
        return Float4(ToSIMD());
    }
};

struct UByte4N
{
    uint32 Bits;

    UByte4N() : Bits(0)
    {
    }

    UByte4N(uint32 bits) : Bits(Bits)
    {
    }

    UByte4N(uint8 x, uint8 y, uint8 z, uint8 w)
    {
        Bits = x | (y << 8) | (z << 16) | (w << 14);
    }

    UByte4N(float x, float y, float z, float w)
    {
        XMStoreUByteN4(reinterpret_cast<XMUBYTEN4*>(this), XMVectorSet(x, y, z, w));
    }

    UByte4N(const Float4& v)
    {
        XMStoreUByteN4(reinterpret_cast<XMUBYTEN4*>(this), v.ToSIMD());
    }

    XMVECTOR ToSIMD() const
    {
        return XMLoadUByteN4(reinterpret_cast<const XMUBYTEN4*>(this));
    }
};

// Random number generation
class Random
{

public:

    void SetSeed(uint32 seed);
    void SeedWithRandomValue();

    uint32 RandomUint();
    float RandomFloat();
    Float2 RandomFloat2();

private:

    std::mt19937 engine;
    std::uniform_real_distribution<float> distribution;
};

template<typename T> void Swap(T& a, T& b)
{
    T tmp = a;
    a = b;
    b = tmp;
}

template<typename T> void Shuffle(std::vector<T>& values, Random& randomGenerator)
{
    const uint64 count = values.size();
    for(uint64 i = 0; i < count; ++i)
    {
        uint64 other = i + (randomGenerator.RandomUint() % (count - i));
        Swap(values[i], values[other]);
    }
}

template<typename T> void Shuffle(T* values, uint64 count, Random& randomGenerator)
{
    for(uint64 i = 0; i < count; ++i)
    {
        uint64 other = i + (randomGenerator.RandomUint() % (count - i));
        Swap(values[i], values[other]);
    }
}

// General math functions

// Linear interpolation
template<typename T> T Lerp(const T& x, const T& y, float s)
{
    return x + (y - x) * s;
}

template<typename T> T Min(T a, T b)
{
    return a < b ? a : b;
}

template<typename T> T Max(T a, T b)
{
    return a < b ? b : a;
}

// Clamps a value to the specified range
template<typename T> T Clamp(T val, T min, T max)
{
    Assert_(max >= min);

    if(val < min)
        val = min;
    else if(val > max)
        val = max;
    return val;
}

// Clamps a value to [0, 1]
template<typename T> T Saturate(T val)
{
    return Clamp<T>(val, T(0.0f), T(1.0f));
}

inline Float3 Saturate(Float3 val)
{
    Float3 result;
    result.x = Clamp<float>(val.x, 0.0f, 1.0f);
    result.y = Clamp<float>(val.y, 0.0f, 1.0f);
    result.z = Clamp<float>(val.z, 0.0f, 1.0f);
    return result;
}

// Rounds a float
inline float Round(float r)
{
    return (r > 0.0f) ? std::floorf(r + 0.5f) : std::ceilf(r - 0.5f);
}

// Returns a random float value between 0 and 1
inline float RandFloat()
{
    return rand() /  static_cast<float>(RAND_MAX);
}

// Returns x * x
template<typename T> T Square(T x)
{
    return x * x;
}

// Returns the fractional part of x
inline float Frac(float x)
{
    float intPart;
    return std::modf(x, &intPart);
}

// Returns the fractional part of x
inline Float2 Frac(Float2 x)
{
    return Float2(Frac(x.x), Frac(x.y));
}

// Smoothstep cubic interpolation
inline float Smoothstep(float start, float end, float x)
{
    x = Saturate((x - start) / (end - start));
    return x * x * (3.0f - 2.0f * x);
}

inline Float3 Pow(Float3 x, float y)
{
    return Float3(std::pow(x.x, y), std::pow(x.y, y), std::pow(x.z, y));
}

// linear -> sRGB conversion
inline Float3 LinearTosRGB(Float3 color)
{
    Float3 x = color * 12.92f;
    Float3 y = 1.055f * Pow(color, 1.0f / 2.4f) - 0.055f;

    Float3 clr = color;
    clr.x = color.x < 0.0031308f ? x.x : y.x;
    clr.y = color.y < 0.0031308f ? x.y : y.y;
    clr.z = color.z < 0.0031308f ? x.z : y.z;

    return clr;
}

inline float DegToRad(float deg)
{
    return deg * (1.0f / 180.0f) * 3.14159265359f;
}

inline float RadToDeg(float rad)
{
    return rad * (1.0f / 3.14159265359f) * 180.0f;
}

// sRGB -> linear conversion
inline Float3 SRGBToLinear(Float3 color)
{
    Float3 x = color / 12.92f;
    Float3 y = Pow((color + 0.055f) / 1.055f, 2.4f);

    Float3 clr = color;
    clr.x = color.x <= 0.04045f ? x.x : y.x;
    clr.y = color.y <= 0.04045f ? x.y : y.y;
    clr.z = color.z <= 0.04045f ? x.z : y.z;

    return clr;
}

inline float ComputeLuminance(Float3 color)
{
    return Float3::Dot(color, Float3(0.2126f, 0.7152f, 0.0722f));
}

// Convert from spherical coordinates to Cartesian coordinates(x, y, z)
// Theta represents how far away from the zenith (north pole/+Y) and phi represents how far
// away from the 'right' axis (+X).
inline void SphericalToCartesianXYZYUP(float r, float theta, float phi, Float3& xyz)
{
    xyz.x = r * std::cosf(phi) * std::sinf(theta);
    xyz.y = r * std::cosf(theta);
    xyz.z = r * std::sinf(theta) * std::sinf(phi);
}

// Constants
const float Pi = 3.141592654f;
const float Pi2 = 6.283185307f;
const float Pi_2 = 1.570796327f;
const float Pi_4 = 0.7853981635f;
const float InvPi = 0.318309886f;
const float InvPi2 = 0.159154943f;

// Max value that we can store in an fp16 buffer (actually a little less so that we have room for error, real max is 65504)
const float FP16Max = 65000.0f;

// Scale factor used for storing physical light units in fp16 floats (equal to 2^-10).
const float FP16Scale = 0.0009765625f;

const float FloatMax = std::numeric_limits<float>::max();
const float FloatInfinity = std::numeric_limits<float>::infinity();

}