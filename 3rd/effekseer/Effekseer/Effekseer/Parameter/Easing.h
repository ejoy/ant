
#ifndef __EFFEKSEER_EASING_H__
#define __EFFEKSEER_EASING_H__

#include "../Effekseer.Base.Pre.h"
#include "../Effekseer.InternalStruct.h"
#include "../Utils/BinaryVersion.h"
#include "../Utils/Effekseer.BinaryReader.h"
#include "DynamicParameter.h"
#include "Effekseer.Parameters.h"

namespace Effekseer
{

enum class Easing3Type : int32_t
{
	StartEndSpeed = 0,
	Linear = 1,

	EaseInQuadratic = 10,
	EaseOutQuadratic = 11,
	EaseInOutQuadratic = 12,

	EaseInCubic = 20,
	EaseOutCubic = 21,
	EaseInOutCubic = 22,

	EaseInQuartic = 30,
	EaseOutQuartic = 31,
	EaseInOutQuartic = 32,

	EaseInQuintic = 40,
	EaseOutQuintic = 41,
	EaseInOutQuintic = 42,

	EaseInBack = 50,
	EaseOutBack = 51,
	EaseInOutBack = 52,

	EaseInBounce = 60,
	EaseOutBounce = 61,
	EaseInOutBounce = 62,
};

template <typename T>
struct easing_type_information
{
	using type = void;
	static constexpr uint8_t elemNum = 0;
};

template <>
struct easing_type_information<float>
{
	using type = random_float;
	static const uint8_t elemNum = 1;
};

template <>
struct easing_type_information<SIMD::Vec3f>
{
	using type = random_vector3d;
	static constexpr uint8_t elemNum = 3;
};

template <typename T>
struct InstanceEasing
{
	T start;
	T middle;
	T end;
	float Rate;
};

template <typename T>
struct ParameterEasing
{
protected:
	using InstanceEasingType = InstanceEasing<T>;
	using RandomValue = typename easing_type_information<T>::type;
	static constexpr uint8_t ElemNum = easing_type_information<T>::elemNum;

protected:
	float getEasingStartEndValue(float t) const
	{
		return params[0] * t * t * t + params[1] * t * t + params[2] * t;
	}

	float getEasingLinearValue(float t) const
	{
		return t;
	}

	float getEaseInQuadratic(float t) const
	{
		return t * t;
	}

	float getEaseOutQuadratic(float t) const
	{
		t = (1.0f - t);
		return 1.0f - t * t;
	}

	float getEaseInOutQuadratic(float t) const
	{
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return t * t * 0.5f;
		}
		else
		{
			t = (1.0f - t) * 2.0f;
			return 1.0f - t * t * 0.5f;
		}
	}

	float getEaseInCubic(float t) const
	{
		return t * t * t;
	}

	float getEaseOutCubic(float t) const
	{
		t = (1.0f - t);
		return 1.0f - t * t * t;
	}

	float getEaseInOutCubic(float t) const
	{
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return t * t * t * 0.5f;
		}
		else
		{
			t = (1.0f - t) * 2.0f;
			return 1.0f - t * t * t * 0.5f;
		}
	}

	float getEaseInQuartic(float t) const
	{
		return t * t * t * t;
	}

	float getEaseOutQuartic(float t) const
	{
		t = (1.0f - t);
		return 1.0f - t * t * t * t;
	}

	float getEaseInOutQuartic(float t) const
	{
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return t * t * t * t * 0.5f;
		}
		else
		{
			t = (1.0f - t) * 2.0f;
			return 1.0f - t * t * t * t * 0.5f;
		}
	}

	float getEaseInQuintic(float t) const
	{
		return t * t * t * t * t;
	}

	float getEaseOutQuintic(float t) const
	{
		t = (1.0f - t);
		return 1.0f - t * t * t * t * t;
	}

	float getEaseInOutQuintic(float t) const
	{
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return t * t * t * t * t * 0.5f;
		}
		else
		{
			t = (1.0f - t) * 2.0f;
			return 1.0f - t * t * t * t * t * 0.5f;
		}
	}

	float getEaseInBack(float t) const
	{
		float c = 1.8f;
		return (c + 1.0f) * t * t * t - c * t * t;
	}

	float getEaseOutBack(float t) const
	{
		t = (1.0f - t);
		float c = 1.8f;
		return 1.0f - ((c + 1.0f) * t * t * t - c * t * t);
	}

	float getEaseInOutBack(float t) const
	{
		float c = 1.8f;
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return ((c + 1.0f) * t * t * t - c * t * t) * 0.5f;
		}
		else
		{
			t = (1.0f - t) * 2.0f;
			return 1.0f - ((c + 1.0f) * t * t * t - c * t * t) * 0.5f;
		}
	}

	float getEaseOutBounce(float t) const
	{
		if (t < 4.0f / 11.0f)
		{
			t = t / 4.0f * 11.0f;
			return t * t;
		}
		else if (t < 8.0f / 11.0f)
		{
			t = t - (4.0f / 11.0f) - (2.0f / 11.0f);
			return 1.0f + (t * t - (2.0f / 11.0f) * (2.0f / 11.0f)) * 8.0f;
		}
		else if (t < 10.0f / 11.0f)
		{
			t = t - (8.0f / 11.0f) - (1.0f / 11.0f);
			return 1.0f + (t * t - (1.0f / 11.0f) * (1.0f / 11.0f)) * 8.0f;
		}
		else
		{
			t = t - (10.0f / 11.0f) - (0.5f / 11.0f);
			return 1.0f + (t * t - (0.5f / 11.0f) * (0.5f / 11.0f)) * 8.0f;
		}
	}

	float getEaseInBounce(float t) const
	{
		return 1.0f - getEaseOutBounce(1.0f - t);
	}

	float getEaseInOutBounce(float t) const
	{
		if (t <= 0.5f)
		{
			t *= 2.0f;
			return getEaseInBounce(t) * 0.5f;
		}
		else
		{
			t = (t - 0.5f) * 2.0f;
			return getEaseOutBounce(t) * 0.5f + 0.5f;
		}
	}

	float getEaseValue(Easing3Type type, float time) const
	{
		auto t = 0.0f;
		if (type == Easing3Type::StartEndSpeed)
		{
			t = getEasingStartEndValue(time);
		}
		else if (type == Easing3Type::Linear)
		{
			t = getEasingLinearValue(time);
		}

		else if (type == Easing3Type::EaseInQuadratic)
		{
			t = getEaseInQuadratic(time);
		}
		else if (type == Easing3Type::EaseOutQuadratic)
		{
			t = getEaseOutQuadratic(time);
		}
		else if (type == Easing3Type::EaseInOutQuadratic)
		{
			t = getEaseInOutQuadratic(time);
		}

		else if (type == Easing3Type::EaseInCubic)
		{
			t = getEaseInCubic(time);
		}
		else if (type == Easing3Type::EaseOutCubic)
		{
			t = getEaseOutCubic(time);
		}
		else if (type == Easing3Type::EaseInOutCubic)
		{
			t = getEaseInOutCubic(time);
		}

		else if (type == Easing3Type::EaseInQuartic)
		{
			t = getEaseInQuartic(time);
		}
		else if (type == Easing3Type::EaseOutQuartic)
		{
			t = getEaseOutQuartic(time);
		}
		else if (type == Easing3Type::EaseInOutQuartic)
		{
			t = getEaseInOutQuartic(time);
		}

		else if (type == Easing3Type::EaseInQuintic)
		{
			t = getEaseInQuintic(time);
		}
		else if (type == Easing3Type::EaseOutQuintic)
		{
			t = getEaseOutQuintic(time);
		}
		else if (type == Easing3Type::EaseInOutQuintic)
		{
			t = getEaseInOutQuintic(time);
		}

		else if (type == Easing3Type::EaseInBack)
		{
			t = getEaseInBack(time);
		}
		else if (type == Easing3Type::EaseOutBack)
		{
			t = getEaseOutBack(time);
		}
		else if (type == Easing3Type::EaseInOutBack)
		{
			t = getEaseInOutBack(time);
		}

		else if (type == Easing3Type::EaseInBounce)
		{
			t = getEaseInBounce(time);
		}
		else if (type == Easing3Type::EaseOutBounce)
		{
			t = getEaseOutBounce(time);
		}
		else if (type == Easing3Type::EaseInOutBounce)
		{
			t = getEaseInOutBounce(time);
		}
		else
		{
			assert(0);
		}

		return t;
	}

	T get2Point(const InstanceEasingType& v, float t) const
	{
		T size = v.end - v.start;
		return v.start + size * t;
	}

	//! calculate with spline
	T get3Point(const InstanceEasingType& v, float t) const
	{
		if (t > v.Rate)
		{
			t = 1.0f + (t - v.Rate) / (1.0f - v.Rate);
		}
		else
		{
			t = t / v.Rate;
		}

		t = Clamp(t, 2.0f, 0.0f);

		std::array<T, 3> a = {v.start, v.middle, v.end};
		std::array<T, 3> b;
		std::array<T, 3> c;
		std::array<T, 3> d;
		std::array<T, 3> w;
		std::array<bool, 3> isSame;

		isSame[0] = a[1] == a[0];
		isSame[1] = a[2] == a[1];

		c[0] = c[2] = T(0.0f);

		for (size_t i = 1; i < a.size() - 1; i++)
		{
			c[i] = (a[i - 1] + a[i] * (-2.0f) + a[i + 1]) * 3.0f;
		}

		w[0] = T(0.0f);
		for (size_t i = 1; i < a.size() - 1; i++)
		{
			auto tmp = T(4.0f) - w[i - 1];
			c[i] = (c[i] - c[i - 1]) / tmp;
			w[i] = T(1.0f) / tmp;
		}

		for (size_t i = (a.size() - 1) - 1; i > 0; i--)
		{
			c[i] = c[i] - c[i + 1] * w[i];
		}

		b[2] = d[2] = T(0.0f);
		for (size_t i = 0; i < a.size() - 1; i++)
		{
			d[i] = (c[i + 1] - c[i]) / 3.0f;
			b[i] = a[i + 1] - a[i] - c[i] - d[i];
		}

		int32_t j = (int32_t)floorf(t);

		if (j < 0)
		{
			j = 0;
		}

		if (j >= (int32_t)a.size())
		{
			j = (int32_t)a.size() - 1;
		}

		auto dt = t - j;

		if (j < (int32_t)isSame.size() && isSame[j])
			return a[j];

		return a[j] + (b[j] + (c[j] + d[j] * dt) * dt) * dt;
	}

protected:
	int32_t minDynamicParameterVersion_ = 14;
	int32_t minAppendParameterVersion_ = Version16Alpha1;

public:
	RefMinMax RefEqS;
	RefMinMax RefEqE;
	RefMinMax RefEqM;

	RandomValue start;
	RandomValue end;
	RandomValue middle;

	Easing3Type type_ = Easing3Type::StartEndSpeed;
	std::array<float, 4> params;

	int32_t channelCount = 0;
	std::array<int, ElemNum> channelIDs;

	bool isMiddleEnabled = false;

	bool isIndividualEnabled = false;
	std::array<Easing3Type, ElemNum> types;

	void Load(uint8_t* pos, int32_t size, int32_t version)
	{
		BinaryReader<true> reader(pos, size);

		if (version >= minDynamicParameterVersion_)
		{
			reader.Read<RefMinMax>(RefEqS);
			reader.Read<RefMinMax>(RefEqE);
		}

		reader.Read<RandomValue>(start);
		reader.Read<RandomValue>(end);

		// middle parameter
		if (version >= minAppendParameterVersion_)
		{
			int32_t isMiddleEnabledNum = 0;
			reader.Read<int32_t>(isMiddleEnabledNum);
			isMiddleEnabled = isMiddleEnabledNum > 0;

			if (isMiddleEnabled)
			{
				reader.Read<RefMinMax>(RefEqM);
				reader.Read<RandomValue>(middle);
			}
		}

		if (version >= minAppendParameterVersion_)
		{
			reader.Read<Easing3Type>(type_);

			if (type_ == Easing3Type::StartEndSpeed)
			{
				reader.Read<float>(params[0]);
				reader.Read<float>(params[1]);
				reader.Read<float>(params[2]);
			}
		}
		else
		{
			reader.Read<float>(params[0]);
			reader.Read<float>(params[1]);
			reader.Read<float>(params[2]);
		}

		if (version >= minAppendParameterVersion_)
		{
			int channel = 0;
			reader.Read<int>(channel);

			for (int32_t i = 0; i < ElemNum; i++)
			{
				channelIDs[i] = channel & 0xff;
				;
				channel = (channel >> 8);
			}

			for (int i = 0; i < ElemNum; i++)
			{
				channelCount = std::max(channelCount, channelIDs[i]);
			}
			channelCount++;
		}
		else
		{
			channelCount = ElemNum;
			for (int32_t i = 0; i < ElemNum; i++)
			{
				channelIDs[i] = i;
			}
		}

		if (version >= minAppendParameterVersion_)
		{
			int isIndividual = 0;
			reader.Read<int>(isIndividual);
			isIndividualEnabled = isIndividual > 0;

			if (isIndividualEnabled)
			{
				for (int32_t i = 0; i < ElemNum; i++)
				{
					reader.Read<Easing3Type>(types[i]);
				}
			}
		}
	}

	virtual T GetValue(const InstanceEasingType& instance, float time) const = 0;
};

class ParameterEasingFloat : public ParameterEasing<float>
{
public:
	ParameterEasingFloat(int minDynamicParameterVersion, int32_t minAppendParameterVersion)
	{
		minDynamicParameterVersion_ = minDynamicParameterVersion;
		minAppendParameterVersion_ = minAppendParameterVersion;
	}

	virtual float GetValue(const InstanceEasingType& instance, float time) const override;
	void Init(InstanceEasingType& instance, Effect* e, InstanceGlobal* instg, Instance* parent, IRandObject* rand);
};

class ParameterEasingSIMDVec3 : public ParameterEasing<SIMD::Vec3f>
{
public:
	virtual SIMD::Vec3f GetValue(const InstanceEasingType& instance, float time) const override;
	void Init(InstanceEasingType& instance, Effect* e, InstanceGlobal* instg, Instance* parent, IRandObject* rand, const std::array<float, 3>& scale, const std::array<float, 3>& scaleInv);
};

} // namespace Effekseer

#endif // __EFFEKSEER_PARAMETERS_H__