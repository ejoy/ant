
#ifndef __EFFEKSEER_FCURVES_H__
#define __EFFEKSEER_FCURVES_H__

#include "Effekseer.Base.h"
#include "Effekseer.InternalStruct.h"
#include "Effekseer.Random.h"
#include "SIMD/Vec2f.h"
#include "SIMD/Vec3f.h"

namespace Effekseer
{

enum class FCurveTimelineType : int32_t
{
	Time = 0,
	Percent = 1,
};

class FCurve
{
private:
	enum class FCurveEdge : int32_t
	{
		Constant = 0,
		Loop = 1,
		LoopInversely = 2,
	};

private:
	int32_t offset_ = 0;
	int32_t len_ = 0;
	int32_t freq_ = 0;
	FCurveEdge start_ = FCurveEdge::Constant;
	FCurveEdge end_ = FCurveEdge::Constant;
	std::vector<float> keys_;

	float defaultValue_ = 0;
	float offsetMax_ = 0;
	float offsetMin_ = 0;

public:
	FCurve(float defaultValue);
	int32_t Load(const void* data, int32_t version);

	float GetValue(float living, float life, FCurveTimelineType type) const;

	float GetOffset(IRandObject& g) const;

	void SetDefaultValue(float value)
	{
		defaultValue_ = value;
	}

	void ChangeCoordinate();

	void Maginify(float value);
};

class FCurveScalar
{
public:
	FCurveTimelineType Timeline = FCurveTimelineType::Time;
	FCurve S = FCurve(0);

	int32_t Load(const void* data, int32_t version);

	float GetValues(float living, float life) const;
	float GetOffsets(IRandObject& g) const;
};

class FCurveVector2D
{
public:
	FCurveTimelineType Timeline = FCurveTimelineType::Time;
	FCurve X = FCurve(0);
	FCurve Y = FCurve(0);

	int32_t Load(const void* data, int32_t version);

	SIMD::Vec2f GetValues(float living, float life) const;
	SIMD::Vec2f GetOffsets(IRandObject& g) const;
};

class FCurveVector3D
{
public:
	FCurveTimelineType Timeline = FCurveTimelineType::Time;
	FCurve X = FCurve(0);
	FCurve Y = FCurve(0);
	FCurve Z = FCurve(0);

	int32_t Load(const void* data, int32_t version);

	SIMD::Vec3f GetValues(float living, float life) const;
	SIMD::Vec3f GetOffsets(IRandObject& g) const;
};

class FCurveVectorColor
{
public:
	FCurveTimelineType Timeline = FCurveTimelineType::Time;
	FCurve R = FCurve(255);
	FCurve G = FCurve(255);
	FCurve B = FCurve(255);
	FCurve A = FCurve(255);

	int32_t Load(const void* data, int32_t version);

	std::array<float, 4> GetValues(float living, float life) const;
	std::array<float, 4> GetOffsets(IRandObject& g) const;
};

} // namespace Effekseer

#endif // __EFFEKSEER_FCURVES_H__
