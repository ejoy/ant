#include "Effekseer.Parameters.h"
#include "../Effekseer.EffectImplemented.h"
#include "../Effekseer.Instance.h"
#include "../Effekseer.InstanceGlobal.h"
#include "../Effekseer.InternalScript.h"
#include "DynamicParameter.h"

namespace Effekseer
{
void NodeRendererTextureUVTypeParameter::Load(uint8_t*& pos, int32_t version)
{
	memcpy(&Type, pos, sizeof(int));
	pos += sizeof(int);

	if (Type == TextureUVType::Strech)
	{
	}
	else if (Type == TextureUVType::Tile)
	{
		memcpy(&TileEdgeHead, pos, sizeof(TileEdgeHead));
		pos += sizeof(TileEdgeHead);

		memcpy(&TileEdgeTail, pos, sizeof(TileEdgeTail));
		pos += sizeof(TileEdgeTail);

		memcpy(&TileLoopAreaBegin, pos, sizeof(TileLoopAreaBegin));
		pos += sizeof(TileLoopAreaBegin);

		memcpy(&TileLoopAreaEnd, pos, sizeof(TileLoopAreaEnd));
		pos += sizeof(TileLoopAreaEnd);
	}
}

template <typename T, typename U>
void ApplyEq_(T& dstParam, Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, int dpInd, const U& originalParam)
{
	static_assert(sizeof(T) == sizeof(U), "size is not mismatched");
	const int count = sizeof(T) / 4;

	EFK_ASSERT(e != nullptr);
	EFK_ASSERT(0 <= dpInd && dpInd < static_cast<int>(instg->dynamicEqResults.size()));

	auto dst = reinterpret_cast<float*>(&(dstParam));
	auto src = reinterpret_cast<const float*>(&(originalParam));

	auto eqresult = instg->dynamicEqResults[dpInd];
	std::array<float, 1> globals;
	globals[0] = instg->GetUpdatedFrame() / 60.0f;

	std::array<float, 5> locals;

	for (int i = 0; i < count; i++)
	{
		locals[i] = src[i];
	}

	for (int i = count; i < 4; i++)
	{
		locals[i] = 0.0f;
	}

	locals[4] = parrentInstance != nullptr ? parrentInstance->m_LivingTime / 60.0f : 0.0f;

	auto e_ = static_cast<EffectImplemented*>(e);
	auto& dp = e_->GetDynamicEquation()[dpInd];

	if (dp.GetRunningPhase() == InternalScript::RunningPhaseType::Local)
	{
		eqresult = dp.Execute(instg->GetDynamicInputParameters(), globals, locals, RandCallback::Rand, RandCallback::RandSeed, rand);
	}

	for (int i = 0; i < count; i++)
	{
		dst[i] = eqresult[i];
	}
}

void ApplyEq(float& dstParam, Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, int dpInd, const float& originalParam)
{
	ApplyEq_(dstParam, e, instg, parrentInstance, rand, dpInd, originalParam);
}

template <typename S>
SIMD::Vec3f ApplyEq_(
	Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const int& dpInd, const SIMD::Vec3f& originalParam, const S& scale, const S& scaleInv)
{
	SIMD::Vec3f param = originalParam;
	if (dpInd >= 0)
	{
		param *= SIMD::Vec3f(scaleInv[0], scaleInv[1], scaleInv[2]);

		ApplyEq_(param, e, instg, parrentInstance, rand, dpInd, param);

		param *= SIMD::Vec3f(scale[0], scale[1], scale[2]);
	}
	return param;
}

SIMD::Vec3f ApplyEq(
	Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const int& dpInd, const SIMD::Vec3f& originalParam, const std::array<float, 3>& scale, const std::array<float, 3>& scaleInv)
{
	return ApplyEq_(e, instg, parrentInstance, rand, dpInd, originalParam, scale, scaleInv);
}

random_float ApplyEq(Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const RefMinMax& dpInd, random_float originalParam)
{
	if (dpInd.Max >= 0)
	{
		ApplyEq_(originalParam.max, e, instg, parrentInstance, rand, dpInd.Max, originalParam.max);
	}

	if (dpInd.Min >= 0)
	{
		ApplyEq_(originalParam.min, e, instg, parrentInstance, rand, dpInd.Min, originalParam.min);
	}

	return originalParam;
}

template <typename S>
random_vector3d ApplyEq_(Effect* e,
						 InstanceGlobal* instg,
						 Instance* parrentInstance,
						 IRandObject* rand,
						 const RefMinMax& dpInd,
						 random_vector3d originalParam,
						 const S& scale,
						 const S& scaleInv)
{
	if (dpInd.Max >= 0)
	{
		originalParam.max.x *= scaleInv[0];
		originalParam.max.y *= scaleInv[1];
		originalParam.max.z *= scaleInv[2];

		ApplyEq_(originalParam.max, e, instg, parrentInstance, rand, dpInd.Max, originalParam.max);

		originalParam.max.x *= scale[0];
		originalParam.max.y *= scale[1];
		originalParam.max.z *= scale[2];
	}

	if (dpInd.Min >= 0)
	{
		originalParam.min.x *= scaleInv[0];
		originalParam.min.y *= scaleInv[1];
		originalParam.min.z *= scaleInv[2];

		ApplyEq_(originalParam.min, e, instg, parrentInstance, rand, dpInd.Min, originalParam.min);

		originalParam.min.x *= scale[0];
		originalParam.min.y *= scale[1];
		originalParam.min.z *= scale[2];
	}

	return originalParam;
}

random_vector3d ApplyEq(Effect* e,
						InstanceGlobal* instg,
						Instance* parrentInstance,
						IRandObject* rand,
						const RefMinMax& dpInd,
						random_vector3d originalParam,
						const std::array<float, 3>& scale,
						const std::array<float, 3>& scaleInv)
{
	return ApplyEq_(e,
					instg,
					parrentInstance,
					rand,
					dpInd,
					originalParam,
					scale,
					scaleInv);
}

random_int ApplyEq(Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const RefMinMax& dpInd, random_int originalParam)
{
	if (dpInd.Max >= 0)
	{
		float value = static_cast<float>(originalParam.max);
		ApplyEq_(value, e, instg, parrentInstance, rand, dpInd.Max, value);
		originalParam.max = static_cast<int32_t>(value);
	}

	if (dpInd.Min >= 0)
	{
		float value = static_cast<float>(originalParam.min);
		ApplyEq_(value, e, instg, parrentInstance, rand, dpInd.Min, value);
		originalParam.min = static_cast<int32_t>(value);
	}

	return originalParam;
}

} // namespace Effekseer