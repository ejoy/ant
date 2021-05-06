#include "ForceFields.h"
#include "../Effekseer.Matrix44.h"
#include "../SIMD/Utils.h"
#include "../Utils/Effekseer.BinaryReader.h"

namespace Effekseer
{

ForceFieldTurbulenceParameter::ForceFieldTurbulenceParameter(ForceFieldTurbulenceType type, int32_t seed, float scale, float strength, int octave)
{
	if (type == ForceFieldTurbulenceType::Simple)
	{
		LightNoise = std::make_unique<LightCurlNoise>(seed, scale, octave);
	}
	else if (type == ForceFieldTurbulenceType::Complicated)
	{
		Noise = std::make_unique<CurlNoise>(seed, scale, octave);
	}
	Power = strength;
}

bool LocalForceFieldElementParameter::Load(uint8_t*& pos, int32_t version)
{
	auto br = BinaryReader<false>(pos, std::numeric_limits<int>::max());

	LocalForceFieldType type{};
	br.Read(type);

	HasValue = true;
	float power = 1.0f;

	if (version >= 1600)
	{
		br.Read(power);

		br.Read(Position.X);
		br.Read(Position.Y);
		br.Read(Position.Z);

		Vector3D rotation;
		br.Read(rotation.X);
		br.Read(rotation.Y);
		br.Read(rotation.Z);

		IsRotated = rotation.X != 0.0f || rotation.Y != 0.0f || rotation.Z != 0.0f;

		if (IsRotated)
		{
			Rotation = SIMD::Mat44f::RotationZXY(rotation.Z, rotation.X, rotation.Y);
			Matrix44 invMat;
			InvRotation = SIMD::Mat44f(Matrix44::Inverse(invMat, ToStruct(Rotation)));
		}
	}

	if (type == LocalForceFieldType::Force)
	{
		int gravitation = 0;
		br.Read(gravitation);

		// convert it by frames
		power /= 60.0f;

		auto ff = new ForceFieldForceParameter();
		ff->Power = power;
		ff->Gravitation = gravitation > 0;
		Force = std::unique_ptr<ForceFieldForceParameter>(ff);
	}
	else if (type == LocalForceFieldType::Wind)
	{
		// convert it by frames
		power /= 60.0f;

		auto ff = new ForceFieldWindParameter();
		ff->Power = power;
		Wind = std::unique_ptr<ForceFieldWindParameter>(ff);
	}
	else if (type == LocalForceFieldType::Vortex)
	{
		if (version < Version16Alpha2)
		{
			power /= 5.0f;
		}

		// convert it by frames
		power /= 12.0f;

		ForceFieldVortexType ftype{};

		if (version < Version16Alpha2)
		{
			ftype = ForceFieldVortexType::ConstantSpeed;
		}
		else
		{
			br.Read(ftype);
		}

		auto ff = new ForceFieldVortexParameter();
		ff->Power = power;
		ff->Type = ftype;
		Vortex = std::unique_ptr<ForceFieldVortexParameter>(ff);
	}
	else if (type == LocalForceFieldType::Turbulence)
	{
		ForceFieldTurbulenceType ftype{};
		int32_t seed{};
		float scale{};
		float strength{};
		int octave{};

		if (version < Version16Alpha2)
		{
			ftype = ForceFieldTurbulenceType::Complicated;
		}
		else
		{
			br.Read(ftype);
		}

		br.Read(seed);
		br.Read(scale);

		if (version < Version16Alpha2)
		{
			br.Read(strength);
			strength *= 10.0f;
		}
		else
		{
			strength = power;
		}

		br.Read(octave);

		scale = 1.0f / scale;

		strength /= 10.0f;

		Turbulence = std::unique_ptr<ForceFieldTurbulenceParameter>(new ForceFieldTurbulenceParameter(ftype, seed, scale, strength, octave));
	}
	else if (type == LocalForceFieldType::Drag)
	{
		// convert it by frames
		power /= 60.0f;

		auto ff = new ForceFieldDragParameter();
		ff->Power = power;
		Drag = std::unique_ptr<ForceFieldDragParameter>(ff);
	}
	else if (type == LocalForceFieldType::Gravity)
	{
		std::array<float, 3> values;
		br.Read(values);
		SIMD::Vec3f gravity{values};
		Gravity = std::make_unique<ForceFieldGravityParameter>();
		Gravity->Gravity = gravity;
		IsGlobal = true;
	}
	else if (type == LocalForceFieldType::AttractiveForce)
	{
		AttractiveForce = std::make_unique<ForceFieldAttractiveForceParameter>();
		AttractiveForce->Force = power;
		br.Read(AttractiveForce->Control);
		br.Read(AttractiveForce->MinRange);
		br.Read(AttractiveForce->MaxRange);
		IsGlobal = true;
	}
	else
	{
		HasValue = false;
	}

	if (version >= 1600)
	{
		LocalForceFieldFalloffType ffType{};
		br.Read(ffType);

		if (ffType != LocalForceFieldFalloffType::None)
		{
			FalloffCommon = std::make_unique<ForceFieldFalloffCommonParameter>();
			br.Read(FalloffCommon->Power);
			br.Read(FalloffCommon->MaxDistance);
			br.Read(FalloffCommon->MinDistance);
		}

		if (ffType == LocalForceFieldFalloffType::None)
		{
		}
		else if (ffType == LocalForceFieldFalloffType::Sphere)
		{
			FalloffSphere = std::make_unique<ForceFieldFalloffSphereParameter>();
		}
		else if (ffType == LocalForceFieldFalloffType::Tube)
		{
			FalloffTube = std::make_unique<ForceFieldFalloffTubeParameter>();
			br.Read(FalloffTube->RadiusPower);
			br.Read(FalloffTube->MaxRadius);
			br.Read(FalloffTube->MinRadius);
		}
		else if (ffType == LocalForceFieldFalloffType::Cone)
		{
			FalloffCone = std::make_unique<ForceFieldFalloffConeParameter>();
			br.Read(FalloffCone->AnglePower);
			br.Read(FalloffCone->MaxAngle);
			br.Read(FalloffCone->MinAngle);
		}
		else
		{
			assert(0);
		}
	}
	else
	{
		IsRotated = false;
	}

	pos += br.GetOffset();

	return true;
}

bool LocalForceFieldParameter::Load(uint8_t*& pos, int32_t version)
{
	int32_t count = 0;
	memcpy(&count, pos, sizeof(int));
	pos += sizeof(int);

	for (int32_t i = 0; i < count; i++)
	{
		if (!LocalForceFields[i].Load(pos, version))
		{
			return false;
		}
	}

	for (auto& ff : LocalForceFields)
	{
		if (ff.HasValue)
		{
			HasValue = true;

			if (ff.Gravity != nullptr || ff.AttractiveForce != nullptr)
			{
				IsGlobalEnabled = true;
			}
		}
	}

	return true;
}

void LocalForceFieldParameter::MaintainGravityCompatibility(const SIMD::Vec3f& gravity)
{
	HasValue = true;
	IsGlobalEnabled = true;
	LocalForceFields[3].Gravity = std::make_unique<ForceFieldGravityParameter>();
	LocalForceFields[3].HasValue = true;
	LocalForceFields[3].Gravity->Gravity = gravity;
	LocalForceFields[3].IsGlobal = true;
}

void LocalForceFieldParameter::MaintainAttractiveForceCompatibility(const float force, const float control, const float minRange, const float maxRange)
{
	HasValue = true;
	IsGlobalEnabled = true;
	LocalForceFields[3].AttractiveForce = std::make_unique<ForceFieldAttractiveForceParameter>();
	LocalForceFields[3].HasValue = true;
	LocalForceFields[3].AttractiveForce->Force = force;
	LocalForceFields[3].AttractiveForce->Control = control;
	LocalForceFields[3].AttractiveForce->MinRange = minRange;
	LocalForceFields[3].AttractiveForce->MaxRange = maxRange;
	LocalForceFields[3].IsGlobal = true;
}

void LocalForceFieldInstance::Update(const LocalForceFieldParameter& parameter, const SIMD::Vec3f& location, float magnification, float deltaFrame, CoordinateSystem coordinateSystem)
{
	for (size_t i = 0; i < parameter.LocalForceFields.size(); i++)
	{
		auto& field = parameter.LocalForceFields[i];
		if (!field.HasValue)
		{
			continue;
		}

		if (parameter.LocalForceFields[i].IsGlobal)
			continue;

		ForceFieldCommonParameter ffcp;
		ffcp.FieldCenter = parameter.LocalForceFields[i].Position;
		ffcp.Position = location / magnification;
		ffcp.PreviousSumVelocity = (VelocitySum + ExternalVelocity / deltaFrame) / magnification;
		ffcp.PreviousVelocity = Velocities[i] / magnification;
		ffcp.DeltaFrame = deltaFrame;
		ffcp.IsFieldRotated = field.IsRotated;

		if (coordinateSystem == CoordinateSystem::LH)
		{
			ffcp.Position.SetZ(-ffcp.Position.GetZ());
			ffcp.PreviousVelocity.SetZ(-ffcp.PreviousVelocity.GetZ());
			ffcp.PreviousSumVelocity.SetZ(-ffcp.PreviousSumVelocity.GetZ());
		}

		if (field.IsRotated)
		{
			ffcp.PreviousSumVelocity = SIMD::Vec3f::Transform(ffcp.PreviousSumVelocity, field.InvRotation);
			ffcp.PreviousVelocity = SIMD::Vec3f::Transform(ffcp.PreviousVelocity, field.InvRotation);
			ffcp.Position = SIMD::Vec3f::Transform(ffcp.Position, field.InvRotation);
		}

		ForceField ff;

		SIMD::Vec3f acc = SIMD::Vec3f(0, 0, 0);
		if (field.Force != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Force) * magnification;
		}

		if (field.Wind != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Wind) * magnification;
		}

		if (field.Vortex != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Vortex) * magnification;
		}

		if (field.Turbulence != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Turbulence) * magnification;
		}

		if (field.Drag != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Drag) * magnification;
		}

		float power = 1.0f;
		if (field.FalloffCommon != nullptr && field.FalloffCone != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffCone);
		}

		if (field.FalloffCommon != nullptr && field.FalloffSphere != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffSphere);
		}

		if (field.FalloffCommon != nullptr && field.FalloffTube != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffTube);
		}

		acc *= power;

		if (field.IsRotated)
		{
			acc = SIMD::Vec3f::Transform(acc, field.Rotation);
		}

		if (coordinateSystem == CoordinateSystem::LH)
		{
			acc.SetZ(-acc.GetZ());
		}

		Velocities[i] += acc;
	}

	VelocitySum = SIMD::Vec3f(0, 0, 0);

	for (size_t i = 0; i < parameter.LocalForceFields.size(); i++)
	{
		if (parameter.LocalForceFields[i].IsGlobal)
			continue;

		VelocitySum += Velocities[i];
	}

	ModifyLocation += VelocitySum * deltaFrame;
}

void LocalForceFieldInstance::UpdateGlobal(const LocalForceFieldParameter& parameter, const SIMD::Vec3f& location, float magnification, const SIMD::Vec3f& targetPosition, float deltaFrame, CoordinateSystem coordinateSystem)
{
	for (size_t i = 0; i < parameter.LocalForceFields.size(); i++)
	{
		auto& field = parameter.LocalForceFields[i];
		if (!field.HasValue)
		{
			continue;
		}

		if (!parameter.LocalForceFields[i].IsGlobal)
			continue;

		ForceFieldCommonParameter ffcp;
		ffcp.FieldCenter = parameter.LocalForceFields[i].Position;
		ffcp.Position = location / magnification;
		ffcp.PreviousSumVelocity = VelocitySum / magnification;
		ffcp.PreviousVelocity = Velocities[i] / magnification;
		ffcp.TargetPosition = targetPosition / magnification;
		ffcp.DeltaFrame = deltaFrame;
		ffcp.IsFieldRotated = field.IsRotated;

		if (coordinateSystem == CoordinateSystem::LH)
		{
			ffcp.Position.SetZ(-ffcp.Position.GetZ());
			ffcp.PreviousVelocity.SetZ(-ffcp.PreviousVelocity.GetZ());
			ffcp.PreviousSumVelocity.SetZ(-ffcp.PreviousSumVelocity.GetZ());
		}

		if (field.IsRotated)
		{
			ffcp.PreviousSumVelocity = SIMD::Vec3f::Transform(ffcp.PreviousSumVelocity, field.InvRotation);
			ffcp.PreviousVelocity = SIMD::Vec3f::Transform(ffcp.PreviousVelocity, field.InvRotation);
			ffcp.Position = SIMD::Vec3f::Transform(ffcp.Position, field.InvRotation);
		}

		ForceField ff;

		SIMD::Vec3f acc = SIMD::Vec3f(0, 0, 0);
		if (field.Gravity != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.Gravity) * magnification;
		}

		if (field.AttractiveForce != nullptr)
		{
			acc = ff.GetAcceleration(ffcp, *field.AttractiveForce) * magnification;
		}

		float power = 1.0f;
		if (field.FalloffCommon != nullptr && field.FalloffCone != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffCone);
		}

		if (field.FalloffCommon != nullptr && field.FalloffSphere != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffSphere);
		}

		if (field.FalloffCommon != nullptr && field.FalloffTube != nullptr)
		{
			ForceFieldFalloff fff;
			power = fff.GetPower(power, ffcp, *field.FalloffCommon, *field.FalloffTube);
		}

		acc *= power;

		if (field.IsRotated)
		{
			acc = SIMD::Vec3f::Transform(acc, field.Rotation);
		}

		if (coordinateSystem == CoordinateSystem::LH)
		{
			acc.SetZ(-acc.GetZ());
		}

		Velocities[i] += acc;
	}

	VelocitySum = SIMD::Vec3f(0, 0, 0);

	for (size_t i = 0; i < parameter.LocalForceFields.size(); i++)
	{
		if (!parameter.LocalForceFields[i].IsGlobal)
			continue;

		VelocitySum += Velocities[i];
	}

	GlobalModifyLocation += VelocitySum * deltaFrame;
}

void LocalForceFieldInstance::Reset()
{
	Velocities.fill(SIMD::Vec3f(0, 0, 0));
	VelocitySum = SIMD::Vec3f(0, 0, 0);
	ModifyLocation = SIMD::Vec3f(0, 0, 0);
	GlobalVelocitySum = SIMD::Vec3f(0, 0, 0);
	GlobalModifyLocation = SIMD::Vec3f(0, 0, 0);
	ExternalVelocity = SIMD::Vec3f(0, 0, 0);
}

} // namespace Effekseer