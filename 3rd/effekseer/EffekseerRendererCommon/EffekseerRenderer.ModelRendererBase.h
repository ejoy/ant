
#ifndef __EFFEKSEERRENDERER_MODEL_RENDERER_BASE_H__
#define __EFFEKSEERRENDERER_MODEL_RENDERER_BASE_H__

#include <Effekseer.h>
#include <algorithm>
#include <assert.h>
#include <string.h>
#include <vector>

#include "EffekseerRenderer.CommonUtils.h"
#include "EffekseerRenderer.IndexBufferBase.h"
#include "EffekseerRenderer.RenderStateBase.h"
#include "EffekseerRenderer.Renderer.h"
#include "EffekseerRenderer.VertexBufferBase.h"

namespace EffekseerRenderer
{

typedef ::Effekseer::ModelRenderer::NodeParameter efkModelNodeParam;
typedef ::Effekseer::ModelRenderer::InstanceParameter efkModelInstanceParam;
typedef ::Effekseer::SIMD::Vec3f efkVector3D;

template <int MODEL_COUNT>
struct ModelRendererVertexConstantBuffer
{
	Effekseer::Matrix44 CameraMatrix;
	Effekseer::Matrix44 ModelMatrix[MODEL_COUNT];
	float ModelUV[MODEL_COUNT][4];

	void SetModelFlipbookParameter(float enableInterpolation, float loopType, float divideX, float divideY)
	{
	}

	void SetModelAlphaUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelUVDistortionUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelBlendUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelBlendAlphaUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelBlendUVDistortionUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelFlipbookIndexAndNextRate(int32_t index, float value)
	{
	}

	void SetModelAlphaThreshold(int32_t index, float value)
	{
	}

	float ModelColor[MODEL_COUNT][4];

	float LightDirection[4];
	float LightColor[4];
	float LightAmbientColor[4];
	float UVInversed[4];
};

template <int MODEL_COUNT>
struct ModelRendererAdvancedVertexConstantBuffer
{
	Effekseer::Matrix44 CameraMatrix;
	Effekseer::Matrix44 ModelMatrix[MODEL_COUNT];
	float ModelUV[MODEL_COUNT][4];

	float ModelAlphaUV[MODEL_COUNT][4];

	float ModelUVDistortionUV[MODEL_COUNT][4];

	float ModelBlendUV[MODEL_COUNT][4];

	float ModelBlendAlphaUV[MODEL_COUNT][4];

	float ModelBlendUVDistortionUV[MODEL_COUNT][4];

	struct
	{
		union
		{
			float Buffer[4];

			struct
			{
				float EnableInterpolation;
				float LoopType;
				float DivideX;
				float DivideY;
			};
		};
	} ModelFlipbookParameter;

	float ModelFlipbookIndexAndNextRate[MODEL_COUNT][4];

	float ModelAlphaThreshold[MODEL_COUNT][4];

	void SetModelFlipbookParameter(float enableInterpolation, float loopType, float divideX, float divideY)
	{
		ModelFlipbookParameter.EnableInterpolation = enableInterpolation;
		ModelFlipbookParameter.LoopType = loopType;
		ModelFlipbookParameter.DivideX = divideX;
		ModelFlipbookParameter.DivideY = divideY;
	}

	void SetModelAlphaUV(int32_t index, float x, float y, float w, float h)
	{
		ModelAlphaUV[index][0] = x;
		ModelAlphaUV[index][1] = y;
		ModelAlphaUV[index][2] = w;
		ModelAlphaUV[index][3] = h;
	}

	void SetModelUVDistortionUV(int32_t index, float x, float y, float w, float h)
	{
		ModelUVDistortionUV[index][0] = x;
		ModelUVDistortionUV[index][1] = y;
		ModelUVDistortionUV[index][2] = w;
		ModelUVDistortionUV[index][3] = h;
	}

	void SetModelBlendUV(int32_t index, float x, float y, float w, float h)
	{
		ModelBlendUV[index][0] = x;
		ModelBlendUV[index][1] = y;
		ModelBlendUV[index][2] = w;
		ModelBlendUV[index][3] = h;
	}

	void SetModelBlendAlphaUV(int32_t index, float x, float y, float w, float h)
	{
		ModelBlendAlphaUV[index][0] = x;
		ModelBlendAlphaUV[index][1] = y;
		ModelBlendAlphaUV[index][2] = w;
		ModelBlendAlphaUV[index][3] = h;
	}

	void SetModelBlendUVDistortionUV(int32_t index, float x, float y, float w, float h)
	{
		ModelBlendUVDistortionUV[index][0] = x;
		ModelBlendUVDistortionUV[index][1] = y;
		ModelBlendUVDistortionUV[index][2] = w;
		ModelBlendUVDistortionUV[index][3] = h;
	}

	void SetModelFlipbookIndexAndNextRate(int32_t index, float value)
	{
		ModelFlipbookIndexAndNextRate[index][0] = value;
	}

	void SetModelAlphaThreshold(int32_t index, float value)
	{
		ModelAlphaThreshold[index][0] = value;
	}

	float ModelColor[MODEL_COUNT][4];

	float LightDirection[4];
	float LightColor[4];
	float LightAmbientColor[4];
	float UVInversed[4];
};

template <int MODEL_COUNT>
struct ModelRendererMaterialVertexConstantBuffer
{
	Effekseer::Matrix44 CameraMatrix;
	Effekseer::Matrix44 ModelMatrix[MODEL_COUNT];
	float ModelUV[MODEL_COUNT][4];
	float ModelColor[MODEL_COUNT][4];

	float LightDirection[4];
	float LightColor[4];
	float LightAmbientColor[4];
	float UVInversed[4];

	void SetModelFlipbookParameter(float enableInterpolation, float loopType, float divideX, float divideY)
	{
	}

	void SetModelAlphaUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelUVDistortionUV(int32_t index, float x, float y, float w, float h)
	{
	}

	void SetModelBlendUV(int32_t iondex, float x, float y, float w, float h)
	{
	}

	void SetModelBlendAlphaUV(int32_t iondex, float x, float y, float w, float h)
	{
	}

	void SetModelBlendUVDistortionUV(int32_t iondex, float x, float y, float w, float h)
	{
	}

	void SetModelFlipbookIndexAndNextRate(int32_t index, float value)
	{
	}

	void SetModelAlphaThreshold(int32_t index, float value)
	{
	}
};

enum class ModelRendererVertexType
{
	Instancing,
	Single,
};

class ModelRendererBase : public ::Effekseer::ModelRenderer, public ::Effekseer::SIMD::AlignedAllocationPolicy<16>
{
protected:
	struct KeyValue
	{
		float Key;
		int Value;
	};

	std::vector<KeyValue> keyValues_;

	std::vector<Effekseer::Matrix44> matrixesSorted_;
	std::vector<Effekseer::RectF> uvSorted_;
	std::vector<Effekseer::RectF> alphaUVSorted_;
	std::vector<Effekseer::RectF> uvDistortionUVSorted_;
	std::vector<Effekseer::RectF> blendUVSorted_;
	std::vector<Effekseer::RectF> blendAlphaUVSorted_;
	std::vector<Effekseer::RectF> blendUVDistortionUVSorted_;
	std::vector<float> flipbookIndexAndNextRateSorted_;
	std::vector<float> alphaThresholdSorted_;
	std::vector<float> viewOffsetDistanceSorted_;

	std::vector<Effekseer::Color> colorsSorted_;
	std::vector<int32_t> timesSorted_;
	std::vector<std::array<float, 4>> customData1Sorted_;
	std::vector<std::array<float, 4>> customData2Sorted_;

	std::vector<Effekseer::Matrix44> m_matrixes;
	std::vector<Effekseer::RectF> m_uv;

	std::vector<Effekseer::RectF> m_alphaUV;
	std::vector<Effekseer::RectF> m_uvDistortionUV;
	std::vector<Effekseer::RectF> m_blendUV;
	std::vector<Effekseer::RectF> m_blendAlphaUV;
	std::vector<Effekseer::RectF> m_blendUVDistortionUV;
	std::vector<float> m_flipbookIndexAndNextRate;
	std::vector<float> m_alphaThreshold;
	std::vector<float> m_viewOffsetDistance;

	std::vector<Effekseer::Color> m_colors;
	std::vector<int32_t> m_times;
	std::vector<std::array<float, 4>> customData1_;
	std::vector<std::array<float, 4>> customData2_;

	int32_t customData1Count_ = 0;
	int32_t customData2Count_ = 0;

	ShaderParameterCollector collector_;

	void ColorToFloat4(::Effekseer::Color color, float fc[4])
	{
		fc[0] = color.R / 255.0f;
		fc[1] = color.G / 255.0f;
		fc[2] = color.B / 255.0f;
		fc[3] = color.A / 255.0f;
	}

	std::array<float, 4> ColorToFloat4(::Effekseer::Color color)
	{
		std::array<float, 4> fc;
		fc[0] = color.R / 255.0f;
		fc[1] = color.G / 255.0f;
		fc[2] = color.B / 255.0f;
		fc[3] = color.A / 255.0f;
		return fc;
	}

	void VectorToFloat4(const ::Effekseer::SIMD::Vec3f& v, float fc[4])
	{
		::Effekseer::SIMD::Float4::Store3(fc, v.s);
		fc[3] = 1.0f;
	}

	void VectorToFloat4(const ::Effekseer::SIMD::Vec3f& v, std::array<float, 4>& fc)
	{
		::Effekseer::SIMD::Float4::Store3(fc.data(), v.s);
		fc[3] = 1.0f;
	}

	ModelRendererBase()
	{
	}

	template <typename RENDERER>
	void GetInversedFlags(RENDERER* renderer, std::array<float, 4>& uvInversed, std::array<float, 4>& uvInversedBack)
	{
		if (renderer->GetTextureUVStyle() == UVStyle::VerticalFlipped)
		{
			uvInversed[0] = 1.0f;
			uvInversed[1] = -1.0f;
		}
		else
		{
			uvInversed[0] = 0.0f;
			uvInversed[1] = 1.0f;
		}

		if (renderer->GetBackgroundTextureUVStyle() == UVStyle::VerticalFlipped)
		{
			uvInversedBack[0] = 1.0f;
			uvInversedBack[1] = -1.0f;
		}
		else
		{
			uvInversedBack[0] = 0.0f;
			uvInversedBack[1] = 1.0f;
		}
	}

	template <typename RENDERER>
	void SortTemporaryValues(RENDERER* renderer, const efkModelNodeParam& param)
	{
		if (param.DepthParameterPtr->ZSort != Effekseer::ZSortType::None)
		{
			keyValues_.resize(m_matrixes.size());
			for (size_t i = 0; i < keyValues_.size(); i++)
			{
				efkVector3D t(m_matrixes[i].Values[3][0], m_matrixes[i].Values[3][1], m_matrixes[i].Values[3][2]);

				auto frontDirection = renderer->GetCameraFrontDirection();
				if (!param.IsRightHand)
				{
					frontDirection.Z = -frontDirection.Z;
				}

				keyValues_[i].Key = Effekseer::SIMD::Vec3f::Dot(t, frontDirection);
				keyValues_[i].Value = static_cast<int32_t>(i);
			}

			if (param.DepthParameterPtr->ZSort == Effekseer::ZSortType::NormalOrder)
			{
				std::sort(keyValues_.begin(), keyValues_.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key < b.Key; });
			}
			else
			{
				std::sort(keyValues_.begin(), keyValues_.end(), [](const KeyValue& a, const KeyValue& b) -> bool { return a.Key > b.Key; });
			}

			matrixesSorted_.resize(m_matrixes.size());
			uvSorted_.resize(m_matrixes.size());
			alphaUVSorted_.resize(m_matrixes.size());
			uvDistortionUVSorted_.resize(m_matrixes.size());
			blendUVSorted_.resize(m_matrixes.size());
			blendAlphaUVSorted_.resize(m_matrixes.size());
			blendUVDistortionUVSorted_.resize(m_matrixes.size());
			flipbookIndexAndNextRateSorted_.resize(m_matrixes.size());
			alphaThresholdSorted_.resize(m_matrixes.size());
			viewOffsetDistanceSorted_.resize(m_matrixes.size());
			colorsSorted_.resize(m_matrixes.size());
			timesSorted_.resize(m_matrixes.size());

			if (customData1Count_ > 0)
			{
				customData1Sorted_.resize(m_matrixes.size());
			}

			if (customData2Count_ > 0)
			{
				customData2Sorted_.resize(m_matrixes.size());
			}

			for (size_t i = 0; i < keyValues_.size(); i++)
			{
				matrixesSorted_[keyValues_[i].Value] = m_matrixes[i];
				uvSorted_[keyValues_[i].Value] = m_uv[i];
				alphaUVSorted_[keyValues_[i].Value] = m_alphaUV[i];
				uvDistortionUVSorted_[keyValues_[i].Value] = m_uvDistortionUV[i];
				blendUVSorted_[keyValues_[i].Value] = m_blendUV[i];
				blendAlphaUVSorted_[keyValues_[i].Value] = m_blendAlphaUV[i];
				blendUVDistortionUVSorted_[keyValues_[i].Value] = m_blendUVDistortionUV[i];
				flipbookIndexAndNextRateSorted_[keyValues_[i].Value] = m_flipbookIndexAndNextRate[i];
				alphaThresholdSorted_[keyValues_[i].Value] = m_alphaThreshold[i];
				viewOffsetDistanceSorted_[keyValues_[i].Value] = m_viewOffsetDistance[i];
				colorsSorted_[keyValues_[i].Value] = m_colors[i];
				timesSorted_[keyValues_[i].Value] = m_times[i];
			}

			if (customData1Count_ > 0)
			{
				for (size_t i = 0; i < keyValues_.size(); i++)
				{
					customData1Sorted_[keyValues_[i].Value] = customData1_[i];
				}
			}

			if (customData2Count_ > 0)
			{
				for (size_t i = 0; i < keyValues_.size(); i++)
				{
					customData2Sorted_[keyValues_[i].Value] = customData2_[i];
				}
			}

			m_matrixes = matrixesSorted_;
			m_uv = uvSorted_;
			m_alphaUV = alphaUVSorted_;
			m_uvDistortionUV = uvDistortionUVSorted_;
			m_blendUV = blendUVSorted_;
			m_blendAlphaUV = blendAlphaUVSorted_;
			m_blendUVDistortionUV = blendUVDistortionUVSorted_;
			m_flipbookIndexAndNextRate = flipbookIndexAndNextRateSorted_;
			m_alphaThreshold = alphaThresholdSorted_;
			m_viewOffsetDistance = viewOffsetDistanceSorted_;
			m_colors = colorsSorted_;
			m_times = timesSorted_;
			customData1_ = customData1Sorted_;
			customData2_ = customData2Sorted_;
		}
	}

	template <typename RENDERER, typename SHADER, int InstanceCount>
	void StoreFileUniform(RENDERER* renderer,
						  SHADER* shader_,
						  Effekseer::MaterialRef material,
						  Effekseer::MaterialRenderData* materialRenderData,
						  const efkModelNodeParam& param,
						  int32_t renderPassInd,
						  float*& cutomData1Ptr,
						  float*& cutomData2Ptr)
	{
		std::array<float, 4> uvInversed;
		std::array<float, 4> uvInversedBack;
		cutomData1Ptr = nullptr;
		cutomData2Ptr = nullptr;

		GetInversedFlags(renderer, uvInversed, uvInversedBack);

		std::array<float, 4> uvInversedMaterial;
		uvInversedMaterial[0] = uvInversed[0];
		uvInversedMaterial[1] = uvInversed[1];
		uvInversedMaterial[2] = uvInversedBack[0];
		uvInversedMaterial[3] = uvInversedBack[1];

		// camera
		float cameraPosition[4];
		::Effekseer::SIMD::Vec3f cameraPosition3 = renderer->GetCameraPosition();
		VectorToFloat4(cameraPosition3, cameraPosition);

		// time
		std::array<float, 4> predefined_uniforms;
		predefined_uniforms.fill(0.5f);
		predefined_uniforms[0] = renderer->GetTime();
		predefined_uniforms[1] = param.Magnification;

		// vs
		int32_t vsOffset = sizeof(Effekseer::Matrix44) + (sizeof(Effekseer::Matrix44) + sizeof(float) * 4 * 2) * InstanceCount;

		renderer->SetVertexBufferToShader(uvInversedMaterial.data(), sizeof(float) * 4, vsOffset);
		vsOffset += (sizeof(float) * 4);

		renderer->SetVertexBufferToShader(predefined_uniforms.data(), sizeof(float) * 4, vsOffset);
		vsOffset += (sizeof(float) * 4);

		renderer->SetVertexBufferToShader(cameraPosition, sizeof(float) * 4, vsOffset);
		vsOffset += (sizeof(float) * 4);

		// vs - custom data
		if (customData1Count_ > 0)
		{
			cutomData1Ptr = (float*)((uint8_t*)shader_->GetVertexConstantBuffer() + vsOffset);
			vsOffset += (sizeof(float) * 4) * InstanceCount;
		}

		if (customData2Count_ > 0)
		{
			cutomData2Ptr = (float*)((uint8_t*)shader_->GetVertexConstantBuffer() + vsOffset);
			vsOffset += (sizeof(float) * 4) * InstanceCount;
		}

		for (size_t i = 0; i < materialRenderData->MaterialUniforms.size(); i++)
		{
			renderer->SetVertexBufferToShader(materialRenderData->MaterialUniforms[i].data(), sizeof(float) * 4, vsOffset);
			vsOffset += (sizeof(float) * 4);
		}

		// ps
		int32_t psOffset = 0;
		renderer->SetPixelBufferToShader(uvInversedMaterial.data(), sizeof(float) * 4, psOffset);
		psOffset += (sizeof(float) * 4);

		renderer->SetPixelBufferToShader(predefined_uniforms.data(), sizeof(float) * 4, psOffset);
		psOffset += (sizeof(float) * 4);

		renderer->SetPixelBufferToShader(cameraPosition, sizeof(float) * 4, psOffset);
		psOffset += (sizeof(float) * 4);

		::Effekseer::Backend::TextureRef depthTexture = nullptr;
		::EffekseerRenderer::DepthReconstructionParameter reconstructionParam;
		renderer->GetImpl()->GetDepth(depthTexture, reconstructionParam);

		SoftParticleParameter softParticleParam;

		softParticleParam.SetParam(
			0.0f,
			0.0f,
			0.0f,
			param.Maginification,
			reconstructionParam.DepthBufferScale,
			reconstructionParam.DepthBufferOffset,
			reconstructionParam.ProjectionMatrix33,
			reconstructionParam.ProjectionMatrix34,
			reconstructionParam.ProjectionMatrix43,
			reconstructionParam.ProjectionMatrix44);

		renderer->SetPixelBufferToShader(softParticleParam.reconstructionParam1.data(), sizeof(float) * 4, psOffset);
		psOffset += (sizeof(float) * 4);

		renderer->SetPixelBufferToShader(softParticleParam.reconstructionParam2.data(), sizeof(float) * 4, psOffset);
		psOffset += (sizeof(float) * 4);

		// shader model
		material = param.EffectPointer->GetMaterial(materialRenderData->MaterialIndex);

		if (material->ShadingModel == ::Effekseer::ShadingModelType::Lit)
		{
			float lightDirection[4];
			float lightColor[4];
			float lightAmbientColor[4];

			::Effekseer::SIMD::Vec3f lightDirection3 = renderer->GetLightDirection();
			lightDirection3 = lightDirection3.Normalize();

			VectorToFloat4(lightDirection3, lightDirection);
			ColorToFloat4(renderer->GetLightColor(), lightColor);
			ColorToFloat4(renderer->GetLightAmbientColor(), lightAmbientColor);

			renderer->SetPixelBufferToShader(lightDirection, sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			renderer->SetPixelBufferToShader(lightColor, sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			renderer->SetPixelBufferToShader(lightAmbientColor, sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);
		}

		// refraction
		if (material->RefractionModelUserPtr != nullptr && renderPassInd == 0)
		{
			auto mat = renderer->GetCameraMatrix();
			renderer->SetPixelBufferToShader(&mat, sizeof(float) * 16, psOffset);
			psOffset += (sizeof(float) * 16);
		}

		for (size_t i = 0; i < materialRenderData->MaterialUniforms.size(); i++)
		{
			renderer->SetPixelBufferToShader(materialRenderData->MaterialUniforms[i].data(), sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);
		}
	}

	template <typename RENDERER, typename SHADER, int InstanceCount, typename VertexConstantBufferType, bool REQUIRE_ADVANCED_DATA, bool DISTORTION>
	void StoreFixedUniforms(RENDERER* renderer,
							SHADER* shader_,
							const efkModelNodeParam& param)
	{
		VertexConstantBufferType* vcb = (VertexConstantBufferType*)shader_->GetVertexConstantBuffer();
		std::array<float, 4> uvInversed;
		std::array<float, 4> uvInversedBack;

		GetInversedFlags(renderer, uvInversed, uvInversedBack);

		vcb->UVInversed[0] = uvInversed[0];
		vcb->UVInversed[1] = uvInversed[1];

		::Effekseer::Backend::TextureRef depthTexture = nullptr;
		::EffekseerRenderer::DepthReconstructionParameter reconstructionParam;
		renderer->GetImpl()->GetDepth(depthTexture, reconstructionParam);

		if (DISTORTION)
		{
			auto pcb = (PixelConstantBufferDistortion*)shader_->GetPixelConstantBuffer();
			pcb->DistortionIntencity[0] = param.BasicParameterPtr->DistortionIntensity;

			pcb->UVInversedBack[0] = uvInversedBack[0];
			pcb->UVInversedBack[1] = uvInversedBack[1];

			pcb->FlipbookParam.EnableInterpolation = static_cast<float>(param.BasicParameterPtr->EnableInterpolation);
			pcb->FlipbookParam.InterpolationType = static_cast<float>(param.BasicParameterPtr->InterpolationType);

			pcb->UVDistortionParam.Intensity = param.BasicParameterPtr->UVDistortionIntensity;
			pcb->UVDistortionParam.BlendIntensity = param.BasicParameterPtr->BlendUVDistortionIntensity;
			pcb->UVDistortionParam.UVInversed[0] = uvInversed[0];
			pcb->UVDistortionParam.UVInversed[1] = uvInversed[1];

			pcb->BlendTextureParam.BlendType = static_cast<float>(param.BasicParameterPtr->TextureBlendType);

			pcb->SoftParticleParam.SetParam(
				param.BasicParameterPtr->SoftParticleDistanceFar,
				param.BasicParameterPtr->SoftParticleDistanceNear,
				param.BasicParameterPtr->SoftParticleDistanceNearOffset,
				param.Maginification,
				reconstructionParam.DepthBufferScale,
				reconstructionParam.DepthBufferOffset,
				reconstructionParam.ProjectionMatrix33,
				reconstructionParam.ProjectionMatrix34,
				reconstructionParam.ProjectionMatrix43,
				reconstructionParam.ProjectionMatrix44);
		}
		else
		{
			auto pcb = (PixelConstantBuffer*)shader_->GetPixelConstantBuffer();

			// specify predefined parameters
			if (param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::Lighting)
			{
				::Effekseer::SIMD::Vec3f lightDirection = renderer->GetLightDirection();
				lightDirection = lightDirection.Normalize();
				VectorToFloat4(lightDirection, vcb->LightDirection);
				VectorToFloat4(lightDirection, pcb->LightDirection);
			}

			{
				ColorToFloat4(renderer->GetLightColor(), vcb->LightColor);
				pcb->LightColor = ColorToFloat4(renderer->GetLightColor());
			}

			{
				ColorToFloat4(renderer->GetLightAmbientColor(), vcb->LightAmbientColor);
				pcb->LightAmbientColor = ColorToFloat4(renderer->GetLightAmbientColor());
			}

			pcb->SetEmissiveScaling(static_cast<float>(param.BasicParameterPtr->EmissiveScaling));

			if (REQUIRE_ADVANCED_DATA)
			{
				pcb->SetModelFlipbookParameter(param.BasicParameterPtr->EnableInterpolation, static_cast<float>(param.BasicParameterPtr->InterpolationType));
				pcb->SetModelUVDistortionParameter(param.BasicParameterPtr->UVDistortionIntensity, param.BasicParameterPtr->BlendUVDistortionIntensity, {uvInversed[0], uvInversed[1]});
				pcb->SetModelBlendTextureParameter(static_cast<float>(param.BasicParameterPtr->TextureBlendType));

				::Effekseer::Vector3D CameraFront = renderer->GetCameraFrontDirection();

				if (!param.IsRightHand)
				{
					CameraFront = -CameraFront;
				}

				pcb->SetCameraFrontDirection(-CameraFront.X, -CameraFront.Y, -CameraFront.Z);
				pcb->SetFalloffParameter(
					static_cast<float>(param.EnableFalloff),
					static_cast<float>(param.FalloffParam.ColorBlendType),
					static_cast<float>(param.FalloffParam.Pow),
					ColorToFloat4(param.FalloffParam.BeginColor),
					ColorToFloat4(param.FalloffParam.EndColor));

				pcb->SetEdgeParameter(ColorToFloat4(Effekseer::Color(
										  param.BasicParameterPtr->EdgeColor[0],
										  param.BasicParameterPtr->EdgeColor[1],
										  param.BasicParameterPtr->EdgeColor[2],
										  param.BasicParameterPtr->EdgeColor[3])),
									  param.BasicParameterPtr->EdgeThreshold,
									  static_cast<float>(param.BasicParameterPtr->EdgeColorScaling));
			}

			pcb->SoftParticleParam.SetParam(
				param.BasicParameterPtr->SoftParticleDistanceFar,
				param.BasicParameterPtr->SoftParticleDistanceNear,
				param.BasicParameterPtr->SoftParticleDistanceNearOffset,
				param.Maginification,
				reconstructionParam.DepthBufferScale,
				reconstructionParam.DepthBufferOffset,
				reconstructionParam.ProjectionMatrix33,
				reconstructionParam.ProjectionMatrix34,
				reconstructionParam.ProjectionMatrix43,
				reconstructionParam.ProjectionMatrix44);

			pcb->UVInversedBack[0] = uvInversedBack[0];
			pcb->UVInversedBack[1] = uvInversedBack[1];
		}

		vcb->CameraMatrix = renderer->GetCameraProjectionMatrix();

		vcb->SetModelFlipbookParameter(static_cast<float>(param.BasicParameterPtr->EnableInterpolation),
									   static_cast<float>(param.BasicParameterPtr->UVLoopType),
									   static_cast<float>(param.BasicParameterPtr->FlipbookDivideX),
									   static_cast<float>(param.BasicParameterPtr->FlipbookDivideY));
	}

public:
	ModelRendererVertexType VertexType = ModelRendererVertexType::Single;

	virtual ~ModelRendererBase()
	{
	}

	template <typename RENDERER>
	void BeginRendering_(RENDERER* renderer, const efkModelNodeParam& parameter, int32_t count, void* userData)
	{
		keyValues_.clear();

		m_matrixes.clear();
		m_uv.clear();
		m_alphaUV.clear();
		m_uvDistortionUV.clear();
		m_blendUV.clear();
		m_blendAlphaUV.clear();
		m_blendUVDistortionUV.clear();
		m_flipbookIndexAndNextRate.clear();
		m_alphaThreshold.clear();
		m_viewOffsetDistance.clear();
		m_colors.clear();
		m_times.clear();
		customData1_.clear();
		customData2_.clear();

		matrixesSorted_.clear();
		uvSorted_.clear();
		alphaUVSorted_.clear();
		uvDistortionUVSorted_.clear();
		blendUVSorted_.clear();
		blendAlphaUVSorted_.clear();
		blendUVDistortionUVSorted_.clear();
		flipbookIndexAndNextRateSorted_.clear();
		alphaThresholdSorted_.clear();
		viewOffsetDistanceSorted_.clear();
		colorsSorted_.clear();
		timesSorted_.clear();
		customData1Sorted_.clear();
		customData2Sorted_.clear();

		if (parameter.BasicParameterPtr->MaterialType == ::Effekseer::RendererMaterialType::File &&
			parameter.BasicParameterPtr->MaterialRenderDataPtr != nullptr &&
			parameter.BasicParameterPtr->MaterialRenderDataPtr->MaterialIndex >= 0 &&
			parameter.EffectPointer->GetMaterial(parameter.BasicParameterPtr->MaterialRenderDataPtr->MaterialIndex) != nullptr)
		{
			auto material = parameter.EffectPointer->GetMaterial(parameter.BasicParameterPtr->MaterialRenderDataPtr->MaterialIndex);
			customData1Count_ = material->CustomData1;
			customData2Count_ = material->CustomData2;
		}
		else
		{
			customData1Count_ = 0;
			customData2Count_ = 0;
		}

		renderer->GetStandardRenderer()->ResetAndRenderingIfRequired();

		collector_ = ShaderParameterCollector();
		collector_.Collect(renderer, parameter.EffectPointer, parameter.BasicParameterPtr, parameter.EnableFalloff, renderer->GetImpl()->isSoftParticleEnabled);
	}

	template <typename RENDERER>
	void Rendering_(RENDERER* renderer, const efkModelNodeParam& parameter, const efkModelInstanceParam& instanceParameter, void* userData)
	{
		::Effekseer::BillboardType btype = parameter.Billboard;
		Effekseer::SIMD::Mat44f mat44;

		if (btype == ::Effekseer::BillboardType::Fixed)
		{
			mat44 = instanceParameter.SRTMatrix43;
		}
		else
		{
			Effekseer::SIMD::Mat43f mat43;
			Effekseer::SIMD::Vec3f s;
			Effekseer::SIMD::Vec3f R;
			Effekseer::SIMD::Vec3f F;

			CalcBillboard(btype, mat43, s, R, F, instanceParameter.SRTMatrix43, renderer->GetCameraFrontDirection());

			mat44 = ::Effekseer::SIMD::Mat43f::Scaling(s) * mat43;
		}

		if (parameter.Magnification != 1.0f)
		{
			mat44 = Effekseer::SIMD::Mat44f::Scaling(::Effekseer::SIMD::Vec3f(parameter.Magnification)) * mat44;
		}

		if (!parameter.IsRightHand)
		{
			mat44 = Effekseer::SIMD::Mat44f::Scaling(1.0f, 1.0f, -1.0f) * mat44;
		}

		m_matrixes.push_back(ToStruct(mat44));
		m_uv.push_back(instanceParameter.UV);
		m_alphaUV.push_back(instanceParameter.AlphaUV);
		m_uvDistortionUV.push_back(instanceParameter.UVDistortionUV);
		m_blendUV.push_back(instanceParameter.BlendUV);
		m_blendAlphaUV.push_back(instanceParameter.BlendAlphaUV);
		m_blendUVDistortionUV.push_back(instanceParameter.BlendUVDistortionUV);
		m_flipbookIndexAndNextRate.push_back(instanceParameter.FlipbookIndexAndNextRate);
		m_alphaThreshold.push_back(instanceParameter.AlphaThreshold);
		m_viewOffsetDistance.push_back(instanceParameter.ViewOffsetDistance);
		m_colors.push_back(instanceParameter.AllColor);
		m_times.push_back(instanceParameter.Time);

		if (customData1Count_ > 0)
		{
			customData1_.push_back(instanceParameter.CustomData1);
		}

		if (customData2Count_ > 0)
		{
			customData2_.push_back(instanceParameter.CustomData2);
		}

		//parameter.BasicParameterPtr
	}

	template <typename RENDERER, typename SHADER, typename MODEL, bool Instancing, int InstanceCount>
	void EndRendering_(RENDERER* renderer,
					   SHADER* advanced_shader_lit,
					   SHADER* advanced_shader_unlit,
					   SHADER* advanced_shader_distortion,
					   SHADER* shader_lit,
					   SHADER* shader_unlit,
					   SHADER* shader_distortion,
					   const efkModelNodeParam& param,
					   void* userData)
	{
		if (m_matrixes.size() == 0)
			return;
		if (param.ModelIndex < 0)
			return;

		int32_t renderPassCount = 1;

		if (param.BasicParameterPtr->MaterialRenderDataPtr != nullptr && param.BasicParameterPtr->MaterialRenderDataPtr->MaterialIndex >= 0)
		{
			auto material = param.EffectPointer->GetMaterial(param.BasicParameterPtr->MaterialRenderDataPtr->MaterialIndex);
			if (material != nullptr && material->IsRefractionRequired)
			{
				// refraction, standard
				renderPassCount = 2;
			}
		}

		// sort
		SortTemporaryValues(renderer, param);

		for (int32_t renderPassInd = 0; renderPassInd < renderPassCount; renderPassInd++)
		{
			Effekseer::MaterialRenderData* materialRenderData = param.BasicParameterPtr->MaterialRenderDataPtr;

			if (materialRenderData != nullptr && materialRenderData->MaterialIndex >= 0 &&
				param.EffectPointer->GetMaterial(materialRenderData->MaterialIndex) != nullptr)
			{
				RenderPass<RENDERER, SHADER, MODEL, Instancing, InstanceCount, ModelRendererMaterialVertexConstantBuffer<InstanceCount>, false>(
					renderer, advanced_shader_lit, advanced_shader_unlit, advanced_shader_distortion, shader_lit, shader_unlit, shader_distortion, param, renderPassInd, userData);
			}
			else
			{
				if (collector_.DoRequireAdvancedRenderer())
				{
					RenderPass<RENDERER, SHADER, MODEL, Instancing, InstanceCount, ModelRendererAdvancedVertexConstantBuffer<InstanceCount>, true>(
						renderer, advanced_shader_lit, advanced_shader_unlit, advanced_shader_distortion, shader_lit, shader_unlit, shader_distortion, param, renderPassInd, userData);
				}
				else
				{
					RenderPass<RENDERER, SHADER, MODEL, Instancing, InstanceCount, ModelRendererVertexConstantBuffer<InstanceCount>, false>(
						renderer, advanced_shader_lit, advanced_shader_unlit, advanced_shader_distortion, shader_lit, shader_unlit, shader_distortion, param, renderPassInd, userData);
				}
			}
		}
	}

	template <typename RENDERER, typename SHADER, typename MODEL, bool Instancing, int InstanceCount, typename VertexConstantBufferType, bool REQUIRE_ADVANCED_DATA>
	void RenderPass(RENDERER* renderer,
					SHADER* advanced_shader_lit,
					SHADER* advanced_shader_unlit,
					SHADER* advanced_shader_distortion,
					SHADER* shader_lit,
					SHADER* shader_unlit,
					SHADER* shader_distortion,
					const efkModelNodeParam& param,
					int32_t renderPassInd,
					void* userData)
	{
		if (m_matrixes.size() == 0)
			return;
		if (param.ModelIndex < 0)
			return;

		::Effekseer::RefPtr<MODEL> model;

		if (param.IsProceduralMode)
		{
			model = param.EffectPointer->GetProceduralModel(param.ModelIndex);
		}
		else
		{
			model = param.EffectPointer->GetModel(param.ModelIndex);
		}

		if (model == nullptr)
			return;

		auto isBackgroundRequired = collector_.IsBackgroundRequiredOnFirstPass && renderPassInd == 0;

		if (isBackgroundRequired)
		{
			auto callback = renderer->GetDistortingCallback();
			if (callback != nullptr)
			{
				if (!callback->OnDistorting(renderer))
				{
					return;
				}
			}
		}

		auto distortion = param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::BackDistortion;

		if (isBackgroundRequired && renderer->GetBackground() == 0)
			return;

		if (isBackgroundRequired)
		{
			collector_.Textures[collector_.BackgroundIndex] = renderer->GetBackground();
		}

		::Effekseer::Backend::TextureRef depthTexture = nullptr;
		::EffekseerRenderer::DepthReconstructionParameter reconstructionParam;
		renderer->GetImpl()->GetDepth(depthTexture, reconstructionParam);

		if (collector_.IsDepthRequired)
		{
			if (depthTexture == nullptr || (param.BasicParameterPtr->SoftParticleDistanceFar == 0.0f &&
											param.BasicParameterPtr->SoftParticleDistanceNear == 0.0f &&
											param.BasicParameterPtr->SoftParticleDistanceNearOffset == 0.0f &&
											collector_.ShaderType != RendererShaderType::Material))
			{
				depthTexture = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
			}

			collector_.Textures[collector_.DepthIndex] = depthTexture;
		}

		// select shader
		Effekseer::MaterialRenderData* materialRenderData = param.BasicParameterPtr->MaterialRenderDataPtr;
		// materialRenderData = nullptr;
		Effekseer::MaterialRef material = nullptr;
		SHADER* shader_ = nullptr;
		bool renderDistortedBackground = false;

		if (materialRenderData != nullptr && materialRenderData->MaterialIndex >= 0 &&
			param.EffectPointer->GetMaterial(materialRenderData->MaterialIndex) != nullptr)
		{
			material = param.EffectPointer->GetMaterial(materialRenderData->MaterialIndex);

			if (material != nullptr && material->IsRefractionRequired)
			{
				if (renderPassInd == 0)
				{
					shader_ = (SHADER*)material->RefractionModelUserPtr;
					renderDistortedBackground = true;
				}
				else
				{
					shader_ = (SHADER*)material->ModelUserPtr;
				}
			}
			else
			{
				shader_ = (SHADER*)material->ModelUserPtr;
			}

			// validate
			if (shader_ == nullptr)
			{
				return;
			}
		}
		else
		{
			if (collector_.DoRequireAdvancedRenderer())
			{
				if (distortion)
				{
					shader_ = advanced_shader_distortion;
				}
				else if (param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::Lighting)
				{
					shader_ = advanced_shader_lit;
				}
				else
				{
					shader_ = advanced_shader_unlit;
				}
			}
			else
			{
				if (distortion)
				{
					shader_ = shader_distortion;
				}
				else if (param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::Lighting)
				{
					shader_ = shader_lit;
				}
				else
				{
					shader_ = shader_unlit;
				}
			}
		}

		RenderStateBase::State& state = renderer->GetRenderState()->Push();
		state.DepthTest = param.ZTest;
		state.DepthWrite = param.ZWrite;
		state.AlphaBlend = param.BasicParameterPtr->AlphaBlend;
		state.CullingType = param.Culling;

		if (renderDistortedBackground)
		{
			state.AlphaBlend = ::Effekseer::AlphaBlendType::Blend;
		}

		renderer->BeginShader(shader_);

		for (int32_t i = 0; i < collector_.TextureCount; i++)
		{
			state.TextureFilterTypes[i] = collector_.TextureFilterTypes[i];
			state.TextureWrapTypes[i] = collector_.TextureWrapTypes[i];
		}

		renderer->SetTextures(shader_, collector_.Textures.data(), collector_.TextureCount);

		renderer->GetRenderState()->Update(distortion);

		VertexConstantBufferType* vcb = (VertexConstantBufferType*)shader_->GetVertexConstantBuffer();

		float* cutomData1Ptr = nullptr;
		float* cutomData2Ptr = nullptr;

		if (materialRenderData != nullptr && material != nullptr)
		{
			StoreFileUniform<RENDERER, SHADER, InstanceCount>(
				renderer, shader_, material, materialRenderData, param, renderPassInd, cutomData1Ptr, cutomData2Ptr);

			vcb->CameraMatrix = renderer->GetCameraProjectionMatrix();
		}
		else
		{
			if (distortion)
			{
				StoreFixedUniforms<RENDERER, SHADER, InstanceCount, VertexConstantBufferType, REQUIRE_ADVANCED_DATA, true>(renderer, shader_, param);
			}
			else
			{
				StoreFixedUniforms<RENDERER, SHADER, InstanceCount, VertexConstantBufferType, REQUIRE_ADVANCED_DATA, false>(renderer, shader_, param);
			}
		}

		renderer->GetImpl()->CurrentRenderingUserData = param.UserData;
		renderer->GetImpl()->CurrentHandleUserData = userData;

		// Check time
		auto stTime0 = m_times[0] % model->GetFrameCount();
		auto isTimeSame = true;

		for (auto t : m_times)
		{
			t = t % model->GetFrameCount();
			if (t != stTime0)
			{
				isTimeSame = false;
				break;
			}
		}

		if (Instancing && isTimeSame)
		{
			//auto& imodel = model->InternalModels[stTime0];

			// Invalid unless layout is set after buffer
			renderer->SetVertexBuffer(model->GetVertexBuffer(stTime0), sizeof(Effekseer::Model::Vertex));

			int32_t indexPerFace = 3;
			if (renderer->GetRenderMode() == Effekseer::RenderMode::Wireframe)
			{
				renderer->SetIndexBuffer(model->GetWireIndexBuffer(stTime0));
				indexPerFace = 6;
			}
			else
			{
				renderer->SetIndexBuffer(model->GetIndexBuffer(stTime0));
			}

			renderer->SetLayout(shader_);

			for (size_t loop = 0; loop < m_matrixes.size();)
			{
				int32_t modelCount = Effekseer::Min(static_cast<int32_t>(m_matrixes.size()) - (int32_t)loop, InstanceCount);

				for (int32_t num = 0; num < modelCount; num++)
				{
					vcb->ModelMatrix[num] = m_matrixes[loop + num];

					// DepthParameter
					::Effekseer::SIMD::Mat44f modelMatrix = vcb->ModelMatrix[num];

					if (param.EnableViewOffset)
					{
						ApplyViewOffset(modelMatrix, renderer->GetCameraMatrix(), m_viewOffsetDistance[loop + num]);
					}

					ApplyDepthParameters(modelMatrix,
										 renderer->GetCameraFrontDirection(),
										 renderer->GetCameraPosition(),
										 param.DepthParameterPtr,
										 param.IsRightHand);
					vcb->ModelMatrix[num] = ToStruct(modelMatrix);

					vcb->ModelUV[num][0] = m_uv[loop + num].X;
					vcb->ModelUV[num][1] = m_uv[loop + num].Y;
					vcb->ModelUV[num][2] = m_uv[loop + num].Width;
					vcb->ModelUV[num][3] = m_uv[loop + num].Height;

					vcb->SetModelAlphaUV(
						num, m_alphaUV[loop + num].X, m_alphaUV[loop + num].Y, m_alphaUV[loop + num].Width, m_alphaUV[loop + num].Height);
					vcb->SetModelUVDistortionUV(num,
												m_uvDistortionUV[loop + num].X,
												m_uvDistortionUV[loop + num].Y,
												m_uvDistortionUV[loop + num].Width,
												m_uvDistortionUV[loop + num].Height);
					vcb->SetModelBlendUV(
						num, m_blendUV[loop + num].X, m_blendUV[loop + num].Y, m_blendUV[loop + num].Width, m_blendUV[loop + num].Height);
					vcb->SetModelBlendAlphaUV(num,
											  m_blendAlphaUV[loop + num].X,
											  m_blendAlphaUV[loop + num].Y,
											  m_blendAlphaUV[loop + num].Width,
											  m_blendAlphaUV[loop + num].Height);
					vcb->SetModelBlendUVDistortionUV(num,
													 m_blendUVDistortionUV[loop + num].X,
													 m_blendUVDistortionUV[loop + num].Y,
													 m_blendUVDistortionUV[loop + num].Width,
													 m_blendUVDistortionUV[loop + num].Height);
					vcb->SetModelFlipbookIndexAndNextRate(num, m_flipbookIndexAndNextRate[loop + num]);
					vcb->SetModelAlphaThreshold(num, m_alphaThreshold[loop + num]);

					ColorToFloat4(m_colors[loop + num], vcb->ModelColor[num]);

					if (cutomData1Ptr != nullptr)
					{
						cutomData1Ptr[num * 4 + 0] = customData1_[loop + num][0];
						cutomData1Ptr[num * 4 + 1] = customData1_[loop + num][1];
						cutomData1Ptr[num * 4 + 2] = customData1_[loop + num][2];
						cutomData1Ptr[num * 4 + 3] = customData1_[loop + num][3];
					}

					if (cutomData2Ptr != nullptr)
					{
						cutomData2Ptr[num * 4 + 0] = customData2_[loop + num][0];
						cutomData2Ptr[num * 4 + 1] = customData2_[loop + num][1];
						cutomData2Ptr[num * 4 + 2] = customData2_[loop + num][2];
						cutomData2Ptr[num * 4 + 3] = customData2_[loop + num][3];
					}
				}

				shader_->SetConstantBuffer();

				if (VertexType == ModelRendererVertexType::Instancing)
				{
					renderer->DrawPolygonInstanced(model->GetVertexCount(stTime0), model->GetFaceCount(stTime0) * indexPerFace, modelCount);
				}
				else
				{
					assert(0);
				}

				loop += modelCount;
			}
		}
		else
		{
			for (size_t loop = 0; loop < m_matrixes.size();)
			{
				auto stTime = m_times[loop] % model->GetFrameCount();
				// auto& imodel = model->InternalModels[stTime];

				// Invalid unless layout is set after buffer
				renderer->SetVertexBuffer(model->GetVertexBuffer(stTime), sizeof(Effekseer::Model::Vertex));

				int32_t indexPerFace = 3;
				if (renderer->GetRenderMode() == Effekseer::RenderMode::Wireframe)
				{
					renderer->SetIndexBuffer(model->GetWireIndexBuffer(stTime));
					indexPerFace = 6;
				}
				else
				{
					renderer->SetIndexBuffer(model->GetIndexBuffer(stTime));
				}

				renderer->SetLayout(shader_);

				vcb->ModelMatrix[0] = m_matrixes[loop];
				vcb->ModelUV[0][0] = m_uv[loop].X;
				vcb->ModelUV[0][1] = m_uv[loop].Y;
				vcb->ModelUV[0][2] = m_uv[loop].Width;
				vcb->ModelUV[0][3] = m_uv[loop].Height;

				vcb->SetModelAlphaUV(0, m_alphaUV[loop].X, m_alphaUV[loop].Y, m_alphaUV[loop].Width, m_alphaUV[loop].Height);
				vcb->SetModelUVDistortionUV(
					0, m_uvDistortionUV[loop].X, m_uvDistortionUV[loop].Y, m_uvDistortionUV[loop].Width, m_uvDistortionUV[loop].Height);
				vcb->SetModelBlendUV(0, m_blendUV[loop].X, m_blendUV[loop].Y, m_blendUV[loop].Width, m_blendUV[loop].Height);
				vcb->SetModelBlendAlphaUV(
					0, m_blendAlphaUV[loop].X, m_blendAlphaUV[loop].Y, m_blendAlphaUV[loop].Width, m_blendAlphaUV[loop].Height);
				vcb->SetModelBlendUVDistortionUV(
					0, m_blendUVDistortionUV[loop].X, m_blendUVDistortionUV[loop].Y, m_blendUVDistortionUV[loop].Width, m_blendUVDistortionUV[loop].Height);
				vcb->SetModelFlipbookIndexAndNextRate(0, m_flipbookIndexAndNextRate[loop]);
				vcb->SetModelAlphaThreshold(0, m_alphaThreshold[loop]);

				// DepthParameters
				::Effekseer::SIMD::Mat44f modelMatrix = vcb->ModelMatrix[0];
				if (param.EnableViewOffset == true)
				{
					ApplyViewOffset(modelMatrix, renderer->GetCameraMatrix(), m_viewOffsetDistance[0]);
				}

				ApplyDepthParameters(modelMatrix,
									 renderer->GetCameraFrontDirection(),
									 renderer->GetCameraPosition(),
									 param.DepthParameterPtr,
									 param.IsRightHand);
				vcb->ModelMatrix[0] = ToStruct(modelMatrix);
				ColorToFloat4(m_colors[loop], vcb->ModelColor[0]);

				if (cutomData1Ptr != nullptr)
				{
					cutomData1Ptr[0] = customData1_[loop][0];
					cutomData1Ptr[1] = customData1_[loop][1];
					cutomData1Ptr[2] = customData1_[loop][2];
					cutomData1Ptr[3] = customData1_[loop][3];
				}

				if (cutomData2Ptr != nullptr)
				{
					cutomData2Ptr[0] = customData2_[loop][0];
					cutomData2Ptr[1] = customData2_[loop][1];
					cutomData2Ptr[2] = customData2_[loop][2];
					cutomData2Ptr[3] = customData2_[loop][3];
				}

				shader_->SetConstantBuffer();
				renderer->DrawPolygon(model->GetVertexCount(stTime), model->GetFaceCount(stTime) * indexPerFace);

				loop += 1;
			}
		}

		renderer->EndShader(shader_);

		renderer->GetRenderState()->Pop();
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_MODEL_RENDERER_H__
