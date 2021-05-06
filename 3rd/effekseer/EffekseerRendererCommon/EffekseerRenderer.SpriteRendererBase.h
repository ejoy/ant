
#ifndef __EFFEKSEERRENDERER_SPRITE_RENDERER_BASE_H__
#define __EFFEKSEERRENDERER_SPRITE_RENDERER_BASE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <Effekseer.h>
#include <algorithm>
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
typedef ::Effekseer::SpriteRenderer::NodeParameter efkSpriteNodeParam;
typedef ::Effekseer::SpriteRenderer::InstanceParameter efkSpriteInstanceParam;
typedef ::Effekseer::SIMD::Vec3f efkVector3D;

template <typename RENDERER, bool FLIP_RGB_FLAG>
class SpriteRendererBase : public ::Effekseer::SpriteRenderer, public ::Effekseer::SIMD::AlignedAllocationPolicy<16>
{
protected:
	RENDERER* m_renderer;
	int32_t m_spriteCount;
	uint8_t* m_ringBufferData;

	struct KeyValue
	{
		float Key;
		efkSpriteInstanceParam Value;
	};

	Effekseer::CustomAlignedVector<KeyValue> instances;
	int32_t vertexCount_ = 0;
	int32_t stride_ = 0;
	int32_t customData1Count_ = 0;
	int32_t customData2Count_ = 0;

public:
	SpriteRendererBase(RENDERER* renderer)
		: m_renderer(renderer)
		, m_spriteCount(0)
		, m_ringBufferData(nullptr)
	{
		// reserve buffers
		instances.reserve(m_renderer->GetSquareMaxCount());
	}

	virtual ~SpriteRendererBase()
	{
	}

protected:
	void RenderingInstance(const efkSpriteInstanceParam& instanceParameter,
						   const efkSpriteNodeParam& parameter,
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

	void BeginRendering_(RENDERER* renderer, int32_t count, const efkSpriteNodeParam& param, void* userData)
	{
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

		renderer->GetStandardRenderer()->UpdateStateAndRenderingIfRequired(state);

		count = (std::min)(count, m_renderer->GetSquareMaxCount());

		renderer->GetStandardRenderer()->BeginRenderingAndRenderingIfRequired(count * 4, stride_, (void*&)m_ringBufferData);
		m_spriteCount = 0;

		vertexCount_ = count * 4;

		instances.clear();
	}

	void Rendering_(const efkSpriteNodeParam& parameter,
					const efkSpriteInstanceParam& instanceParameter,
					const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (parameter.ZSort == Effekseer::ZSortType::None)
		{
			auto cameraMat = m_renderer->GetCameraMatrix();
			const auto& state = m_renderer->GetStandardRenderer()->GetState();

			RenderingInstance(instanceParameter, parameter, state, cameraMat);
		}
		else
		{
			KeyValue kv;
			kv.Value = instanceParameter;
			instances.push_back(kv);
		}
	}

	template <typename VERTEX, bool FLIP_RGB>
	void Rendering_Internal(const efkSpriteNodeParam& parameter,
							const efkSpriteInstanceParam& instanceParameter,
							const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (m_ringBufferData == nullptr)
			return;

		StrideView<VERTEX> verteies(m_ringBufferData, stride_, 4);

		for (int i = 0; i < 4; i++)
		{
			verteies[i].Pos.X = instanceParameter.Positions[i].GetX();
			verteies[i].Pos.Y = instanceParameter.Positions[i].GetY();
			verteies[i].Pos.Z = 0.0f;

			verteies[i].SetColor(instanceParameter.Colors[i], FLIP_RGB);

			verteies[i].SetFlipbookIndexAndNextRate(instanceParameter.FlipbookIndexAndNextRate);
			verteies[i].SetAlphaThreshold(instanceParameter.AlphaThreshold);
		}

		verteies[0].UV[0] = instanceParameter.UV.X;
		verteies[0].UV[1] = instanceParameter.UV.Y + instanceParameter.UV.Height;

		verteies[1].UV[0] = instanceParameter.UV.X + instanceParameter.UV.Width;
		verteies[1].UV[1] = instanceParameter.UV.Y + instanceParameter.UV.Height;

		verteies[2].UV[0] = instanceParameter.UV.X;
		verteies[2].UV[1] = instanceParameter.UV.Y;

		verteies[3].UV[0] = instanceParameter.UV.X + instanceParameter.UV.Width;
		verteies[3].UV[1] = instanceParameter.UV.Y;

		SetVertexAlphaUV(verteies[0], instanceParameter.AlphaUV.X, 0);
		SetVertexAlphaUV(verteies[0], instanceParameter.AlphaUV.Y + instanceParameter.AlphaUV.Height, 1);

		SetVertexAlphaUV(verteies[1], instanceParameter.AlphaUV.X + instanceParameter.AlphaUV.Width, 0);
		SetVertexAlphaUV(verteies[1], instanceParameter.AlphaUV.Y + instanceParameter.AlphaUV.Height, 1);

		SetVertexAlphaUV(verteies[2], instanceParameter.AlphaUV.X, 0);
		SetVertexAlphaUV(verteies[2], instanceParameter.AlphaUV.Y, 1);

		SetVertexAlphaUV(verteies[3], instanceParameter.AlphaUV.X + instanceParameter.AlphaUV.Width, 0);
		SetVertexAlphaUV(verteies[3], instanceParameter.AlphaUV.Y, 1);

		SetVertexUVDistortionUV(verteies[0], instanceParameter.UVDistortionUV.X, 0);
		SetVertexUVDistortionUV(verteies[0], instanceParameter.UVDistortionUV.Y + instanceParameter.UVDistortionUV.Height, 1);

		SetVertexUVDistortionUV(verteies[1], instanceParameter.UVDistortionUV.X + instanceParameter.UVDistortionUV.Width, 0);
		SetVertexUVDistortionUV(verteies[1], instanceParameter.UVDistortionUV.Y + instanceParameter.UVDistortionUV.Height, 1);

		SetVertexUVDistortionUV(verteies[2], instanceParameter.UVDistortionUV.X, 0);
		SetVertexUVDistortionUV(verteies[2], instanceParameter.UVDistortionUV.Y, 1);

		SetVertexUVDistortionUV(verteies[3], instanceParameter.UVDistortionUV.X + instanceParameter.UVDistortionUV.Width, 0);
		SetVertexUVDistortionUV(verteies[3], instanceParameter.UVDistortionUV.Y, 1);

		SetVertexBlendUV(verteies[0], instanceParameter.BlendUV.X, 0);
		SetVertexBlendUV(verteies[0], instanceParameter.BlendUV.Y + instanceParameter.BlendUV.Height, 1);

		SetVertexBlendUV(verteies[1], instanceParameter.BlendUV.X + instanceParameter.BlendUV.Width, 0);
		SetVertexBlendUV(verteies[1], instanceParameter.BlendUV.Y + instanceParameter.BlendUV.Height, 1);

		SetVertexBlendUV(verteies[2], instanceParameter.BlendUV.X, 0);
		SetVertexBlendUV(verteies[2], instanceParameter.BlendUV.Y, 1);

		SetVertexBlendUV(verteies[3], instanceParameter.BlendUV.X + instanceParameter.BlendUV.Width, 0);
		SetVertexBlendUV(verteies[3], instanceParameter.BlendUV.Y, 1);

		SetVertexBlendAlphaUV(verteies[0], instanceParameter.BlendAlphaUV.X, 0);
		SetVertexBlendAlphaUV(verteies[0], instanceParameter.BlendAlphaUV.Y + instanceParameter.BlendAlphaUV.Height, 1);

		SetVertexBlendAlphaUV(verteies[1], instanceParameter.BlendAlphaUV.X + instanceParameter.BlendAlphaUV.Width, 0);
		SetVertexBlendAlphaUV(verteies[1], instanceParameter.BlendAlphaUV.Y + instanceParameter.BlendAlphaUV.Height, 1);

		SetVertexBlendAlphaUV(verteies[2], instanceParameter.BlendAlphaUV.X, 0);
		SetVertexBlendAlphaUV(verteies[2], instanceParameter.BlendAlphaUV.Y, 1);

		SetVertexBlendAlphaUV(verteies[3], instanceParameter.BlendAlphaUV.X + instanceParameter.BlendAlphaUV.Width, 0);
		SetVertexBlendAlphaUV(verteies[3], instanceParameter.BlendAlphaUV.Y, 1);

		SetVertexBlendUVDistortionUV(verteies[0], instanceParameter.BlendUVDistortionUV.X, 0);
		SetVertexBlendUVDistortionUV(verteies[0], instanceParameter.BlendUVDistortionUV.Y + instanceParameter.BlendUVDistortionUV.Height, 1);

		SetVertexBlendUVDistortionUV(verteies[1], instanceParameter.BlendUVDistortionUV.X + instanceParameter.BlendUVDistortionUV.Width, 0);
		SetVertexBlendUVDistortionUV(verteies[1], instanceParameter.BlendUVDistortionUV.Y + instanceParameter.BlendUVDistortionUV.Height, 1);

		SetVertexBlendUVDistortionUV(verteies[2], instanceParameter.BlendUVDistortionUV.X, 0);
		SetVertexBlendUVDistortionUV(verteies[2], instanceParameter.BlendUVDistortionUV.Y, 1);

		SetVertexBlendUVDistortionUV(verteies[3], instanceParameter.BlendUVDistortionUV.X + instanceParameter.BlendUVDistortionUV.Width, 0);
		SetVertexBlendUVDistortionUV(verteies[3], instanceParameter.BlendUVDistortionUV.Y, 1);

		if (VertexUV2Required<VERTEX>())
		{
			StrideView<VERTEX> vs(verteies.pointerOrigin_, stride_, 4);
			vs[0].SetUV2(0.0f, 1.0f);
			vs[1].SetUV2(1.0f, 1.0f);
			vs[2].SetUV2(0.0f, 0.0f);
			vs[3].SetUV2(1.0f, 0.0f);
		}

		if (parameter.Billboard == ::Effekseer::BillboardType::Billboard ||
			parameter.Billboard == ::Effekseer::BillboardType::RotatedBillboard ||
			parameter.Billboard == ::Effekseer::BillboardType::YAxisFixed)
		{
			Effekseer::SIMD::Mat43f mat_rot = Effekseer::SIMD::Mat43f::Identity;
			Effekseer::SIMD::Vec3f s;
			Effekseer::SIMD::Vec3f R;
			Effekseer::SIMD::Vec3f F;

			if (parameter.EnableViewOffset == true)
			{
				Effekseer::SIMD::Mat43f instMat = instanceParameter.SRTMatrix43;

				ApplyViewOffset(instMat, camera, instanceParameter.ViewOffsetDistance);

				CalcBillboard(parameter.Billboard, mat_rot, s, R, F, instMat, m_renderer->GetCameraFrontDirection());
			}
			else
			{
				CalcBillboard(parameter.Billboard, mat_rot, s, R, F, instanceParameter.SRTMatrix43, m_renderer->GetCameraFrontDirection());
			}

			for (int i = 0; i < 4; i++)
			{
				verteies[i].Pos.X = verteies[i].Pos.X * s.GetX();
				verteies[i].Pos.Y = verteies[i].Pos.Y * s.GetY();
			}

			ApplyDepthParameters(mat_rot,
								 m_renderer->GetCameraFrontDirection(),
								 m_renderer->GetCameraPosition(),
								 s,
								 parameter.DepthParameterPtr,
								 parameter.IsRightHand);

			TransformVertexes(verteies, 4, mat_rot);

			if (VertexNormalRequired<VERTEX>())
			{
				if (!parameter.IsRightHand)
				{
					F = -F;
				}

				StrideView<VERTEX> vs(verteies.pointerOrigin_, stride_, 4);
				for (auto i = 0; i < 4; i++)
				{
					vs[i].SetPackedNormal(PackVector3DF(F));
					vs[i].SetPackedTangent(PackVector3DF(R));
				}
			}
		}
		else if (parameter.Billboard == ::Effekseer::BillboardType::Fixed)
		{
			auto mat = instanceParameter.SRTMatrix43;

			if (parameter.EnableViewOffset == true)
			{
				ApplyViewOffset(mat, camera, instanceParameter.ViewOffsetDistance);
			}

			ApplyDepthParameters(mat,
								 m_renderer->GetCameraFrontDirection(),
								 m_renderer->GetCameraPosition(),
								 parameter.DepthParameterPtr,
								 parameter.IsRightHand);

			for (int i = 0; i < 4; i++)
			{
				auto Pos = ::Effekseer::SIMD::Vec3f::Load(&verteies[i].Pos);
				Pos = ::Effekseer::SIMD::Vec3f::Transform(Pos, mat);
				::Effekseer::SIMD::Vec3f::Store(&verteies[i].Pos, Pos);

				if (VertexNormalRequired<VERTEX>())
				{
					StrideView<VERTEX> vs(verteies.pointerOrigin_, stride_, 4);
					auto tangentX = efkVector3D(mat.X.GetX(), mat.Y.GetX(), mat.Z.GetX());
					auto tangentZ = efkVector3D(mat.X.GetZ(), mat.Y.GetZ(), mat.Z.GetZ());
					tangentX = tangentX.Normalize();
					tangentZ = tangentZ.Normalize();

					if (!parameter.IsRightHand)
					{
						tangentZ = -tangentZ;
					}

					vs[i].SetPackedNormal(PackVector3DF(tangentZ));
					vs[i].SetPackedTangent(PackVector3DF(tangentX));
				}
			}
		}

		// custom parameter
		if (customData1Count_ > 0)
		{
			StrideView<float> custom(m_ringBufferData + sizeof(DynamicVertex), stride_, 4);
			for (int i = 0; i < 4; i++)
			{
				auto c = (float*)(&custom[i]);
				memcpy(c, instanceParameter.CustomData1.data(), sizeof(float) * customData1Count_);
			}
		}

		if (customData2Count_ > 0)
		{
			StrideView<float> custom(m_ringBufferData + sizeof(DynamicVertex) + sizeof(float) * customData1Count_, stride_, 4);
			for (int i = 0; i < 4; i++)
			{
				auto c = (float*)(&custom[i]);
				memcpy(c, instanceParameter.CustomData2.data(), sizeof(float) * customData2Count_);
			}
		}

		m_ringBufferData += (stride_ * 4);
		m_spriteCount++;
	}

	void EndRendering_(RENDERER* renderer, const efkSpriteNodeParam& param)
	{
		if (param.ZSort != Effekseer::ZSortType::None)
		{
			for (auto& kv : instances)
			{
				efkVector3D t = kv.Value.SRTMatrix43.GetTranslation();

				auto frontDirection = m_renderer->GetCameraFrontDirection();
				if (!param.IsRightHand)
				{
					frontDirection.Z = -frontDirection.Z;
				}

				kv.Key = Effekseer::SIMD::Vec3f::Dot(t, frontDirection);
			}

			if (param.ZSort == Effekseer::ZSortType::NormalOrder)
			{
				std::sort(instances.begin(), instances.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key < b.Key; });
			}
			else
			{
				std::sort(instances.begin(), instances.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key > b.Key; });
			}

			for (auto& kv : instances)
			{
				auto camera = m_renderer->GetCameraMatrix();
				const auto& state = renderer->GetStandardRenderer()->GetState();

				RenderingInstance(kv.Value, param, state, camera);
			}
		}
	}

public:
	void BeginRendering(const efkSpriteNodeParam& parameter, int32_t count, void* userData) override
	{
		BeginRendering_(m_renderer, count, parameter, userData);
	}

	void Rendering(const efkSpriteNodeParam& parameter, const efkSpriteInstanceParam& instanceParameter, void* userData) override
	{
		if (m_spriteCount == m_renderer->GetSquareMaxCount())
			return;
		Rendering_(parameter, instanceParameter, m_renderer->GetCameraMatrix());
	}

	void EndRendering(const efkSpriteNodeParam& parameter, void* userData) override
	{
		EndRendering_(m_renderer, parameter);
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_SPRITE_RENDERER_H__
