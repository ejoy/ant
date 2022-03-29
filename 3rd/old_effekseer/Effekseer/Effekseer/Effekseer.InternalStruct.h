
#ifndef __EFFEKSEER_INTERNAL_STRUCT_H__
#define __EFFEKSEER_INTERNAL_STRUCT_H__

/**
	@file
	@brief	内部計算用構造体
	@note
	union等に使用するための構造体。<BR>

*/

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Color.h"
#include "Effekseer.Manager.h"
#include "Effekseer.Random.h"
#include "Effekseer.Vector2D.h"
#include "Effekseer.Vector3D.h"
#include "SIMD/Vec2f.h"
#include "SIMD/Vec3f.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

template <typename T>
void ReadData(T& dst, unsigned char*& pos)
{
	memcpy(&dst, pos, sizeof(T));
	pos += sizeof(T);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct random_float
{
	float max;
	float min;

	void reset()
	{
		memset(this, 0, sizeof(random_float));
	};

	float getValue(IRandObject& g) const
	{
		return g.GetRand(min, max);
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct random_int
{
	int max;
	int min;

	void reset()
	{
		memset(this, 0, sizeof(random_int));
	};

	float getValue(IRandObject& g) const
	{
		float r;
		r = g.GetRand((float)min, (float)max);
		return r;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct vector2d
{
	float x;
	float y;

	vector2d& operator*=(float rhs)
	{
		x *= rhs;
		y *= rhs;
		return *this;
	}
};

struct rectf
{
	float x;
	float y;
	float w;
	float h;

	void reset()
	{
		assert(sizeof(rectf) == sizeof(float) * 4);
		memset(this, 0, sizeof(rectf));
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct random_vector2d
{
	vector2d max;
	vector2d min;

	void reset()
	{
		memset(this, 0, sizeof(random_vector2d));
	};

	SIMD::Vec2f getValue(IRandObject& g) const
	{
		return {g.GetRand(min.x, max.x), g.GetRand(min.y, max.y)};
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct easing_float_without_random
{
	float easingA;
	float easingB;
	float easingC;

	void setValueToArg(float& o, const float start_, const float end_, float t) const
	{
		float df = end_ - start_;
		float d = easingA * t * t * t + easingB * t * t + easingC * t;
		o = start_ + d * df;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct easing_float
{
	random_float start;
	random_float end;
	float easingA;
	float easingB;
	float easingC;

	float getValue(const float start_, const float end_, float t) const
	{
		float df = end_ - start_;
		float d = easingA * t * t * t + easingB * t * t + easingC * t;
		return start_ + d * df;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct easing_vector2d
{
	random_vector2d start;
	random_vector2d end;
	float easingA;
	float easingB;
	float easingC;

	SIMD::Vec2f getValue(const SIMD::Vec2f& start_, const SIMD::Vec2f& end_, float t) const
	{
		SIMD::Vec2f size = end_ - start_;
		float d = easingA * t * t * t + easingB * t * t + easingC * t;
		return start_ + size * d;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct vector3d
{
	float x;
	float y;
	float z;

	vector3d& operator*=(float rhs)
	{
		x *= rhs;
		y *= rhs;
		z *= rhs;
		return *this;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct random_vector3d
{
	vector3d max;
	vector3d min;

	void reset()
	{
		memset(this, 0, sizeof(random_vector3d));
	};

	SIMD::Vec3f getValue(IRandObject& g) const
	{
		return {g.GetRand(min.x, max.x), g.GetRand(min.y, max.y), g.GetRand(min.z, max.z)};
	}

	SIMD::Vec3f getValue(const std::array<int32_t, 3>& channels, int32_t channelCount, IRandObject& g) const
	{
		assert(channelCount <= 3);
		std::array<float, 3> channelValues;

		for (int32_t i = 0; i < channelCount; i++)
		{
			channelValues[i] = g.GetRand();
		}

		auto x = channelValues[channels[0]] * (max.x - min.x) + min.x;
		auto y = channelValues[channels[1]] * (max.y - min.y) + min.y;
		auto z = channelValues[channels[2]] * (max.z - min.z) + min.z;

		return {x, y, z};
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct easing_vector3d
{
	random_vector3d start;
	random_vector3d end;
	float easingA;
	float easingB;
	float easingC;

	SIMD::Vec3f getValue(const SIMD::Vec3f& start_, const SIMD::Vec3f& end_, float t) const
	{
		SIMD::Vec3f size = end_ - start_;
		float d = easingA * t * t * t + easingB * t * t + easingC * t;
		return start_ + size * d;
	}
};

inline Color HSVToRGB(Color hsv)
{
	int H = hsv.R, S = hsv.G, V = hsv.B;
	int Hi, R = 0, G = 0, B = 0, p, q, t;
	float f, s;

	if (H >= 252)
		H = 252;
	Hi = (H / 42);
	f = H / 42.0f - Hi;
	Hi = Hi % 6;
	s = S / 255.0f;
	p = (int)((V * (1 - s)));
	q = (int)((V * (1 - f * s)));
	t = (int)((V * (1 - (1 - f) * s)));

	switch (Hi)
	{
	case 0:
		R = V;
		G = t;
		B = p;
		break;
	case 1:
		R = q;
		G = V;
		B = p;
		break;
	case 2:
		R = p;
		G = V;
		B = t;
		break;
	case 3:
		R = p;
		G = q;
		B = V;
		break;
	case 4:
		R = t;
		G = p;
		B = V;
		break;
	case 5:
		R = V;
		G = p;
		B = q;
		break;
	}
	Color result;
	result.R = static_cast<uint8_t>(R);
	result.G = static_cast<uint8_t>(G);
	result.B = static_cast<uint8_t>(B);
	result.A = hsv.A;
	return result;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct random_color
{
	ColorMode mode;
	Color max;
	Color min;

	void reset()
	{
		assert(sizeof(random_color) == 12);
		mode = COLOR_MODE_RGBA;
		max = {255, 255, 255, 255};
		min = {255, 255, 255, 255};
	};

	Color getValue(IRandObject& g) const
	{
		Color r = getDirectValue(g);
		if (mode == COLOR_MODE_HSVA)
		{
			r = HSVToRGB(r);
		}
		return r;
	}

	Color getDirectValue(IRandObject& g) const
	{
		Color r;
		r.R = (uint8_t)(g.GetRand(min.R, max.R));
		r.G = (uint8_t)(g.GetRand(min.G, max.G));
		r.B = (uint8_t)(g.GetRand(min.B, max.B));
		r.A = (uint8_t)(g.GetRand(min.A, max.A));
		return r;
	}

	void load(int version, unsigned char*& pos)
	{
		if (version >= 4)
		{
			uint8_t mode_ = 0;
			ReadData<uint8_t>(mode_, pos);
			mode = static_cast<ColorMode>(mode_);
			pos++; // reserved
		}
		else
		{
			mode = COLOR_MODE_RGBA;
		}
		ReadData<Color>(max, pos);
		ReadData<Color>(min, pos);
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct easing_color
{
	random_color start;
	random_color end;
	float easingA;
	float easingB;
	float easingC;

	void setValueToArg(Color& o, const Color& start_, const Color& end_, float t) const
	{
		assert(start.mode == end.mode);
		float d = easingA * t * t * t + easingB * t * t + easingC * t;
		o = Color::Lerp(start_, end_, d);
		if (start.mode == COLOR_MODE_HSVA)
		{
			o = HSVToRGB(o);
		}
	}

	Color getStartValue(IRandObject& g) const
	{
		return start.getDirectValue(g);
	}

	Color getEndValue(IRandObject& g) const
	{
		return end.getDirectValue(g);
	}

	void load(int version, unsigned char*& pos)
	{
		start.load(version, pos);
		end.load(version, pos);
		ReadData<float>(easingA, pos);
		ReadData<float>(easingB, pos);
		ReadData<float>(easingC, pos);
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_INTERNAL_STRUCT_H__