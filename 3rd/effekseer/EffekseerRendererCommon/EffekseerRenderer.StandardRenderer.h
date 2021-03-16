
#ifndef __EFFEKSEERRENDERER_STANDARD_RENDERER_BASE_H__
#define __EFFEKSEERRENDERER_STANDARD_RENDERER_BASE_H__

#include <Effekseer.h>
#include <algorithm>
#include <functional>
#include <vector>

#include "EffekseerRenderer.CommonUtils.h"
#include "EffekseerRenderer.Renderer.h"
#include "EffekseerRenderer.Renderer_Impl.h"
#include "EffekseerRenderer.VertexBufferBase.h"

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
namespace EffekseerRenderer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

struct StandardRendererState
{
	bool DepthTest;
	bool DepthWrite;
	bool Distortion;
	float DistortionIntensity;
	bool Wireframe;
	bool Refraction;

	::Effekseer::AlphaBlendType AlphaBlend;
	::Effekseer::CullingType CullingType;

	int32_t EnableInterpolation;
	int32_t UVLoopType;
	int32_t InterpolationType;
	int32_t FlipbookDivideX;
	int32_t FlipbookDivideY;

	float UVDistortionIntensity;

	int32_t TextureBlendType;

	float BlendUVDistortionIntensity;

	float EmissiveScaling;

	float EdgeThreshold;
	uint8_t EdgeColor[4];
	float EdgeColorScaling;
	bool IsAlphaCuttoffEnabled = false;
	float SoftParticleDistanceFar = 0.0f;
	float SoftParticleDistanceNear = 0.0f;
	float SoftParticleDistanceNearOffset = 0.0f;
	float Maginification = 1.0f;

	::Effekseer::RendererMaterialType MaterialType;
	int32_t MaterialUniformCount = 0;
	std::array<std::array<float, 4>, 16> MaterialUniforms;

	int32_t CustomData1Count = 0;
	int32_t CustomData2Count = 0;

	ShaderParameterCollector Collector{};

	Effekseer::RefPtr<Effekseer::RenderingUserData> RenderingUserData{};
	void* HandleUserData;

	StandardRendererState()
	{
		DepthTest = false;
		DepthWrite = false;
		Distortion = false;
		DistortionIntensity = 1.0f;
		Wireframe = true;
		Refraction = false;

		AlphaBlend = ::Effekseer::AlphaBlendType::Blend;
		CullingType = ::Effekseer::CullingType::Front;

		EnableInterpolation = 0;
		UVLoopType = 0;
		InterpolationType = 0;
		FlipbookDivideX = 0;
		FlipbookDivideY = 0;

		UVDistortionIntensity = 1.0f;

		TextureBlendType = 0;

		BlendUVDistortionIntensity = 1.0f;

		EmissiveScaling = 1.0f;

		EdgeThreshold = 0.0f;
		EdgeColor[0] = EdgeColor[1] = EdgeColor[2] = EdgeColor[3] = 0;
		EdgeColorScaling = 1;

		MaterialType = ::Effekseer::RendererMaterialType::Default;
		MaterialUniformCount = 0;
		CustomData1Count = 0;
		CustomData2Count = 0;

		RenderingUserData.Reset();
		HandleUserData = nullptr;
	}

	bool operator!=(const StandardRendererState state)
	{
		if (Collector != state.Collector)
			return true;

		if (DepthTest != state.DepthTest)
			return true;
		if (DepthWrite != state.DepthWrite)
			return true;
		if (Distortion != state.Distortion)
			return true;
		if (DistortionIntensity != state.DistortionIntensity)
			return true;
		if (AlphaBlend != state.AlphaBlend)
			return true;
		if (CullingType != state.CullingType)
			return true;

		if (EnableInterpolation != state.EnableInterpolation)
			return true;
		if (UVLoopType != state.UVLoopType)
			return true;
		if (InterpolationType != state.InterpolationType)
			return true;
		if (FlipbookDivideX != state.FlipbookDivideX)
			return true;
		if (FlipbookDivideY != state.FlipbookDivideY)
			return true;

		if (UVDistortionIntensity != state.UVDistortionIntensity)
			return true;
		if (TextureBlendType != state.TextureBlendType)
			return true;
		if (BlendUVDistortionIntensity != state.BlendUVDistortionIntensity)
			return true;
		if (EmissiveScaling != state.EmissiveScaling)
			return true;

		if (EdgeThreshold != state.EdgeThreshold)
			return true;
		if (EdgeColor[0] != state.EdgeColor[0] ||
			EdgeColor[1] != state.EdgeColor[1] ||
			EdgeColor[2] != state.EdgeColor[2] ||
			EdgeColor[3] != state.EdgeColor[3])
			return true;
		if (EdgeColorScaling != state.EdgeColorScaling)
			return true;

		if (IsAlphaCuttoffEnabled != state.IsAlphaCuttoffEnabled)
			return true;

		if (SoftParticleDistanceFar != state.SoftParticleDistanceFar)
			return true;

		if (SoftParticleDistanceNear != state.SoftParticleDistanceNear)
			return true;

		if (SoftParticleDistanceNearOffset != state.SoftParticleDistanceNearOffset)
			return true;

		if (Maginification != state.Maginification)
			return true;

		if (MaterialType != state.MaterialType)
			return true;
		if (MaterialUniformCount != state.MaterialUniformCount)
			return true;
		if (Refraction != state.Refraction)
			return true;

		for (int32_t i = 0; i < state.MaterialUniformCount; i++)
		{
			if (MaterialUniforms[i] != state.MaterialUniforms[i])
				return true;
		}

		if (CustomData1Count != state.CustomData1Count)
			return true;

		if (CustomData1Count != state.CustomData1Count)
			return true;

		if (RenderingUserData == nullptr && state.RenderingUserData != nullptr)
			return true;

		if (RenderingUserData != nullptr && state.RenderingUserData == nullptr)
			return true;

		if (RenderingUserData != nullptr && state.RenderingUserData != nullptr && !RenderingUserData->Equal(state.RenderingUserData.Get()))
			return true;

		if (HandleUserData != state.HandleUserData)
			return true;

		return false;
	}

	void CopyMaterialFromParameterToState(
		EffekseerRenderer::Renderer* renderer,
		Effekseer::Effect* effect,
		Effekseer::NodeRendererBasicParameter* basicParam)
	{
		Collector = ShaderParameterCollector();
		Collector.Collect(renderer, effect, basicParam, false, renderer->GetImpl()->isSoftParticleEnabled);

		SoftParticleDistanceFar = basicParam->SoftParticleDistanceFar;
		SoftParticleDistanceNear = basicParam->SoftParticleDistanceNear;
		SoftParticleDistanceNearOffset = basicParam->SoftParticleDistanceNearOffset;

		if (Collector.MaterialRenderDataPtr != nullptr && Collector.MaterialDataPtr != nullptr)
		{
			CustomData1Count = Collector.MaterialDataPtr->CustomData1;
			CustomData2Count = Collector.MaterialDataPtr->CustomData2;

			MaterialUniformCount =
				static_cast<int32_t>(Effekseer::Min(Collector.MaterialRenderDataPtr->MaterialUniforms.size(), MaterialUniforms.size()));
			for (size_t i = 0; i < MaterialUniformCount; i++)
			{
				MaterialUniforms[i] = Collector.MaterialRenderDataPtr->MaterialUniforms[i];
			}
		}
		else
		{
			Refraction = false;
			CustomData1Count = 0;
			CustomData2Count = 0;
		}
	}
};

struct StandardRendererVertexBuffer
{
	Effekseer::Matrix44 constantVSBuffer[2];
	float uvInversed[4];

	struct
	{
		union
		{
			float Buffer[4];

			struct
			{
				float enableInterpolation;
				float loopType;
				float divideX;
				float divideY;
			};
		};
	} flipbookParameter;
};

template <typename RENDERER, typename SHADER>
class StandardRenderer
{
private:
	RENDERER* m_renderer;

	Effekseer::Backend::TextureRef m_texture;

	StandardRendererState m_state;

	//! WebAssembly requires a much time to resize std::vector (in a profiler at least) so reduce to call resize
	std::vector<uint8_t> vertexCaches_;
	int32_t vertexCacheOffset_ = 0;

	int32_t squareMaxSize_ = 0;
	RendererShaderType renderingMode_ = RendererShaderType::Unlit;

	void ColorToFloat4(::Effekseer::Color color, float fc[4])
	{
		fc[0] = color.R / 255.0f;
		fc[1] = color.G / 255.0f;
		fc[2] = color.B / 255.0f;
		fc[3] = color.A / 255.0f;
	}

	void VectorToFloat4(const ::Effekseer::SIMD::Vec3f& v, float fc[4])
	{
		::Effekseer::SIMD::Float4::Store3(fc, v.s);
		fc[3] = 1.0f;
	}

public:
	StandardRenderer(RENDERER* renderer)
		: squareMaxSize_(renderer->GetSquareMaxCount())
	{
		m_renderer = renderer;
		// TODO:
		vertexCaches_.reserve(squareMaxSize_ * sizeof(SimpleVertex)/*m_renderer->GetVertexBuffer()->GetMaxSize()*/);
	}

	virtual ~StandardRenderer()
	{
	}

	int32_t CalculateCurrentStride() const
	{
		size_t stride = 0;
		if (renderingMode_ == RendererShaderType::Material)
		{
			stride = sizeof(DynamicVertex);
			stride += (m_state.CustomData1Count + m_state.CustomData2Count) * sizeof(float);
		}
		else if (renderingMode_ == RendererShaderType::Lit)
		{
			stride = sizeof(LightingVertex);
		}
		else if (renderingMode_ == RendererShaderType::BackDistortion)
		{
			stride = sizeof(LightingVertex);
		}
		else if (renderingMode_ == RendererShaderType::Unlit)
		{
			stride = sizeof(SimpleVertex);
		}
		else if (renderingMode_ == RendererShaderType::AdvancedLit)
		{
			stride = sizeof(AdvancedLightingVertex);
		}
		else if (renderingMode_ == RendererShaderType::AdvancedBackDistortion)
		{
			stride = sizeof(AdvancedLightingVertex);
		}
		else if (renderingMode_ == RendererShaderType::AdvancedUnlit)
		{
			stride = sizeof(AdvancedSimpleVertex);
		}

		return static_cast<int32_t>(stride);
	}

	void UpdateStateAndRenderingIfRequired(StandardRendererState state)
	{
		if (m_state != state)
		{
			Rendering();
		}

		m_state = state;

		renderingMode_ = m_state.Collector.ShaderType;
	}

	void BeginRenderingAndRenderingIfRequired(int32_t count, int& stride, void*& data)
	{
		stride = CalculateCurrentStride();

		const int32_t requiredSize = count * stride;
		{
			int32_t renderVertexMaxSize = squareMaxSize_ * stride * 4;

			if (requiredSize + vertexCacheOffset_ > renderVertexMaxSize)
			{
				Rendering();
			}

			const auto oldOffset = vertexCacheOffset_;
			vertexCacheOffset_ += requiredSize;
			if (vertexCaches_.size() < vertexCacheOffset_)
			{
				vertexCaches_.resize(vertexCacheOffset_);
			}

			data = (vertexCaches_.data() + oldOffset);
		}
	}

	void ResetAndRenderingIfRequired()
	{
		Rendering();

		// It is always initialized with the next drawing.
		m_state.Collector = ShaderParameterCollector();
	}

	const StandardRendererState& GetState()
	{
		return m_state;
	}

	void Rendering(const Effekseer::SIMD::Mat44f& mCamera, const Effekseer::SIMD::Mat44f& mProj)
	{
		if (vertexCacheOffset_ == 0)
			return;

		int32_t stride = CalculateCurrentStride();

		int32_t passNum = 1;

		if (m_state.Collector.ShaderType == RendererShaderType::Material)
		{
			if (m_state.Collector.MaterialDataPtr->RefractionUserPtr != nullptr)
			{
				// refraction and standard
				passNum = 2;
			}
		}

		for (int32_t passInd = 0; passInd < passNum; passInd++)
		{
			int32_t offset = 0;

			while (true)
			{
				// only sprite
				int32_t renderBufferSize = vertexCacheOffset_ - offset;

				int32_t renderVertexMaxSize = squareMaxSize_ * stride * 4;

				if (renderBufferSize > renderVertexMaxSize)
				{
					renderBufferSize = (renderVertexMaxSize / (stride * 4)) * (stride * 4);
				}

				Rendering_(mCamera, mProj, offset, renderBufferSize, stride, passInd);

				offset += renderBufferSize;

				if (offset == vertexCacheOffset_)
					break;
			}
		}

		vertexCacheOffset_ = 0;
	}

	void Rendering_(const Effekseer::SIMD::Mat44f& mCamera,
					const Effekseer::SIMD::Mat44f& mProj,
					int32_t bufferOffset,
					int32_t bufferSize,
					int32_t stride,
					int32_t renderPass)
	{
		bool isBackgroundRequired = m_state.Collector.IsBackgroundRequiredOnFirstPass && renderPass == 0;

		if (isBackgroundRequired)
		{
			auto callback = m_renderer->GetDistortingCallback();
			if (callback != nullptr)
			{
				if (!callback->OnDistorting(m_renderer))
				{
					return;
				}
			}
		}

		if (isBackgroundRequired && m_renderer->GetBackground() == 0)
		{
			return;
		}

		auto textures = m_state.Collector.Textures;
		if (isBackgroundRequired)
		{
			textures[m_state.Collector.BackgroundIndex] = m_renderer->GetBackground();
		}

		::Effekseer::Backend::TextureRef depthTexture = nullptr;
		::EffekseerRenderer::DepthReconstructionParameter reconstructionParam;
		m_renderer->GetImpl()->GetDepth(depthTexture, reconstructionParam);

		if (m_state.Collector.IsDepthRequired)
		{
			if (depthTexture == nullptr || (m_state.SoftParticleDistanceFar == 0.0f &&
											m_state.SoftParticleDistanceNear == 0.0f &&
											m_state.SoftParticleDistanceNearOffset == 0.0f &&
											m_state.Collector.ShaderType != RendererShaderType::Material))
			{
				depthTexture = m_renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
			}

			textures[m_state.Collector.DepthIndex] = depthTexture;
		}

		int32_t vertexSize = bufferSize;
		int32_t vbOffset = 0;
		{
			VertexBufferBase* vb = m_renderer->GetVertexBuffer();

			void* vbData = nullptr;

			if (vb->RingBufferLock(vertexSize, vbOffset, vbData, stride * 4))
			{
				assert(vbData != nullptr);
				memcpy(vbData, vertexCaches_.data() + bufferOffset, vertexSize);
				vb->Unlock();
			}
			else
			{
				return;
			}
		}

		SHADER* shader_ = nullptr;

		bool distortion = m_state.Distortion;
		bool renderDistortedBackground = false;

		if (m_state.Collector.ShaderType == RendererShaderType::Material)
		{
			/*
			if (m_state.Collector.MaterialDataPtr->IsRefractionRequired)
			{
				if (renderPass == 0)
				{
					if (m_renderer->GetBackground() == 0)
					{
						return;
					}

					shader_ = (SHADER*)m_state.Collector.MaterialDataPtr->RefractionUserPtr;
					renderDistortedBackground = true;
				}
				else
				{
					shader_ = (SHADER*)m_state.Collector.MaterialDataPtr->UserPtr;
				}
			}
			else
			{
				shader_ = (SHADER*)m_state.Collector.MaterialDataPtr->UserPtr;
			}
			*/
			// validate
			if (shader_ == nullptr)
				return;
		}
		else
		{
			if (m_state.Collector.ShaderType != RendererShaderType::Unlit)
			{
				printf("unsupport shader type.\n");
				return;
			}
			shader_ = m_renderer->GetShader(m_state.Collector.ShaderType);
		}

		RenderStateBase::State& state = m_renderer->GetRenderState()->Push();
		state.DepthTest = m_state.DepthTest;
		state.DepthWrite = m_state.DepthWrite;
		state.CullingType = m_state.CullingType;
		state.AlphaBlend = m_state.AlphaBlend;

		if (renderDistortedBackground)
		{
			state.AlphaBlend = ::Effekseer::AlphaBlendType::Blend;
		}

		m_renderer->BeginShader(shader_);

		for (int32_t i = 0; i < m_state.Collector.TextureCount; i++)
		{
			state.TextureFilterTypes[i] = m_state.Collector.TextureFilterTypes[i];
			state.TextureWrapTypes[i] = m_state.Collector.TextureWrapTypes[i];
		}

		m_renderer->SetTextures(shader_, textures.data(), m_state.Collector.TextureCount);

		std::array<float, 4> uvInversed;
		std::array<float, 4> uvInversedBack;
		std::array<float, 4> uvInversedMaterial;

		if (m_renderer->GetTextureUVStyle() == UVStyle::VerticalFlipped)
		{
			uvInversed[0] = 1.0f;
			uvInversed[1] = -1.0f;
		}
		else
		{
			uvInversed[0] = 0.0f;
			uvInversed[1] = 1.0f;
		}

		if (m_renderer->GetBackgroundTextureUVStyle() == UVStyle::VerticalFlipped)
		{
			uvInversedBack[0] = 1.0f;
			uvInversedBack[1] = -1.0f;
		}
		else
		{
			uvInversedBack[0] = 0.0f;
			uvInversedBack[1] = 1.0f;
		}

		uvInversedMaterial[0] = uvInversed[0];
		uvInversedMaterial[1] = uvInversed[1];
		uvInversedMaterial[2] = uvInversedBack[0];
		uvInversedMaterial[3] = uvInversedBack[1];

		if (m_state.Collector.ShaderType == RendererShaderType::Material)
		{
			Effekseer::Matrix44 mstCamera = ToStruct(mCamera);
			Effekseer::Matrix44 mstProj = ToStruct(mProj);

			// camera
			float cameraPosition[4];
			::Effekseer::SIMD::Vec3f cameraPosition3 = m_renderer->GetCameraPosition();
			VectorToFloat4(cameraPosition3, cameraPosition);
			// time
			std::array<float, 4> predefined_uniforms;
			predefined_uniforms.fill(0.5f);
			predefined_uniforms[0] = m_renderer->GetTime();
			predefined_uniforms[1] = m_state.Maginification;

			// vs
			int32_t vsOffset = 0;
			m_renderer->SetVertexBufferToShader(&mstCamera, sizeof(Effekseer::Matrix44), vsOffset);
			vsOffset += sizeof(Effekseer::Matrix44);

			m_renderer->SetVertexBufferToShader(&mstProj, sizeof(Effekseer::Matrix44), vsOffset);
			vsOffset += sizeof(Effekseer::Matrix44);

			m_renderer->SetVertexBufferToShader(uvInversedMaterial.data(), sizeof(float) * 4, vsOffset);
			vsOffset += (sizeof(float) * 4);

			m_renderer->SetVertexBufferToShader(predefined_uniforms.data(), sizeof(float) * 4, vsOffset);
			vsOffset += (sizeof(float) * 4);

			m_renderer->SetVertexBufferToShader(cameraPosition, sizeof(float) * 4, vsOffset);
			vsOffset += (sizeof(float) * 4);

			for (size_t i = 0; i < m_state.MaterialUniformCount; i++)
			{
				m_renderer->SetVertexBufferToShader(m_state.MaterialUniforms[i].data(), sizeof(float) * 4, vsOffset);
				vsOffset += (sizeof(float) * 4);
			}

			// ps
			int32_t psOffset = 0;
			m_renderer->SetPixelBufferToShader(uvInversedMaterial.data(), sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			m_renderer->SetPixelBufferToShader(predefined_uniforms.data(), sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			m_renderer->SetPixelBufferToShader(cameraPosition, sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			SoftParticleParameter softParticleParam;

			softParticleParam.SetParam(
				0.0f,
				0.0f,
				0.0f,
				0.0f,
				reconstructionParam.DepthBufferScale,
				reconstructionParam.DepthBufferOffset,
				reconstructionParam.ProjectionMatrix33,
				reconstructionParam.ProjectionMatrix34,
				reconstructionParam.ProjectionMatrix43,
				reconstructionParam.ProjectionMatrix44);

			m_renderer->SetPixelBufferToShader(softParticleParam.reconstructionParam1.data(), sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			m_renderer->SetPixelBufferToShader(softParticleParam.reconstructionParam2.data(), sizeof(float) * 4, psOffset);
			psOffset += (sizeof(float) * 4);

			// shader model
			if (m_state.Collector.MaterialDataPtr->ShadingModel == ::Effekseer::ShadingModelType::Lit)
			{

				float lightDirection[4];
				float lightColor[4];
				float lightAmbientColor[4];

				::Effekseer::SIMD::Vec3f lightDirection3 = m_renderer->GetLightDirection();
				lightDirection3 = lightDirection3.Normalize();
				VectorToFloat4(lightDirection3, lightDirection);
				ColorToFloat4(m_renderer->GetLightColor(), lightColor);
				ColorToFloat4(m_renderer->GetLightAmbientColor(), lightAmbientColor);

				m_renderer->SetPixelBufferToShader(lightDirection, sizeof(float) * 4, psOffset);
				psOffset += (sizeof(float) * 4);

				m_renderer->SetPixelBufferToShader(lightColor, sizeof(float) * 4, psOffset);
				psOffset += (sizeof(float) * 4);

				m_renderer->SetPixelBufferToShader(lightAmbientColor, sizeof(float) * 4, psOffset);
				psOffset += (sizeof(float) * 4);
			}

			// refraction
			if (m_state.Collector.MaterialDataPtr->RefractionUserPtr != nullptr && renderPass == 0)
			{
				auto mat = m_renderer->GetCameraMatrix();
				m_renderer->SetPixelBufferToShader(&mat, sizeof(float) * 16, psOffset);
				psOffset += (sizeof(float) * 16);
			}

			for (size_t i = 0; i < m_state.MaterialUniformCount; i++)
			{
				m_renderer->SetPixelBufferToShader(m_state.MaterialUniforms[i].data(), sizeof(float) * 4, psOffset);
				psOffset += (sizeof(float) * 4);
			}
		}
		else if (m_state.MaterialType == ::Effekseer::RendererMaterialType::Lighting)
		{
			StandardRendererVertexBuffer vcb;
			vcb.constantVSBuffer[0] = ToStruct(mCamera);
			vcb.constantVSBuffer[1] = ToStruct(mCamera * mProj);
			vcb.uvInversed[0] = uvInversed[0];
			vcb.uvInversed[1] = uvInversed[1];

			vcb.flipbookParameter.enableInterpolation = static_cast<float>(m_state.EnableInterpolation);
			vcb.flipbookParameter.loopType = static_cast<float>(m_state.UVLoopType);
			vcb.flipbookParameter.divideX = static_cast<float>(m_state.FlipbookDivideX);
			vcb.flipbookParameter.divideY = static_cast<float>(m_state.FlipbookDivideY);

			m_renderer->SetVertexBufferToShader(&vcb, sizeof(StandardRendererVertexBuffer), 0);

			// ps
			PixelConstantBuffer pcb{};

			pcb.FalloffParam.Enable = 0;

			auto lightDirection3 = m_renderer->GetLightDirection();
			Effekseer::Vector3D::Normal(lightDirection3, lightDirection3);
			pcb.LightDirection = lightDirection3.ToFloat4();
			pcb.LightColor = m_renderer->GetLightColor().ToFloat4();
			pcb.LightAmbientColor = m_renderer->GetLightAmbientColor().ToFloat4();

			pcb.FlipbookParam.EnableInterpolation = static_cast<float>(m_state.EnableInterpolation);
			pcb.FlipbookParam.InterpolationType = static_cast<float>(m_state.InterpolationType);

			pcb.UVDistortionParam.Intensity = m_state.UVDistortionIntensity;
			pcb.UVDistortionParam.BlendIntensity = m_state.BlendUVDistortionIntensity;
			pcb.UVDistortionParam.UVInversed[0] = uvInversed[0];
			pcb.UVDistortionParam.UVInversed[1] = uvInversed[1];

			pcb.BlendTextureParam.BlendType = static_cast<float>(m_state.TextureBlendType);

			pcb.EmmisiveParam.EmissiveScaling = m_state.EmissiveScaling;

			pcb.EdgeParam.EdgeColor = Effekseer::Color(m_state.EdgeColor[0], m_state.EdgeColor[1], m_state.EdgeColor[2], m_state.EdgeColor[3]).ToFloat4();
			pcb.EdgeParam.Threshold = m_state.EdgeThreshold;
			pcb.EdgeParam.ColorScaling = static_cast<float>(m_state.EdgeColorScaling);

			pcb.SoftParticleParam.SetParam(
				m_state.SoftParticleDistanceFar,
				m_state.SoftParticleDistanceNear,
				m_state.SoftParticleDistanceNearOffset,
				m_state.Maginification,
				reconstructionParam.DepthBufferScale,
				reconstructionParam.DepthBufferOffset,
				reconstructionParam.ProjectionMatrix33,
				reconstructionParam.ProjectionMatrix34,
				reconstructionParam.ProjectionMatrix43,
				reconstructionParam.ProjectionMatrix44);

			m_renderer->SetPixelBufferToShader(&pcb, sizeof(PixelConstantBuffer), 0);
		}
		else
		{
			StandardRendererVertexBuffer vcb;
			vcb.constantVSBuffer[0] = ToStruct(mCamera);
			vcb.constantVSBuffer[1] = ToStruct(mCamera * mProj);
			vcb.uvInversed[0] = uvInversed[0];
			vcb.uvInversed[1] = uvInversed[1];
			vcb.uvInversed[2] = 0.0f;
			vcb.uvInversed[3] = 0.0f;

			vcb.flipbookParameter.enableInterpolation = static_cast<float>(m_state.EnableInterpolation);
			vcb.flipbookParameter.loopType = static_cast<float>(m_state.UVLoopType);
			vcb.flipbookParameter.divideX = static_cast<float>(m_state.FlipbookDivideX);
			vcb.flipbookParameter.divideY = static_cast<float>(m_state.FlipbookDivideY);

			m_renderer->SetVertexBufferToShader(&vcb, sizeof(StandardRendererVertexBuffer), 0);

			if (distortion)
			{
				PixelConstantBufferDistortion pcb;
				pcb.DistortionIntencity[0] = m_state.DistortionIntensity;
				pcb.UVInversedBack[0] = uvInversedBack[0];
				pcb.UVInversedBack[1] = uvInversedBack[1];

				pcb.FlipbookParam.EnableInterpolation = static_cast<float>(m_state.EnableInterpolation);
				pcb.FlipbookParam.InterpolationType = static_cast<float>(m_state.InterpolationType);

				pcb.UVDistortionParam.Intensity = m_state.UVDistortionIntensity;
				pcb.UVDistortionParam.BlendIntensity = m_state.BlendUVDistortionIntensity;
				pcb.UVDistortionParam.UVInversed[0] = uvInversed[0];
				pcb.UVDistortionParam.UVInversed[1] = uvInversed[1];

				pcb.BlendTextureParam.BlendType = static_cast<float>(m_state.TextureBlendType);

				pcb.SoftParticleParam.SetParam(
					m_state.SoftParticleDistanceFar,
					m_state.SoftParticleDistanceNear,
					m_state.SoftParticleDistanceNearOffset,
					m_state.Maginification,
					reconstructionParam.DepthBufferScale,
					reconstructionParam.DepthBufferOffset,
					reconstructionParam.ProjectionMatrix33,
					reconstructionParam.ProjectionMatrix34,
					reconstructionParam.ProjectionMatrix43,
					reconstructionParam.ProjectionMatrix44);

				m_renderer->SetPixelBufferToShader(&pcb, sizeof(PixelConstantBufferDistortion), 0);
			}
			else
			{
				PixelConstantBuffer pcb;
				pcb.FlipbookParam.EnableInterpolation = static_cast<float>(m_state.EnableInterpolation);
				pcb.FlipbookParam.InterpolationType = static_cast<float>(m_state.InterpolationType);

				pcb.UVDistortionParam.Intensity = m_state.UVDistortionIntensity;
				pcb.UVDistortionParam.BlendIntensity = m_state.BlendUVDistortionIntensity;
				pcb.UVDistortionParam.UVInversed[0] = uvInversed[0];
				pcb.UVDistortionParam.UVInversed[1] = uvInversed[1];

				pcb.BlendTextureParam.BlendType = static_cast<float>(m_state.TextureBlendType);

				pcb.EmmisiveParam.EmissiveScaling = m_state.EmissiveScaling;

				pcb.EdgeParam.EdgeColor = Effekseer::Color(m_state.EdgeColor[0], m_state.EdgeColor[1], m_state.EdgeColor[2], m_state.EdgeColor[3]).ToFloat4();
				pcb.EdgeParam.Threshold = m_state.EdgeThreshold;
				pcb.EdgeParam.ColorScaling = static_cast<float>(m_state.EdgeColorScaling);

				pcb.SoftParticleParam.SetParam(
					m_state.SoftParticleDistanceFar,
					m_state.SoftParticleDistanceNear,
					m_state.SoftParticleDistanceNearOffset,
					m_state.Maginification,
					reconstructionParam.DepthBufferScale,
					reconstructionParam.DepthBufferOffset,
					reconstructionParam.ProjectionMatrix33,
					reconstructionParam.ProjectionMatrix34,
					reconstructionParam.ProjectionMatrix43,
					reconstructionParam.ProjectionMatrix44);

				m_renderer->SetPixelBufferToShader(&pcb, sizeof(PixelConstantBuffer), 0);
			}
		}

		shader_->SetConstantBuffer();

		m_renderer->GetRenderState()->Update(distortion);

		assert(vbOffset % stride == 0);

		m_renderer->SetVertexBuffer(m_renderer->GetVertexBuffer(), stride);
		m_renderer->SetIndexBuffer(m_renderer->GetIndexBuffer());
		m_renderer->SetLayout(shader_);
		m_renderer->GetImpl()->CurrentRenderingUserData = m_state.RenderingUserData;
		m_renderer->GetImpl()->CurrentHandleUserData = m_state.HandleUserData;
		m_renderer->DrawSprites(vertexSize / stride / 4, vbOffset / stride);

		m_renderer->EndShader(shader_);

		m_renderer->GetRenderState()->Pop();
	}

	void Rendering()
	{
		Rendering(m_renderer->GetCameraMatrix(), m_renderer->GetProjectionMatrix());
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_STANDARD_RENDERER_H__
