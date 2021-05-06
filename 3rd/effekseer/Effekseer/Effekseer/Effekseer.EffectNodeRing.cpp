#include "Effekseer.EffectNodeRing.h"

#include "Effekseer.Effect.h"
#include "Effekseer.EffectNode.h"
#include "Effekseer.Manager.h"
#include "Effekseer.Vector3D.h"
#include "SIMD/Utils.h"

#include "Effekseer.Instance.h"
#include "Effekseer.InstanceContainer.h"
#include "Effekseer.InstanceGlobal.h"

#include "Renderer/Effekseer.RingRenderer.h"

#include "Effekseer.Setting.h"

#include "Utils/Compatiblity.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::LoadRendererParameter(unsigned char*& pos, const SettingRef& setting)
{
	int32_t type = 0;
	memcpy(&type, pos, sizeof(int));
	pos += sizeof(int);
	assert(type == GetType());
	EffekseerPrintDebug("Renderer : Ring\n");

	memcpy(&RenderingOrder, pos, sizeof(int));
	pos += sizeof(int);

	if (m_effect->GetVersion() >= 3)
	{
		AlphaBlend = RendererCommon.AlphaBlend;
	}
	else
	{
		memcpy(&AlphaBlend, pos, sizeof(int));
		pos += sizeof(int);
	}

	memcpy(&Billboard, pos, sizeof(int));
	pos += sizeof(int);

	if (m_effect->GetVersion() >= 15)
	{
		int32_t ringShape = 0;
		memcpy(&ringShape, pos, sizeof(int));
		pos += sizeof(int);

		Shape.Type = static_cast<RingShapeType>(ringShape);

		if (Shape.Type == RingShapeType::Dount)
		{
			Shape.StartingAngle.type = RingSingleParameter::Fixed;
			Shape.EndingAngle.type = RingSingleParameter::Fixed;
			Shape.StartingAngle.fixed = 0;
			Shape.EndingAngle.fixed = 360;
		}
		else if (Shape.Type == RingShapeType::Cresient)
		{
			memcpy(&Shape.StartingFade, pos, sizeof(float));
			pos += sizeof(float);
			memcpy(&Shape.EndingFade, pos, sizeof(float));
			pos += sizeof(float);

			LoadSingleParameter(pos, Shape.StartingAngle);
			LoadSingleParameter(pos, Shape.EndingAngle);
		}
	}

	memcpy(&VertexCount, pos, sizeof(int));
	pos += sizeof(int);

	// compatiblity
	{
		RingSingleParameter viewingAngle;
		LoadSingleParameter(pos, viewingAngle);
		if (m_effect->GetVersion() < 15)
		{
			Shape.Type = RingShapeType::Cresient;
			Shape.StartingAngle = viewingAngle;
			Shape.EndingAngle = viewingAngle;

			if (viewingAngle.type == RingSingleParameter::Fixed)
			{
				Shape.StartingAngle.fixed = (360 - viewingAngle.fixed) / 2.0f + 90.0f;
				Shape.EndingAngle.fixed = 360.0f - (360 - viewingAngle.fixed) / 2.0f + 90.0f;
			}

			if (viewingAngle.type == RingSingleParameter::Random)
			{
				Shape.StartingAngle.random.max = (360 - viewingAngle.random.min) / 2.0f + 90.0f;
				Shape.StartingAngle.random.min = (360 - viewingAngle.random.max) / 2.0f + 90.0f;
				Shape.EndingAngle.random.max = 360.0f - (360 - viewingAngle.random.max) / 2.0f + 90.0f;
				Shape.EndingAngle.random.min = 360.0f - (360 - viewingAngle.random.min) / 2.0f + 90.0f;
			}

			if (viewingAngle.type == RingSingleParameter::Easing)
			{
				Shape.StartingAngle.easing.start.max = (360 - viewingAngle.easing.start.min) / 2.0f + 90.0f;
				Shape.StartingAngle.easing.start.min = (360 - viewingAngle.easing.start.max) / 2.0f + 90.0f;
				Shape.StartingAngle.easing.end.max = (360 - viewingAngle.easing.end.min) / 2.0f + 90.0f;
				Shape.StartingAngle.easing.end.min = (360 - viewingAngle.easing.end.max) / 2.0f + 90.0f;
				Shape.EndingAngle.easing.start.max = 360.0f - (360 - viewingAngle.easing.start.max) / 2.0f + 90.0f;
				Shape.EndingAngle.easing.start.min = 360.0f - (360 - viewingAngle.easing.start.min) / 2.0f + 90.0f;
				Shape.EndingAngle.easing.end.max = 360.0f - (360 - viewingAngle.easing.end.max) / 2.0f + 90.0f;
				Shape.EndingAngle.easing.end.min = 360.0f - (360 - viewingAngle.easing.end.min) / 2.0f + 90.0f;
			}
		}
	}

	LoadLocationParameter(pos, OuterLocation);

	LoadLocationParameter(pos, InnerLocation);

	LoadSingleParameter(pos, CenterRatio);

	LoadColorParameter(pos, OuterColor);

	LoadColorParameter(pos, CenterColor);

	LoadColorParameter(pos, InnerColor);

	if (m_effect->GetVersion() >= 3)
	{
		RingTexture = RendererCommon.ColorTextureIndex;
	}
	else
	{
		memcpy(&RingTexture, pos, sizeof(int));
		pos += sizeof(int);
	}

	// 右手系左手系変換
	if (setting->GetCoordinateSystem() == CoordinateSystem::LH)
	{
		if (OuterLocation.type == RingLocationParameter::Fixed)
		{
			OuterLocation.fixed.location.y *= -1;
		}
		else if (OuterLocation.type == RingLocationParameter::PVA)
		{
			OuterLocation.pva.location.min.y *= -1;
			OuterLocation.pva.location.max.y *= -1;
			OuterLocation.pva.velocity.min.y *= -1;
			OuterLocation.pva.velocity.max.y *= -1;
			OuterLocation.pva.acceleration.min.y *= -1;
			OuterLocation.pva.acceleration.max.y *= -1;
		}
		else if (OuterLocation.type == RingLocationParameter::Easing)
		{
			OuterLocation.easing.start.min.y *= -1;
			OuterLocation.easing.start.max.y *= -1;
			OuterLocation.easing.end.min.y *= -1;
			OuterLocation.easing.end.max.y *= -1;
		}

		if (InnerLocation.type == RingLocationParameter::Fixed)
		{
			InnerLocation.fixed.location.y *= -1;
		}
		else if (InnerLocation.type == RingLocationParameter::PVA)
		{
			InnerLocation.pva.location.min.y *= -1;
			InnerLocation.pva.location.max.y *= -1;
			InnerLocation.pva.velocity.min.y *= -1;
			InnerLocation.pva.velocity.max.y *= -1;
			InnerLocation.pva.acceleration.min.y *= -1;
			InnerLocation.pva.acceleration.max.y *= -1;
		}
		else if (InnerLocation.type == RingLocationParameter::Easing)
		{
			InnerLocation.easing.start.min.y *= -1;
			InnerLocation.easing.start.max.y *= -1;
			InnerLocation.easing.end.min.y *= -1;
			InnerLocation.easing.end.max.y *= -1;
		}
	}

	/* 位置拡大処理 */
	if (m_effect->GetVersion() >= 8)
	{
		if (OuterLocation.type == RingLocationParameter::Fixed)
		{
			OuterLocation.fixed.location *= m_effect->GetMaginification();
		}
		else if (OuterLocation.type == RingLocationParameter::PVA)
		{
			OuterLocation.pva.location.min *= m_effect->GetMaginification();
			OuterLocation.pva.location.max *= m_effect->GetMaginification();
			OuterLocation.pva.velocity.min *= m_effect->GetMaginification();
			OuterLocation.pva.velocity.max *= m_effect->GetMaginification();
			OuterLocation.pva.acceleration.min *= m_effect->GetMaginification();
			OuterLocation.pva.acceleration.max *= m_effect->GetMaginification();
		}
		else if (OuterLocation.type == RingLocationParameter::Easing)
		{
			OuterLocation.easing.start.min *= m_effect->GetMaginification();
			OuterLocation.easing.start.max *= m_effect->GetMaginification();
			OuterLocation.easing.end.min *= m_effect->GetMaginification();
			OuterLocation.easing.end.max *= m_effect->GetMaginification();
		}

		if (InnerLocation.type == RingLocationParameter::Fixed)
		{
			InnerLocation.fixed.location *= m_effect->GetMaginification();
		}
		else if (InnerLocation.type == RingLocationParameter::PVA)
		{
			InnerLocation.pva.location.min *= m_effect->GetMaginification();
			InnerLocation.pva.location.max *= m_effect->GetMaginification();
			InnerLocation.pva.velocity.min *= m_effect->GetMaginification();
			InnerLocation.pva.velocity.max *= m_effect->GetMaginification();
			InnerLocation.pva.acceleration.min *= m_effect->GetMaginification();
			InnerLocation.pva.acceleration.max *= m_effect->GetMaginification();
		}
		else if (InnerLocation.type == RingLocationParameter::Easing)
		{
			InnerLocation.easing.start.min *= m_effect->GetMaginification();
			InnerLocation.easing.start.max *= m_effect->GetMaginification();
			InnerLocation.easing.end.min *= m_effect->GetMaginification();
			InnerLocation.easing.end.max *= m_effect->GetMaginification();
		}
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::BeginRendering(int32_t count, Manager* manager, void* userData)
{
	RingRendererRef renderer = manager->GetRingRenderer();
	if (renderer != nullptr)
	{
		nodeParameter.EffectPointer = GetEffect();
		nodeParameter.ZTest = RendererCommon.ZTest;
		nodeParameter.ZWrite = RendererCommon.ZWrite;
		nodeParameter.Billboard = Billboard;
		nodeParameter.VertexCount = VertexCount;
		nodeParameter.IsRightHand = manager->GetCoordinateSystem() == CoordinateSystem::RH;
		nodeParameter.Maginification = GetEffect()->GetMaginification();

		nodeParameter.DepthParameterPtr = &DepthValues.DepthParameter;
		nodeParameter.BasicParameterPtr = &RendererCommon.BasicParameter;
		nodeParameter.StartingFade = Shape.StartingFade;
		nodeParameter.EndingFade = Shape.EndingFade;

		nodeParameter.EnableViewOffset = (TranslationType == ParameterTranslationType_ViewOffset);

		nodeParameter.UserData = GetRenderingUserData();

		renderer->BeginRendering(nodeParameter, count, userData);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::Rendering(const Instance& instance, const Instance* next_instance, Manager* manager, void* userData)
{
	const InstanceValues& instValues = instance.rendererValues.ring;
	RingRendererRef renderer = manager->GetRingRenderer();
	if (renderer != nullptr)
	{
		nodeParameter.EffectPointer = GetEffect();
		nodeParameter.ZTest = RendererCommon.ZTest;
		nodeParameter.ZWrite = RendererCommon.ZWrite;
		nodeParameter.Billboard = Billboard;
		nodeParameter.VertexCount = VertexCount;
		nodeParameter.IsRightHand = manager->GetCoordinateSystem() == CoordinateSystem::RH;

		nodeParameter.DepthParameterPtr = &DepthValues.DepthParameter;
		nodeParameter.BasicParameterPtr = &RendererCommon.BasicParameter;
		nodeParameter.StartingFade = Shape.StartingFade;
		nodeParameter.EndingFade = Shape.EndingFade;

		nodeParameter.EnableViewOffset = (TranslationType == ParameterTranslationType_ViewOffset);

		Color _outerColor;
		Color _centerColor;
		Color _innerColor;

		if (RendererCommon.ColorBindType == BindType::Always || RendererCommon.ColorBindType == BindType::WhenCreating)
		{
			_outerColor = Color::Mul(instValues.outerColor.original, instance.ColorParent);
			_centerColor = Color::Mul(instValues.centerColor.original, instance.ColorParent);
			_innerColor = Color::Mul(instValues.innerColor.original, instance.ColorParent);
		}
		else
		{
			_outerColor = instValues.outerColor.original;
			_centerColor = instValues.centerColor.original;
			_innerColor = instValues.innerColor.original;
		}

		RingRenderer::InstanceParameter instanceParameter;
		instanceParameter.SRTMatrix43 = instance.GetGlobalMatrix43();

		instanceParameter.ViewingAngleStart = instValues.startingAngle.current;
		instanceParameter.ViewingAngleEnd = instValues.endingAngle.current;

		instanceParameter.OuterLocation = instValues.outerLocation.current;
		instanceParameter.InnerLocation = instValues.innerLocation.current;

		instanceParameter.CenterRatio = instValues.centerRatio.current;

		// Apply global Color
		if (instance.m_pContainer->GetRootInstance()->IsGlobalColorSet)
		{
			_outerColor = Color::Mul(_outerColor, instance.m_pContainer->GetRootInstance()->GlobalColor);
			_centerColor = Color::Mul(_centerColor, instance.m_pContainer->GetRootInstance()->GlobalColor);
			_innerColor = Color::Mul(_innerColor, instance.m_pContainer->GetRootInstance()->GlobalColor);
		}

		instanceParameter.OuterColor = _outerColor;
		instanceParameter.CenterColor = _centerColor;
		instanceParameter.InnerColor = _innerColor;

		instanceParameter.UV = instance.GetUV(0);
		instanceParameter.AlphaUV = instance.GetUV(1);
		instanceParameter.UVDistortionUV = instance.GetUV(2);
		instanceParameter.BlendUV = instance.GetUV(3);
		instanceParameter.BlendAlphaUV = instance.GetUV(4);
		instanceParameter.BlendUVDistortionUV = instance.GetUV(5);

		instanceParameter.FlipbookIndexAndNextRate = instance.m_flipbookIndexAndNextRate;

		instanceParameter.AlphaThreshold = instance.m_AlphaThreshold;

		if (instance.m_pEffectNode->TranslationType == ParameterTranslationType_ViewOffset)
		{
			instanceParameter.ViewOffsetDistance = instance.translation_values.view_offset.distance;
		}

		CalcCustomData(&instance, instanceParameter.CustomData1, instanceParameter.CustomData2);

		nodeParameter.UserData = GetRenderingUserData();

		renderer->Rendering(nodeParameter, instanceParameter, userData);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::EndRendering(Manager* manager, void* userData)
{
	RingRendererRef renderer = manager->GetRingRenderer();
	if (renderer != nullptr)
	{
		renderer->EndRendering(nodeParameter, userData);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::InitializeRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager)
{
	IRandObject* rand = &instance.GetRandObject();

	InstanceValues& instValues = instance.rendererValues.ring;

	InitializeSingleValues(Shape.StartingAngle, instValues.startingAngle, manager, rand);
	InitializeSingleValues(Shape.EndingAngle, instValues.endingAngle, manager, rand);

	InitializeLocationValues(OuterLocation, instValues.outerLocation, manager, rand);
	InitializeLocationValues(InnerLocation, instValues.innerLocation, manager, rand);

	InitializeSingleValues(CenterRatio, instValues.centerRatio, manager, rand);

	InitializeColorValues(OuterColor, instValues.outerColor, manager, rand);
	InitializeColorValues(CenterColor, instValues.centerColor, manager, rand);
	InitializeColorValues(InnerColor, instValues.innerColor, manager, rand);

	if (RendererCommon.ColorBindType == BindType::Always || RendererCommon.ColorBindType == BindType::WhenCreating)
	{
		instValues.outerColor.current = Color::Mul(instValues.outerColor.original, instance.ColorParent);
		instValues.centerColor.current = Color::Mul(instValues.centerColor.original, instance.ColorParent);
		instValues.innerColor.current = Color::Mul(instValues.innerColor.original, instance.ColorParent);
	}
	else
	{
		instValues.outerColor.current = instValues.outerColor.original;
		instValues.centerColor.current = instValues.centerColor.original;
		instValues.innerColor.current = instValues.innerColor.original;
	}

	instance.ColorInheritance = instValues.centerColor.current;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::UpdateRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager)
{
	InstanceValues& instValues = instance.rendererValues.ring;

	UpdateSingleValues(instance, Shape.StartingAngle, instValues.startingAngle);
	UpdateSingleValues(instance, Shape.EndingAngle, instValues.endingAngle);

	UpdateLocationValues(instance, OuterLocation, instValues.outerLocation);
	UpdateLocationValues(instance, InnerLocation, instValues.innerLocation);

	UpdateSingleValues(instance, CenterRatio, instValues.centerRatio);

	UpdateColorValues(instance, OuterColor, instValues.outerColor);
	UpdateColorValues(instance, CenterColor, instValues.centerColor);
	UpdateColorValues(instance, InnerColor, instValues.innerColor);

	if (RendererCommon.ColorBindType == BindType::Always || RendererCommon.ColorBindType == BindType::WhenCreating)
	{
		instValues.outerColor.current = Color::Mul(instValues.outerColor.original, instance.ColorParent);
		instValues.centerColor.current = Color::Mul(instValues.centerColor.original, instance.ColorParent);
		instValues.innerColor.current = Color::Mul(instValues.innerColor.original, instance.ColorParent);
	}
	else
	{
		instValues.outerColor.current = instValues.outerColor.original;
		instValues.centerColor.current = instValues.centerColor.original;
		instValues.innerColor.current = instValues.innerColor.original;
	}

	instance.ColorInheritance = instValues.centerColor.current;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::LoadSingleParameter(unsigned char*& pos, RingSingleParameter& param)
{
	memcpy(&param.type, pos, sizeof(int));
	pos += sizeof(int);

	if (param.type == RingSingleParameter::Fixed)
	{
		memcpy(&param.fixed, pos, sizeof(float));
		pos += sizeof(float);
	}
	else if (param.type == RingSingleParameter::Random)
	{
		memcpy(&param.random, pos, sizeof(param.random));
		pos += sizeof(param.random);
	}
	else if (param.type == RingSingleParameter::Easing)
	{
		LoadFloatEasing(param.easing, pos, m_effect->GetVersion());
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::LoadLocationParameter(unsigned char*& pos, RingLocationParameter& param)
{
	memcpy(&param.type, pos, sizeof(int));
	pos += sizeof(int);

	if (param.type == RingLocationParameter::Fixed)
	{
		memcpy(&param.fixed, pos, sizeof(param.fixed));
		pos += sizeof(param.fixed);
	}
	else if (param.type == RingLocationParameter::PVA)
	{
		memcpy(&param.pva, pos, sizeof(param.pva));
		pos += sizeof(param.pva);
	}
	else if (param.type == RingLocationParameter::Easing)
	{
		memcpy(&param.easing, pos, sizeof(param.easing));
		pos += sizeof(param.easing);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::LoadColorParameter(unsigned char*& pos, RingColorParameter& param)
{
	memcpy(&param.type, pos, sizeof(int));
	pos += sizeof(int);

	if (param.type == RingColorParameter::Fixed)
	{
		memcpy(&param.fixed, pos, sizeof(param.fixed));
		pos += sizeof(param.fixed);
	}
	else if (param.type == RingColorParameter::Random)
	{
		param.random.load(m_effect->GetVersion(), pos);
	}
	else if (param.type == RingColorParameter::Easing)
	{
		param.easing.load(m_effect->GetVersion(), pos);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::InitializeSingleValues(const RingSingleParameter& param, RingSingleValues& values, Manager* manager, IRandObject* rand)
{
	switch (param.type)
	{
	case RingSingleParameter::Fixed:
		values.current = param.fixed;
		break;
	case RingSingleParameter::Random:
		values.current = param.random.getValue(*rand);
		break;
	case RingSingleParameter::Easing:
		values.easing.start = param.easing.start.getValue(*rand);
		values.easing.end = param.easing.end.getValue(*rand);
		values.current = values.easing.start;
		break;
	default:
		break;
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::InitializeLocationValues(const RingLocationParameter& param,
											  RingLocationValues& values,
											  Manager* manager,
											  IRandObject* rand)
{
	switch (param.type)
	{
	case RingLocationParameter::Fixed:
		values.current = param.fixed.location;
		break;
	case RingLocationParameter::PVA:
		values.pva.start = param.pva.location.getValue(*rand);
		values.pva.velocity = param.pva.velocity.getValue(*rand);
		values.pva.acceleration = param.pva.acceleration.getValue(*rand);
		values.current = values.pva.start;
		break;
	case RingLocationParameter::Easing:
		values.easing.start = param.easing.start.getValue(*rand);
		values.easing.end = param.easing.end.getValue(*rand);
		values.current = values.easing.start;
		break;
	default:
		break;
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::InitializeColorValues(const RingColorParameter& param, RingColorValues& values, Manager* manager, IRandObject* rand)
{
	switch (param.type)
	{
	case RingColorParameter::Fixed:
		values.original = param.fixed;
		values.fixed._color = values.original;
		break;
	case RingColorParameter::Random:
		values.original = param.random.getValue(*rand);
		values.random._color = values.original;
		break;
	case RingColorParameter::Easing:
		values.easing.start = param.easing.getStartValue(*rand);
		values.easing.end = param.easing.getEndValue(*rand);
		values.original = values.easing.start;
		break;
	default:
		break;
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::UpdateSingleValues(Instance& instance, const RingSingleParameter& param, RingSingleValues& values)
{
	if (param.type == RingSingleParameter::Easing)
	{
		values.current = param.easing.GetValue(values.easing, instance.m_LivingTime / instance.m_LivedTime);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::UpdateLocationValues(Instance& instance, const RingLocationParameter& param, RingLocationValues& values)
{
	if (param.type == RingLocationParameter::PVA)
	{
		values.current = values.pva.start + values.pva.velocity * instance.m_LivingTime +
						 values.pva.acceleration * instance.m_LivingTime * instance.m_LivingTime * 0.5f;
	}
	else if (param.type == RingLocationParameter::Easing)
	{
		values.current = param.easing.getValue(values.easing.start, values.easing.end, instance.m_LivingTime / instance.m_LivedTime);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectNodeRing::UpdateColorValues(Instance& instance, const RingColorParameter& param, RingColorValues& values)
{
	if (param.type == RingColorParameter::Fixed)
	{
		values.original = values.fixed._color;
	}
	else if (param.type == RingColorParameter::Random)
	{
		values.original = values.random._color;
	}
	else if (param.type == RingColorParameter::Easing)
	{
		param.easing.setValueToArg(values.original, values.easing.start, values.easing.end, instance.m_LivingTime / instance.m_LivedTime);
	}

	float fadeAlpha = GetFadeAlpha(instance);
	if (fadeAlpha != 1.0f)
	{
		values.original.A = (uint8_t)(values.original.A * fadeAlpha);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
