#pragma once

#include <array>
#include <memory>
#include <random>

#include "../Effekseer.Vector3D.h"
#include "../Noise/CurlNoise.h"
#include "../Noise/PerlinNoise.h"
#include "../SIMD/Mat44f.h"
#include "../SIMD/Vec3f.h"
#include "../Utils/BinaryVersion.h"

namespace Effekseer
{

struct ForceFieldCommonParameter
{
	SIMD::Vec3f Position;
	SIMD::Vec3f PreviousVelocity;
	SIMD::Vec3f PreviousSumVelocity;
	SIMD::Vec3f FieldCenter;
	SIMD::Vec3f TargetPosition;
	SIMD::Mat44f FieldRotation;
	bool IsFieldRotated = false;
	float DeltaFrame;
};

struct ForceFieldFalloffCommonParameter
{
	float Power = 0.0f;
	float MinDistance = 0.0f;
	float MaxDistance = 0.0f;
};

struct ForceFieldFalloffSphereParameter
{
};

struct ForceFieldFalloffTubeParameter
{
	float RadiusPower = 0.0f;
	float MinRadius = 0.0f;
	float MaxRadius = 0.0f;
};

struct ForceFieldFalloffConeParameter
{
	float AnglePower = 0.0f;
	float MinAngle = 0.0f;
	float MaxAngle = 0.0f;
};

struct ForceFieldForceParameter
{
	float Power;
	bool Gravitation;
};

struct ForceFieldWindParameter
{
	float Power;
};

enum class ForceFieldVortexType : int32_t
{
	ConstantAngle = 0,
	ConstantSpeed = 1,
};

struct ForceFieldVortexParameter
{
	ForceFieldVortexType Type = ForceFieldVortexType::ConstantAngle;
	float Power;
};

enum class ForceFieldTurbulenceType : int32_t
{
	Simple = 0,
	Complicated = 1,
};

struct ForceFieldTurbulenceParameter
{
	float Power;

	std::unique_ptr<CurlNoise> Noise;
	std::unique_ptr<LightCurlNoise> LightNoise;

	ForceFieldTurbulenceParameter(ForceFieldTurbulenceType type, int32_t seed, float scale, float strength, int octave);
};

struct ForceFieldDragParameter
{
	float Power;
};

struct ForceFieldGravityParameter
{
	SIMD::Vec3f Gravity;
};

struct ForceFieldAttractiveForceParameter
{
	float Force;
	float Control;
	float MinRange;
	float MaxRange;
};

class ForceFieldFalloff
{
public:
	//! Sphare
	float GetPower(float power,
				   const ForceFieldCommonParameter& ffc,
				   const ForceFieldFalloffCommonParameter& fffc,
				   const ForceFieldFalloffSphereParameter& fffs)
	{
		auto localPos = ffc.Position - ffc.FieldCenter;
		auto distance = localPos.GetLength();
		if (distance > fffc.MaxDistance)
		{
			return 0.0f;
		}

		if (distance < fffc.MinDistance)
		{
			return 0.0f;
		}

		const auto deg = powf(distance - fffc.MinDistance + 1.0f, fffc.Power);

		if (deg == 0.0f)
		{
			return power;
		}

		return power / deg;
	}

	//! Tube
	float GetPower(float power,
				   const ForceFieldCommonParameter& ffc,
				   const ForceFieldFalloffCommonParameter& fffc,
				   const ForceFieldFalloffTubeParameter& ffft)
	{
		// Sphere
		auto localPos = ffc.Position - ffc.FieldCenter;
		auto distance = localPos.GetLength();
		if (distance > fffc.MaxDistance)
		{
			return 0.0f;
		}

		if (distance <= fffc.MinDistance)
		{
			return 0.0f;
		}

		// Tube
		auto tubePos = localPos;
		tubePos.SetY(0);

		auto tubeRadius = tubePos.GetLength();

		if (tubeRadius > ffft.MaxRadius)
		{
			return 0.0f;
		}

		if (tubeRadius < ffft.MinRadius)
		{
			return 0.0f;
		}

		const auto deg = powf(distance + 1.0f, fffc.Power) * powf(tubeRadius - ffft.MinRadius + 1.0f, ffft.RadiusPower);

		if (deg == 0.0f)
		{
			return power;
		}

		return power / deg;
	}

	float GetPower(float power,
				   const ForceFieldCommonParameter& ffc,
				   const ForceFieldFalloffCommonParameter& fffc,
				   const ForceFieldFalloffConeParameter& ffft)
	{
		auto localPos = ffc.Position - ffc.FieldCenter;
		auto distance = localPos.GetLength();
		if (distance > fffc.MaxDistance)
		{
			return 0.0f;
		}

		if (distance <= fffc.MinDistance)
		{
			return 0.0f;
		}

		auto tubePos = localPos;
		tubePos.SetY(0);

		auto tubeRadius = tubePos.GetLength();

		auto angle = fabs(EFK_PI / 2.0f - atan2(localPos.GetY(), tubeRadius));

		if (angle > ffft.MaxAngle)
		{
			return 0.0f;
		}

		if (angle < ffft.MinAngle)
		{
			return 0.0f;
		}

		const auto e = 0.000001f;

		const auto deg = powf(distance + 1.0f, fffc.Power) * powf((angle - ffft.MinAngle) / (ffft.MaxAngle - ffft.MinAngle + e) + 1.0f, ffft.AnglePower);

		return power / deg;
	}
};

class ForceField
{
public:
	/**
		@brief	Force
	*/
	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldForceParameter& ffp)
	{
		float eps = 0.0000001f;
		auto localPos = ffc.Position - ffc.FieldCenter;
		auto distance = localPos.GetLength() + eps;
		auto dir = localPos / distance;

		if (ffp.Gravitation)
		{
			return dir * ffp.Power / distance;
		}

		return dir * ffp.Power * ffc.DeltaFrame;
	}

	/**
		@brief	Wind
	*/
	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldWindParameter& ffp)
	{
		auto dir = SIMD::Vec3f(0, 1, 0);
		return dir * ffp.Power * ffc.DeltaFrame;
	}

	/**
		@brief	Vortex
	*/
	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldVortexParameter& ffp)
	{
		float eps = 0.0000001f;
		auto localPos = ffc.Position - ffc.FieldCenter;
		localPos.SetY(0.0f);
		auto distance = localPos.GetLength();

		if (distance < eps)
			return SIMD::Vec3f(0.0f, 0.0f, 0.0f);
		if (abs(ffp.Power) < eps)
			return SIMD::Vec3f(0.0f, 0.0f, 0.0f);

		localPos /= distance;

		auto axis = SIMD::Vec3f(0, 1, 0);
		SIMD::Vec3f front = SIMD::Vec3f::Cross(axis, localPos);

		auto direction = 1.0f;
		if (ffp.Power < 0)
			direction = -1.0f;

		auto power = ffp.Power;

		if (ffp.Type == ForceFieldVortexType::ConstantAngle)
		{
			power *= distance;
		}

		auto xlen = power / distance * (power / 2.0f);
		auto flen = sqrt(power * power - xlen * xlen);
		return ((front * flen - localPos * xlen) * direction - ffc.PreviousVelocity) * ffc.DeltaFrame;
	}

	/**
		@brief	Turbulence
	*/
	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldTurbulenceParameter& ffp)
	{
		const float LightNoisePowerScale = 4.0f;

		auto localPos = ffc.Position - ffc.FieldCenter;
		SIMD::Vec3f vel;

		if (ffp.Noise != nullptr)
		{
			vel = ffp.Noise->Get(localPos) * ffp.Power;
		}
		else if (ffp.LightNoise != nullptr)
		{
			vel = ffp.LightNoise->Get(localPos) * ffp.Power * LightNoisePowerScale;
		}

		auto acc = vel - ffc.PreviousVelocity;
		return acc;
	}

	/**
		@brief	Drag
	*/
	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldDragParameter& ffp)
	{
		return -ffc.PreviousSumVelocity * ffp.Power * ffc.DeltaFrame;
	}

	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldGravityParameter& ffp)
	{
		return ffp.Gravity * ffc.DeltaFrame;
	}

	SIMD::Vec3f GetAcceleration(const ForceFieldCommonParameter& ffc, const ForceFieldAttractiveForceParameter& ffp)
	{
		const SIMD::Vec3f targetDifference = ffc.TargetPosition - ffc.Position;
		const float targetDistance = targetDifference.GetLength();

		if (targetDistance > 0.0f)
		{
			const SIMD::Vec3f targetDirection = targetDifference / targetDistance;
			float force = ffp.Force;

			if (ffp.MinRange > 0.0f || ffp.MaxRange > 0.0f)
			{
				if (targetDistance >= ffp.MaxRange)
				{
					force = 0.0f;
				}
				else if (targetDistance > ffp.MinRange)
				{
					force *= 1.0f - (targetDistance - ffp.MinRange) / (ffp.MaxRange - ffp.MinRange);
				}
			}

			if (ffc.DeltaFrame > 0)
			{
				float eps = 0.0001f;
				auto ret = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
				auto vel = ffc.PreviousVelocity;
				vel += targetDirection * force * ffc.DeltaFrame;
				float currentVelocity = vel.GetLength() + eps;
				SIMD::Vec3f currentDirection = vel / currentVelocity;

				vel = (targetDirection * ffp.Control + currentDirection * (1.0f - ffp.Control)) * currentVelocity;
				return vel - ffc.PreviousVelocity;
			}
		}

		return SIMD::Vec3f(0.0f, 0.0f, 0.0f);
	}
};

enum class LocalForceFieldFalloffType : int32_t
{
	None = 0,
	Sphere = 1,
	Tube = 2,
	Cone = 3,
};

enum class LocalForceFieldType : int32_t
{
	None = 0,
	Force = 2,
	Wind = 3,
	Vortex = 4,
	Turbulence = 1,
	Drag = 7,
	Gravity = 8,
	AttractiveForce = 9,
};

struct LocalForceFieldElementParameter
{
	Vector3D Position;
	SIMD::Mat44f Rotation;
	SIMD::Mat44f InvRotation;
	bool IsRotated = false;
	bool IsGlobal = false;

	std::unique_ptr<ForceFieldForceParameter> Force;
	std::unique_ptr<ForceFieldWindParameter> Wind;
	std::unique_ptr<ForceFieldVortexParameter> Vortex;
	std::unique_ptr<ForceFieldTurbulenceParameter> Turbulence;
	std::unique_ptr<ForceFieldDragParameter> Drag;
	std::unique_ptr<ForceFieldGravityParameter> Gravity;
	std::unique_ptr<ForceFieldAttractiveForceParameter> AttractiveForce;

	std::unique_ptr<ForceFieldFalloffCommonParameter> FalloffCommon;
	std::unique_ptr<ForceFieldFalloffSphereParameter> FalloffSphere;
	std::unique_ptr<ForceFieldFalloffTubeParameter> FalloffTube;
	std::unique_ptr<ForceFieldFalloffConeParameter> FalloffCone;

	bool HasValue = false;

	bool Load(uint8_t*& pos, int32_t version);
};

struct LocalForceFieldParameter
{
	std::array<LocalForceFieldElementParameter, LocalFieldSlotMax> LocalForceFields;

	bool HasValue = false;

	bool IsGlobalEnabled = false;

	bool Load(uint8_t*& pos, int32_t version);

	void MaintainGravityCompatibility(const SIMD::Vec3f& gravity);

	void MaintainAttractiveForceCompatibility(const float force, const float control, const float minRange, const float maxRange);
};

struct LocalForceFieldInstance
{
	std::array<SIMD::Vec3f, LocalFieldSlotMax> Velocities;

	SIMD::Vec3f ExternalVelocity;
	SIMD::Vec3f VelocitySum;
	SIMD::Vec3f ModifyLocation;

	SIMD::Vec3f GlobalVelocitySum;
	SIMD::Vec3f GlobalModifyLocation;

	void Update(const LocalForceFieldParameter& parameter, const SIMD::Vec3f& location, float magnification, float deltaFrame, CoordinateSystem coordinateSystem);

	void UpdateGlobal(const LocalForceFieldParameter& parameter, const SIMD::Vec3f& location, float magnification, const SIMD::Vec3f& targetPosition, float deltaTime, CoordinateSystem coordinateSystem);

	void Reset();
};

} // namespace Effekseer
