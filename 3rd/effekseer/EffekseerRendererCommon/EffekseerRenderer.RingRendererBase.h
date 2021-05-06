
#ifndef __EFFEKSEERRENDERER_RING_RENDERER_BASE_H__
#define __EFFEKSEERRENDERER_RING_RENDERER_BASE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <Effekseer.h>
#include <assert.h>
#include <math.h>
#include <string.h>

#include "EffekseerRenderer.CommonUtils.h"
#include "EffekseerRenderer.IndexBufferBase.h"
#include "EffekseerRenderer.RenderStateBase.h"
#include "EffekseerRenderer.StandardRenderer.h"
#include "EffekseerRenderer.VertexBufferBase.h"

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
namespace EffekseerRenderer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
typedef ::Effekseer::RingRenderer::NodeParameter efkRingNodeParam;
typedef ::Effekseer::RingRenderer::InstanceParameter efkRingInstanceParam;
typedef ::Effekseer::SIMD::Vec3f efkVector3D;

template <typename RENDERER, bool FLIP_RGB_FLAG>
class RingRendererBase : public ::Effekseer::RingRenderer, public ::Effekseer::SIMD::AlignedAllocationPolicy<16>
{
protected:
	struct KeyValue
	{
		float Key;
		efkRingInstanceParam Value;
	};
	std::vector<KeyValue> instances_;

	RENDERER* m_renderer;
	int32_t m_ringBufferOffset;
	uint8_t* m_ringBufferData;

	int32_t m_spriteCount;
	int32_t m_instanceCount;
	::Effekseer::SIMD::Mat44f m_singleRenderingMatrix;
	::Effekseer::RendererMaterialType materialType_ = ::Effekseer::RendererMaterialType::Default;

	int32_t vertexCount_ = 0;
	int32_t stride_ = 0;
	int32_t customData1Count_ = 0;
	int32_t customData2Count_ = 0;
	bool fasterSngleRingModeEnabled_ = true;

public:
	RingRendererBase(RENDERER* renderer)
		: m_renderer(renderer)
		, m_ringBufferOffset(0)
		, m_ringBufferData(nullptr)
		, m_spriteCount(0)
		, m_instanceCount(0)
	{
	}

	virtual ~RingRendererBase()
	{
	}

	/**
		@brief	get a flag of single ring mode
		@note
		This flag means that a rendering of ring is faster with GPU on some condition.
		Default is true.
	*/
	bool GetFasterSingleRingModeEnabled() const
	{
		return fasterSngleRingModeEnabled_;
	}

	/**
		@brief	Set a flag of single ring mode
		@note
		please read getter
	*/

	void SetFasterSngleRingModeEnabled(bool value)
	{
		fasterSngleRingModeEnabled_ = value;
	}

protected:
	void RenderingInstance(const efkRingInstanceParam& instanceParameter,
						   const efkRingNodeParam& parameter,
						   const StandardRendererState& state,
						   const ::Effekseer::SIMD::Mat44f& camera)
	{
		const ShaderParameterCollector& collector = state.Collector;
		if (collector.ShaderType == RendererShaderType::Material)
		{
			Rendering_Internal<DynamicVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedLit)
		{
			Rendering_Internal<AdvancedLightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedBackDistortion)
		{
			Rendering_Internal<AdvancedLightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedUnlit)
		{
			Rendering_Internal<AdvancedSimpleVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::Lit)
		{
			Rendering_Internal<LightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::BackDistortion)
		{
			Rendering_Internal<LightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else
		{
			Rendering_Internal<SimpleVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
	}

	void BeginRendering_(RENDERER* renderer, int32_t count, const efkRingNodeParam& param, void* userData)
	{
		m_spriteCount = 0;
		const auto singleVertexCount = param.VertexCount * 8;
		const auto singleSpriteCount = param.VertexCount * 2;

		count = (std::min)(count, renderer->GetSquareMaxCount() / singleSpriteCount);

		m_instanceCount = count;

		instances_.clear();

		if (param.DepthParameterPtr->ZSort != Effekseer::ZSortType::None)
		{
			instances_.reserve(count);
		}

		if (count == 1)
		{
			renderer->GetStandardRenderer()->ResetAndRenderingIfRequired();
		}

		EffekseerRenderer::StandardRendererState state;
		state.AlphaBlend = param.BasicParameterPtr->AlphaBlend;
		state.CullingType = ::Effekseer::CullingType::Double;
		state.DepthTest = param.ZTest;
		state.DepthWrite = param.ZWrite;

		state.EnableInterpolation = param.BasicParameterPtr->EnableInterpolation;
		state.UVLoopType = param.BasicParameterPtr->UVLoopType;
		state.InterpolationType = param.BasicParameterPtr->InterpolationType;
		state.FlipbookDivideX = param.BasicParameterPtr->FlipbookDivideX;
		state.FlipbookDivideY = param.BasicParameterPtr->FlipbookDivideY;

		state.UVDistortionIntensity = param.BasicParameterPtr->UVDistortionIntensity;

		state.TextureBlendType = param.BasicParameterPtr->TextureBlendType;

		state.BlendUVDistortionIntensity = param.BasicParameterPtr->BlendUVDistortionIntensity;

		state.EmissiveScaling = param.BasicParameterPtr->EmissiveScaling;

		state.EdgeThreshold = param.BasicParameterPtr->EdgeThreshold;
		state.EdgeColor[0] = param.BasicParameterPtr->EdgeColor[0];
		state.EdgeColor[1] = param.BasicParameterPtr->EdgeColor[1];
		state.EdgeColor[2] = param.BasicParameterPtr->EdgeColor[2];
		state.EdgeColor[3] = param.BasicParameterPtr->EdgeColor[3];
		state.EdgeColorScaling = param.BasicParameterPtr->EdgeColorScaling;
		state.IsAlphaCuttoffEnabled = param.BasicParameterPtr->IsAlphaCutoffEnabled;
		state.Maginification = param.Maginification;

		state.Distortion = param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::BackDistortion;
		state.DistortionIntensity = param.BasicParameterPtr->DistortionIntensity;
		state.MaterialType = param.BasicParameterPtr->MaterialType;

		state.RenderingUserData = param.UserData;
		state.HandleUserData = userData;

		state.CopyMaterialFromParameterToState(
			m_renderer,
			param.EffectPointer,
			param.BasicParameterPtr);

		customData1Count_ = state.CustomData1Count;
		customData2Count_ = state.CustomData2Count;

		materialType_ = param.BasicParameterPtr->MaterialType;

		renderer->GetStandardRenderer()->UpdateStateAndRenderingIfRequired(state);
		renderer->GetStandardRenderer()->BeginRenderingAndRenderingIfRequired(count * singleVertexCount, stride_, (void*&)m_ringBufferData);

		vertexCount_ = count * singleVertexCount;
	}

	void Rendering_(const efkRingNodeParam& parameter,
					const efkRingInstanceParam& instanceParameter,
					const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (parameter.DepthParameterPtr->ZSort == Effekseer::ZSortType::None || CanSingleRendering())
		{
			const auto& state = m_renderer->GetStandardRenderer()->GetState();

			RenderingInstance(instanceParameter, parameter, state, camera);
		}
		else
		{
			KeyValue kv;
			kv.Value = instanceParameter;
			instances_.push_back(kv);
		}
	}

	bool CanSingleRendering()
	{
		return m_instanceCount <= 1 && materialType_ == ::Effekseer::RendererMaterialType::Default && fasterSngleRingModeEnabled_;
	}

	template <typename VERTEX, bool FLIP_RGB>
	void Rendering_Internal(const efkRingNodeParam& parameter,
							const efkRingInstanceParam& instanceParameter,
							const ::Effekseer::SIMD::Mat44f& camera)
	{
		::Effekseer::SIMD::Mat43f mat43{};

		if (parameter.Billboard == ::Effekseer::BillboardType::Billboard ||
			parameter.Billboard == ::Effekseer::BillboardType::RotatedBillboard ||
			parameter.Billboard == ::Effekseer::BillboardType::YAxisFixed)
		{
			Effekseer::SIMD::Vec3f s;
			Effekseer::SIMD::Vec3f R;
			Effekseer::SIMD::Vec3f F;

			if (parameter.EnableViewOffset)
			{
				Effekseer::SIMD::Mat43f instMat = instanceParameter.SRTMatrix43;

				ApplyViewOffset(instMat, camera, instanceParameter.ViewOffsetDistance);

				CalcBillboard(parameter.Billboard, mat43, s, R, F, instMat, m_renderer->GetCameraFrontDirection());
			}
			else
			{
				CalcBillboard(parameter.Billboard, mat43, s, R, F, instanceParameter.SRTMatrix43, m_renderer->GetCameraFrontDirection());
			}

			ApplyDepthParameters(mat43,
								 m_renderer->GetCameraFrontDirection(),
								 m_renderer->GetCameraPosition(),
								 s,
								 parameter.DepthParameterPtr,
								 parameter.IsRightHand);

			if (CanSingleRendering())
			{
				mat43 = ::Effekseer::SIMD::Mat43f::Scaling(s) * mat43;
			}
			else
			{
				mat43 = ::Effekseer::SIMD::Mat43f::Scaling(s) * mat43;
			}
		}
		else if (parameter.Billboard == ::Effekseer::BillboardType::Fixed)
		{
			mat43 = instanceParameter.SRTMatrix43;

			if (parameter.EnableViewOffset)
			{
				ApplyViewOffset(mat43, camera, instanceParameter.ViewOffsetDistance);
			}

			ApplyDepthParameters(mat43,
								 m_renderer->GetCameraFrontDirection(),
								 m_renderer->GetCameraPosition(),
								 parameter.DepthParameterPtr,
								 parameter.IsRightHand);
		}

		int32_t singleVertexCount = parameter.VertexCount * 8;
		// Vertex* verteies = (Vertex*)m_renderer->GetVertexBuffer()->GetBufferDirect( sizeof(Vertex) * vertexCount );

		StrideView<VERTEX> verteies(m_ringBufferData, stride_, singleVertexCount);
		const float circleAngleDegree = (instanceParameter.ViewingAngleEnd - instanceParameter.ViewingAngleStart);
		const float stepAngleDegree = circleAngleDegree / (parameter.VertexCount);
		const float stepAngle = (stepAngleDegree) / 180.0f * 3.141592f;
		const float beginAngle = (instanceParameter.ViewingAngleStart + 90) / 180.0f * 3.141592f;

		const float outerRadius = instanceParameter.OuterLocation.GetX();
		const float innerRadius = instanceParameter.InnerLocation.GetX();
		const float centerRadius = innerRadius + (outerRadius - innerRadius) * instanceParameter.CenterRatio;

		const float outerHeight = instanceParameter.OuterLocation.GetY();
		const float innerHeight = instanceParameter.InnerLocation.GetY();
		const float centerHeight = innerHeight + (outerHeight - innerHeight) * instanceParameter.CenterRatio;

		::Effekseer::Color outerColor = instanceParameter.OuterColor;
		::Effekseer::Color innerColor = instanceParameter.InnerColor;
		::Effekseer::Color centerColor = instanceParameter.CenterColor;
		::Effekseer::Color outerColorNext = instanceParameter.OuterColor;
		::Effekseer::Color innerColorNext = instanceParameter.InnerColor;
		::Effekseer::Color centerColorNext = instanceParameter.CenterColor;

		if (parameter.StartingFade > 0)
		{
			outerColor.A = 0;
			innerColor.A = 0;
			centerColor.A = 0;
		}

		const float stepC = cosf(stepAngle);
		const float stepS = sinf(stepAngle);
		float cos_ = cosf(beginAngle);
		float sin_ = sinf(beginAngle);
		::Effekseer::SIMD::Vec3f outerCurrent(cos_ * outerRadius, sin_ * outerRadius, outerHeight);
		::Effekseer::SIMD::Vec3f innerCurrent(cos_ * innerRadius, sin_ * innerRadius, innerHeight);
		::Effekseer::SIMD::Vec3f centerCurrent(cos_ * centerRadius, sin_ * centerRadius, centerHeight);

		float uv0Current = instanceParameter.UV.X;
		const float uv0Step = instanceParameter.UV.Width / parameter.VertexCount;
		const float uv0v1 = instanceParameter.UV.Y;
		const float uv0v2 = uv0v1 + instanceParameter.UV.Height * 0.5f;
		const float uv0v3 = uv0v1 + instanceParameter.UV.Height;
		float uv0texNext = 0.0f;

		float uv1Current = 0.0f;
		const float uv1Step = 1.0f / parameter.VertexCount;
		const float uv1v1 = 0.0f;
		const float uv1v2 = uv1v1 + 0.5f;
		const float uv1v3 = uv1v1 + 1.0f;
		float uv1texNext = 0.0f;

		const int32_t advancedUVNum = 5;

		float advancedUVCurrent[advancedUVNum] =
			{
				instanceParameter.AlphaUV.X,
				instanceParameter.UVDistortionUV.X,
				instanceParameter.BlendUV.X,
				instanceParameter.BlendAlphaUV.X,
				instanceParameter.BlendUVDistortionUV.X};
		const float advancedUVStep[advancedUVNum] =
			{
				instanceParameter.AlphaUV.Width / parameter.VertexCount,
				instanceParameter.UVDistortionUV.Width / parameter.VertexCount,
				instanceParameter.BlendUV.Width / parameter.VertexCount,
				instanceParameter.BlendAlphaUV.Width / parameter.VertexCount,
				instanceParameter.BlendUVDistortionUV.Width / parameter.VertexCount};
		const float advancedUVv1[advancedUVNum] =
			{
				instanceParameter.AlphaUV.Y,
				instanceParameter.UVDistortionUV.Y,
				instanceParameter.BlendUV.Y,
				instanceParameter.BlendAlphaUV.Y,
				instanceParameter.BlendUVDistortionUV.Y};
		const float advancedUVv2[advancedUVNum] =
			{
				advancedUVv1[0] + instanceParameter.AlphaUV.Height * 0.5f,
				advancedUVv1[1] + instanceParameter.UVDistortionUV.Height * 0.5f,
				advancedUVv1[2] + instanceParameter.BlendUV.Height * 0.5f,
				advancedUVv1[3] + instanceParameter.BlendAlphaUV.Height * 0.5f,
				advancedUVv1[4] + instanceParameter.BlendUVDistortionUV.Height * 0.5f};
		const float advancedUVv3[advancedUVNum] =
			{
				advancedUVv1[0] + instanceParameter.AlphaUV.Height,
				advancedUVv1[1] + instanceParameter.UVDistortionUV.Height,
				advancedUVv1[2] + instanceParameter.BlendUV.Height,
				advancedUVv1[3] + instanceParameter.BlendAlphaUV.Height,
				advancedUVv1[4] + instanceParameter.BlendUVDistortionUV.Height};
		float advancedUVtexNext[advancedUVNum] = {0.0f};

		::Effekseer::SIMD::Vec3f outerNext, innerNext, centerNext;

		float currentAngleDegree = 0;
		float fadeStartAngle = parameter.StartingFade;
		float fadeEndingAngle = parameter.EndingFade;

		for (int i = 0; i < singleVertexCount; i += 8)
		{
			float old_c = cos_;
			float old_s = sin_;

			float t;
			t = cos_ * stepC - sin_ * stepS;
			sin_ = sin_ * stepC + cos_ * stepS;
			cos_ = t;

			outerNext = ::Effekseer::SIMD::Vec3f{cos_ * outerRadius, sin_ * outerRadius, outerHeight};
			innerNext = ::Effekseer::SIMD::Vec3f{cos_ * innerRadius, sin_ * innerRadius, innerHeight};
			centerNext = ::Effekseer::SIMD::Vec3f{cos_ * centerRadius, sin_ * centerRadius, centerHeight};

			currentAngleDegree += stepAngleDegree;

			// for floating decimal point error
			currentAngleDegree = Effekseer::Min(currentAngleDegree, circleAngleDegree);
			float alpha = 1.0f;
			if (currentAngleDegree < fadeStartAngle)
			{
				alpha = currentAngleDegree / fadeStartAngle;
			}
			else if (currentAngleDegree > circleAngleDegree - fadeEndingAngle)
			{
				alpha = 1.0f - (currentAngleDegree - (circleAngleDegree - fadeEndingAngle)) / fadeEndingAngle;
			}

			outerColorNext = instanceParameter.OuterColor;
			innerColorNext = instanceParameter.InnerColor;
			centerColorNext = instanceParameter.CenterColor;

			if (alpha != 1.0f)
			{
				outerColorNext.A = static_cast<uint8_t>(outerColorNext.A * alpha);
				innerColorNext.A = static_cast<uint8_t>(innerColorNext.A * alpha);
				centerColorNext.A = static_cast<uint8_t>(centerColorNext.A * alpha);
			}

			uv0texNext = uv0Current + uv0Step;

			StrideView<VERTEX> v(&verteies[i], stride_, 8);
			v[0].Pos = ToStruct(outerCurrent);
			v[0].SetColor(outerColor, FLIP_RGB);
			v[0].UV[0] = uv0Current;
			v[0].UV[1] = uv0v1;

			v[1].Pos = ToStruct(centerCurrent);
			v[1].SetColor(centerColor, FLIP_RGB);
			v[1].UV[0] = uv0Current;
			v[1].UV[1] = uv0v2;

			v[2].Pos = ToStruct(outerNext);
			v[2].SetColor(outerColorNext, FLIP_RGB);
			v[2].UV[0] = uv0texNext;
			v[2].UV[1] = uv0v1;

			v[3].Pos = ToStruct(centerNext);
			v[3].SetColor(centerColorNext, FLIP_RGB);
			v[3].UV[0] = uv0texNext;
			v[3].UV[1] = uv0v2;

			v[4] = v[1];

			v[5].Pos = ToStruct(innerCurrent);
			v[5].SetColor(innerColor, FLIP_RGB);
			v[5].UV[0] = uv0Current;
			v[5].UV[1] = uv0v3;

			v[6] = v[3];

			v[7].Pos = ToStruct(innerNext);
			v[7].SetColor(innerColorNext, FLIP_RGB);
			v[7].UV[0] = uv0texNext;
			v[7].UV[1] = uv0v3;

			for (int32_t uvi = 0; uvi < advancedUVNum; uvi++)
			{
				advancedUVtexNext[uvi] = advancedUVCurrent[uvi] + advancedUVStep[uvi];
			}

			SetVertexAlphaUV(v[0], advancedUVCurrent[0], 0);
			SetVertexAlphaUV(v[0], advancedUVv1[0], 1);

			SetVertexUVDistortionUV(v[0], advancedUVCurrent[1], 0);
			SetVertexUVDistortionUV(v[0], advancedUVv1[1], 1);

			SetVertexBlendUV(v[0], advancedUVCurrent[2], 0);
			SetVertexBlendUV(v[0], advancedUVv1[2], 1);

			SetVertexBlendAlphaUV(v[0], advancedUVCurrent[3], 0);
			SetVertexBlendAlphaUV(v[0], advancedUVv1[3], 1);

			SetVertexBlendUVDistortionUV(v[0], advancedUVCurrent[4], 0);
			SetVertexBlendUVDistortionUV(v[0], advancedUVv1[4], 1);

			SetVertexAlphaUV(v[1], advancedUVCurrent[0], 0);
			SetVertexAlphaUV(v[1], advancedUVv2[0], 1);

			SetVertexUVDistortionUV(v[1], advancedUVCurrent[1], 0);
			SetVertexUVDistortionUV(v[1], advancedUVv2[1], 1);

			SetVertexBlendUV(v[1], advancedUVCurrent[2], 0);
			SetVertexBlendUV(v[1], advancedUVv2[2], 1);

			SetVertexBlendAlphaUV(v[1], advancedUVCurrent[3], 0);
			SetVertexBlendAlphaUV(v[1], advancedUVv2[3], 1);

			SetVertexBlendUVDistortionUV(v[1], advancedUVCurrent[4], 0);
			SetVertexBlendUVDistortionUV(v[1], advancedUVv2[4], 1);

			SetVertexAlphaUV(v[2], advancedUVtexNext[0], 0);
			SetVertexAlphaUV(v[2], advancedUVv1[0], 1);

			SetVertexUVDistortionUV(v[2], advancedUVtexNext[1], 0);
			SetVertexUVDistortionUV(v[2], advancedUVv1[1], 1);

			SetVertexBlendUV(v[2], advancedUVtexNext[2], 0);
			SetVertexBlendUV(v[2], advancedUVv1[2], 1);

			SetVertexBlendAlphaUV(v[2], advancedUVtexNext[3], 0);
			SetVertexBlendAlphaUV(v[2], advancedUVv1[3], 1);

			SetVertexBlendUVDistortionUV(v[2], advancedUVtexNext[4], 0);
			SetVertexBlendUVDistortionUV(v[2], advancedUVv1[4], 1);

			SetVertexAlphaUV(v[3], advancedUVtexNext[0], 0);
			SetVertexAlphaUV(v[3], advancedUVv2[0], 1);

			SetVertexUVDistortionUV(v[3], advancedUVtexNext[1], 0);
			SetVertexUVDistortionUV(v[3], advancedUVv2[1], 1);

			SetVertexBlendUV(v[3], advancedUVtexNext[2], 0);
			SetVertexBlendUV(v[3], advancedUVv2[2], 1);

			SetVertexBlendAlphaUV(v[3], advancedUVtexNext[3], 0);
			SetVertexBlendAlphaUV(v[3], advancedUVv2[3], 1);

			SetVertexBlendUVDistortionUV(v[3], advancedUVtexNext[4], 0);
			SetVertexBlendUVDistortionUV(v[3], advancedUVv2[4], 1);

			v[4] = v[1];

			SetVertexAlphaUV(v[5], advancedUVCurrent[0], 0);
			SetVertexAlphaUV(v[5], advancedUVv3[0], 1);

			SetVertexUVDistortionUV(v[5], advancedUVCurrent[1], 0);
			SetVertexUVDistortionUV(v[5], advancedUVv3[1], 1);

			SetVertexBlendUV(v[5], advancedUVCurrent[2], 0);
			SetVertexBlendUV(v[5], advancedUVv3[2], 1);

			SetVertexBlendAlphaUV(v[5], advancedUVCurrent[3], 0);
			SetVertexBlendAlphaUV(v[5], advancedUVv3[3], 1);

			SetVertexBlendUVDistortionUV(v[5], advancedUVCurrent[4], 0);
			SetVertexBlendUVDistortionUV(v[5], advancedUVv3[4], 1);

			v[6] = v[3];

			SetVertexAlphaUV(v[7], advancedUVtexNext[0], 0);
			SetVertexAlphaUV(v[7], advancedUVv3[0], 1);

			SetVertexUVDistortionUV(v[7], advancedUVtexNext[1], 0);
			SetVertexUVDistortionUV(v[7], advancedUVv3[1], 1);

			SetVertexBlendUV(v[7], advancedUVtexNext[2], 0);
			SetVertexBlendUV(v[7], advancedUVv3[2], 1);

			SetVertexBlendAlphaUV(v[7], advancedUVtexNext[3], 0);
			SetVertexBlendAlphaUV(v[7], advancedUVv3[3], 1);

			SetVertexBlendUVDistortionUV(v[7], advancedUVtexNext[4], 0);
			SetVertexBlendUVDistortionUV(v[7], advancedUVv3[4], 1);

			for (int32_t vi = 0; vi < 8; vi++)
			{
				v[vi].SetFlipbookIndexAndNextRate(instanceParameter.FlipbookIndexAndNextRate);
				v[vi].SetAlphaThreshold(instanceParameter.AlphaThreshold);
			}

			if (VertexNormalRequired<VERTEX>())
			{
				StrideView<VERTEX> vs(&verteies[i], stride_, 8);

				// return back
				float t_b;
				t_b = old_c * (stepC)-old_s * (-stepS);
				auto s_b = old_s * (stepC) + old_c * (-stepS);
				auto c_b = t_b;

				::Effekseer::SIMD::Vec3f outerBefore{c_b * outerRadius, s_b * outerRadius, outerHeight};

				// next
				auto t_n = cos_ * stepC - sin_ * stepS;
				auto s_n = sin_ * stepC + cos_ * stepS;
				auto c_n = t_n;

				::Effekseer::SIMD::Vec3f outerNN;
				outerNN.SetX(c_n * outerRadius);
				outerNN.SetY(s_n * outerRadius);
				outerNN.SetZ(outerHeight);

				::Effekseer::SIMD::Vec3f tangent0 = (outerCurrent - outerBefore).Normalize();
				::Effekseer::SIMD::Vec3f tangent1 = (outerNext - outerCurrent).Normalize();
				::Effekseer::SIMD::Vec3f tangent2 = (outerNN - outerNext).Normalize();

				auto tangentCurrent = (tangent0 + tangent1) / 2.0f;
				auto tangentNext = (tangent1 + tangent2) / 2.0f;

				auto binormalCurrent = v[5].Pos - v[0].Pos;
				auto binormalNext = v[7].Pos - v[2].Pos;

				::Effekseer::SIMD::Vec3f normalCurrent;
				::Effekseer::SIMD::Vec3f normalNext;

				normalCurrent = ::Effekseer::SIMD::Vec3f::Cross(tangentCurrent, binormalCurrent);
				normalNext = ::Effekseer::SIMD::Vec3f::Cross(tangentNext, binormalNext);

				if (!parameter.IsRightHand)
				{
					normalCurrent = -normalCurrent;
					normalNext = -normalNext;
				}

				// rotate directions
				::Effekseer::SIMD::Mat43f matRot = mat43;
				matRot.SetTranslation({0.0f, 0.0f, 0.0f});

				normalCurrent = ::Effekseer::SIMD::Vec3f::Transform(normalCurrent, matRot);
				normalNext = ::Effekseer::SIMD::Vec3f::Transform(normalNext, matRot);
				tangentCurrent = ::Effekseer::SIMD::Vec3f::Transform(tangentCurrent, matRot);
				tangentNext = ::Effekseer::SIMD::Vec3f::Transform(tangentNext, matRot);

				normalCurrent = normalCurrent.Normalize();
				normalNext = normalNext.Normalize();
				tangentCurrent = tangentCurrent.Normalize();
				tangentNext = tangentNext.Normalize();

				const auto packedNormalCurrent = PackVector3DF(normalCurrent);
				const auto packedNormalNext = PackVector3DF(normalNext);
				const auto packedTangentCurrent = PackVector3DF(tangentCurrent);
				const auto packedTangentNext = PackVector3DF(tangentNext);

				vs[0].SetPackedNormal(packedNormalCurrent);
				vs[1].SetPackedNormal(packedNormalCurrent);
				vs[2].SetPackedNormal(packedNormalNext);
				vs[3].SetPackedNormal(packedNormalNext);

				vs[4].SetPackedNormal(packedNormalCurrent);
				vs[5].SetPackedNormal(packedNormalCurrent);
				vs[6].SetPackedNormal(packedNormalNext);
				vs[7].SetPackedNormal(packedNormalNext);

				vs[0].SetPackedTangent(packedTangentCurrent);
				vs[1].SetPackedTangent(packedTangentCurrent);
				vs[2].SetPackedTangent(packedTangentNext);
				vs[3].SetPackedTangent(packedTangentNext);

				vs[4].SetPackedTangent(packedTangentCurrent);
				vs[5].SetPackedTangent(packedTangentCurrent);
				vs[6].SetPackedTangent(packedTangentNext);
				vs[7].SetPackedTangent(packedTangentNext);

				// uv1
				uv1texNext = uv1Current + uv1Step;

				vs[0].SetUV2(uv1Current, uv1v1);
				vs[1].SetUV2(uv1Current, uv1v2);
				vs[2].SetUV2(uv1texNext, uv1v1);
				vs[3].SetUV2(uv1texNext, uv1v2);

				vs[4].SetUV2(uv1Current, uv1v2);

				vs[5].SetUV2(uv1Current, uv1v3);

				vs[6].SetUV2(uv1texNext, uv1v2);

				vs[7].SetUV2(uv1texNext, uv1v3);
			}

			outerCurrent = outerNext;
			innerCurrent = innerNext;
			centerCurrent = centerNext;
			uv0Current = uv0texNext;
			uv1Current = uv1texNext;
			for (int32_t uvi = 0; uvi < advancedUVNum; uvi++)
			{
				advancedUVCurrent[uvi] = advancedUVtexNext[uvi];
			}

			outerColor = outerColorNext;
			innerColor = innerColorNext;
			centerColor = centerColorNext;
		}

		if (CanSingleRendering())
		{
			m_singleRenderingMatrix = mat43;
		}
		else
		{
			TransformVertexes(verteies, singleVertexCount, mat43);
		}

		// custom parameter
		if (customData1Count_ > 0)
		{
			StrideView<float> custom(m_ringBufferData + sizeof(DynamicVertex), stride_, singleVertexCount);
			for (int i = 0; i < singleVertexCount; i++)
			{
				auto c = (float*)(&custom[i]);
				memcpy(c, instanceParameter.CustomData1.data(), sizeof(float) * customData1Count_);
			}
		}

		if (customData2Count_ > 0)
		{
			StrideView<float> custom(
				m_ringBufferData + sizeof(DynamicVertex) + sizeof(float) * customData1Count_, stride_, singleVertexCount);
			for (int i = 0; i < singleVertexCount; i++)
			{
				auto c = (float*)(&custom[i]);
				memcpy(c, instanceParameter.CustomData2.data(), sizeof(float) * customData2Count_);
			}
		}

		m_spriteCount += 2 * parameter.VertexCount;
		m_ringBufferData += stride_ * singleVertexCount;
	}

	void EndRendering_(RENDERER* renderer, const efkRingNodeParam& param, const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (CanSingleRendering())
		{
			::Effekseer::SIMD::Mat44f mat = m_singleRenderingMatrix * renderer->GetCameraMatrix();

			renderer->GetStandardRenderer()->Rendering(mat, renderer->GetProjectionMatrix());
		}

		if (param.DepthParameterPtr->ZSort != Effekseer::ZSortType::None && !CanSingleRendering())
		{
			for (auto& kv : instances_)
			{
				efkVector3D t = kv.Value.SRTMatrix43.GetTranslation();

				Effekseer::SIMD::Vec3f frontDirection = m_renderer->GetCameraFrontDirection();
				if (!param.IsRightHand)
				{
					frontDirection.SetZ(-frontDirection.GetZ());
				}

				kv.Key = Effekseer::SIMD::Vec3f::Dot(t, frontDirection);
			}

			if (param.DepthParameterPtr->ZSort == Effekseer::ZSortType::NormalOrder)
			{
				std::sort(instances_.begin(), instances_.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key < b.Key; });
			}
			else
			{
				std::sort(instances_.begin(), instances_.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key > b.Key; });
			}

			const auto& state = m_renderer->GetStandardRenderer()->GetState();

			for (auto& kv : instances_)
			{
				RenderingInstance(kv.Value, param, state, camera);
			}
		}
	}

public:
	void BeginRendering(const efkRingNodeParam& parameter, int32_t count, void* userData)
	{
		BeginRendering_(m_renderer, count, parameter, userData);
	}

	void Rendering(const efkRingNodeParam& parameter, const efkRingInstanceParam& instanceParameter, void* userData)
	{
		if (m_spriteCount + 2 * parameter.VertexCount > m_renderer->GetSquareMaxCount())
			return;
		Rendering_(parameter, instanceParameter, m_renderer->GetCameraMatrix());
	}

	void EndRendering(const efkRingNodeParam& parameter, void* userData)
	{
		if (m_ringBufferData == nullptr)
			return;

		if (m_spriteCount == 0 && parameter.DepthParameterPtr->ZSort == Effekseer::ZSortType::None)
			return;

		EndRendering_(m_renderer, parameter, m_renderer->GetCameraMatrix());
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_RING_RENDERER_H__