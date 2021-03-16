
#ifndef __EFFEKSEERRENDERER_COMMON_UTILS_H__
#define __EFFEKSEERRENDERER_COMMON_UTILS_H__

#include "../EffekseerRendererCommon/EffekseerRenderer.Renderer.h"
#include "../EffekseerRendererCommon/EffekseerRenderer.Renderer_Impl.h"
#include <Effekseer.h>
#include <Effekseer/Material/Effekseer.CompiledMaterial.h>
#include <Effekseer/Model/SplineGenerator.h>
#include <algorithm>
#include <array>
#include <assert.h>
#include <functional>
#include <math.h>
#include <string.h>
#include <type_traits>

namespace EffekseerRenderer
{

using VertexFloat3 = ::Effekseer::Vector3D;
using VertexColor = ::Effekseer::Color;

inline void SwapRGBAToBGRA(Effekseer::Color& color)
{
	auto temp = color;
	color.B = temp.R;
	color.R = temp.B;
}

inline Effekseer::Color PackVector3DF(const Effekseer::SIMD::Vec3f& v)
{
	Effekseer::Color ret;
	ret.R = static_cast<uint8_t>(Effekseer::Clamp(((v.GetX() + 1.0f) / 2.0f + 0.5f / 255.0f) * 255.0f, 255, 0));
	ret.G = static_cast<uint8_t>(Effekseer::Clamp(((v.GetY() + 1.0f) / 2.0f + 0.5f / 255.0f) * 255.0f, 255, 0));
	ret.B = static_cast<uint8_t>(Effekseer::Clamp(((v.GetZ() + 1.0f) / 2.0f + 0.5f / 255.0f) * 255.0f, 255, 0));
	ret.A = 255;
	return ret;
}

inline Effekseer::Vector3D UnpackVector3DF(const Effekseer::Color& v)
{
	Effekseer::Vector3D ret;
	ret.X = (static_cast<float>(v.R) / 255.0f * 2.0f - 1.0f);
	ret.Y = (static_cast<float>(v.G) / 255.0f * 2.0f - 1.0f);
	ret.Z = (static_cast<float>(v.B) / 255.0f * 2.0f - 1.0f);
	return ret;
}

struct DynamicVertex
{
	VertexFloat3 Pos;
	VertexColor Col;
	//! packed vector
	VertexColor Normal;
	//! packed vector
	VertexColor Tangent;

	union
	{
		//! UV1 (for template)
		float UV[2];
		float UV1[2];
	};

	float UV2[2];

	void SetFlipbookIndexAndNextRate(float value)
	{
	}

	void SetAlphaThreshold(float value)
	{
	}

	void SetColor(const VertexColor& color, bool flipRGB)
	{
		Col = color;

		if (flipRGB)
		{
			std::swap(Col.R, Col.B);
		}
	}

	void SetPackedNormal(const VertexColor& normal)
	{
		Normal = normal;
	}

	void SetPackedTangent(const VertexColor& tangent)
	{
		Tangent = tangent;
	}

	void SetUV2(float u, float v)
	{
		UV2[0] = u;
		UV2[1] = v;
	}
};

struct DynamicVertexWithCustomData
{
	DynamicVertex V;
	std::array<float, 4> CustomData1;
	std::array<float, 4> CustomData2;
};

struct LightingVertex
{
	VertexFloat3 Pos;
	VertexColor Col;
	//! packed vector
	VertexColor Normal;
	//! packed vector
	VertexColor Tangent;

	union
	{
		//! UV1 (for template)
		float UV[2];
		float UV1[2];
	};

	float UV2[2];

	void SetFlipbookIndexAndNextRate(float value)
	{
	}
	void SetAlphaThreshold(float value)
	{
	}

	void SetColor(const VertexColor& color, bool flipRGB)
	{
		Col = color;

		if (flipRGB)
		{
			std::swap(Col.R, Col.B);
		}
	}

	void SetPackedNormal(const VertexColor& normal)
	{
		Normal = normal;
	}

	void SetPackedTangent(const VertexColor& tangent)
	{
		Tangent = tangent;
	}

	void SetUV2(float u, float v)
	{
		UV2[0] = u;
		UV2[1] = v;
	}
};

struct SimpleVertex
{
	VertexFloat3 Pos;
	VertexColor Col;

	union
	{
		float UV[2];
		//! dummy for template
		float UV2[2];
	};

	void SetFlipbookIndexAndNextRate(float value)
	{
	}
	void SetAlphaThreshold(float value)
	{
	}

	void SetColor(const VertexColor& color, bool flipRGB)
	{
		Col = color;

		if (flipRGB)
		{
			std::swap(Col.R, Col.B);
		}
	}

	void SetPackedNormal(const VertexColor& normal)
	{
	}

	void SetPackedTangent(const VertexColor& tangent)
	{
	}

	void SetUV2(float u, float v)
	{
	}
};

struct AdvancedLightingVertex
{
	VertexFloat3 Pos;
	VertexColor Col;
	//! packed vector
	VertexColor Normal;
	//! packed vector
	VertexColor Tangent;

	union
	{
		//! UV1 (for template)
		float UV[2];
		float UV1[2];
	};

	float UV2[2];

	float AlphaUV[2];
	float UVDistortionUV[2];
	float BlendUV[2];
	float BlendAlphaUV[2];
	float BlendUVDistortionUV[2];
	float FlipbookIndexAndNextRate;
	float AlphaThreshold;

	void SetFlipbookIndexAndNextRate(float value)
	{
		FlipbookIndexAndNextRate = value;
	}
	void SetAlphaThreshold(float value)
	{
		AlphaThreshold = value;
	}

	void SetColor(const VertexColor& color, bool flipRGB)
	{
		Col = color;

		if (flipRGB)
		{
			std::swap(Col.R, Col.B);
		}
	}

	void SetPackedNormal(const VertexColor& normal)
	{
		Normal = normal;
	}

	void SetPackedTangent(const VertexColor& tangent)
	{
		Tangent = tangent;
	}

	void SetUV2(float u, float v)
	{
		UV2[0] = u;
		UV2[1] = v;
	}
};

struct AdvancedSimpleVertex
{
	VertexFloat3 Pos;
	VertexColor Col;

	union
	{
		float UV[2];
		//! dummy for template
		float UV1[2];
		//! dummy for template
		float UV2[2];
	};

	float AlphaUV[2];
	float UVDistortionUV[2];
	float BlendUV[2];
	float BlendAlphaUV[2];
	float BlendUVDistortionUV[2];
	float FlipbookIndexAndNextRate;
	float AlphaThreshold;

	void SetFlipbookIndexAndNextRate(float value)
	{
		FlipbookIndexAndNextRate = value;
	}
	void SetAlphaThreshold(float value)
	{
		AlphaThreshold = value;
	}

	void SetColor(const VertexColor& color, bool flipRGB)
	{
		Col = color;

		if (flipRGB)
		{
			std::swap(Col.R, Col.B);
		}
	}

	void SetPackedNormal(const VertexColor& normal)
	{
	}

	void SetPackedTangent(const VertexColor& tangent)
	{
	}

	void SetUV2(float u, float v)
	{
	}
};

template <typename U>
class ContainAdvancedData
{
public:
	using Value = int;
};

template <>
class ContainAdvancedData<SimpleVertex>
{
public:
	using Value = float;
};

template <>
class ContainAdvancedData<LightingVertex>
{
public:
	using Value = float;
};

template <>
class ContainAdvancedData<DynamicVertex>
{
public:
	using Value = float;
};

template <typename U>
using enable_if_contain_advanced_t = typename std::enable_if<std::is_same<typename ContainAdvancedData<U>::Value, int>::value, std::nullptr_t>::type;

template <typename U>
using enable_ifnot_contain_advanced_t = typename std::enable_if<std::is_same<typename ContainAdvancedData<U>::Value, float>::value, std::nullptr_t>::type;

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexAlphaUV(const U& v)
{
	return {v.AlphaUV[0], v.AlphaUV[1]};
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexAlphaUV(const U& v)
{
	return {0.0f, 0.0f};
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexUVDistortionUV(const U& v)
{
	return {v.UVDistortionUV[0], v.UVDistortionUV[1]};
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexUVDistortionUV(const U& v)
{
	return {0.0f, 0.0f};
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendUV(const U& v)
{
	return {v.BlendUV[0], v.BlendUV[1]};
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendUV(const U& v)
{
	return {0.0f, 0.0f};
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendAlphaUV(const U& v)
{
	return {v.BlendAlphaUV[0], v.BlendAlphaUV[1]};
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendAlphaUV(const U& v)
{
	return {0.0f, 0.0f};
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendUVDistortionUV(const U& v)
{
	return {v.BlendUVDistortionUV[0], v.BlendUVDistortionUV[1]};
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
std::array<float, 2> GetVertexBlendUVDistortionUV(const U& v)
{
	return {0.0f, 0.0f};
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
float GetVertexFlipbookIndexAndNextRate(const U& v)
{
	return v.FlipbookIndexAndNextRate;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
float GetVertexFlipbookIndexAndNextRate(const U& v)
{
	return 0.0f;
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
float GetVertexAlphaThreshold(const U& v)
{
	return v.AlphaThreshold;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
float GetVertexAlphaThreshold(const U& v)
{
	return 0.0f;
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexAlphaUV(U& v, float value, int32_t ind)
{
	v.AlphaUV[ind] = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexAlphaUV(U& v, float value, int32_t ind)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexUVDistortionUV(U& v, float value, int32_t ind)
{
	v.UVDistortionUV[ind] = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexUVDistortionUV(U& v, float value, int32_t ind)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexBlendUV(U& v, float value, int32_t ind)
{
	v.BlendUV[ind] = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexBlendUV(U& v, float value, int32_t ind)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexBlendAlphaUV(U& v, float value, int32_t ind)
{
	v.BlendAlphaUV[ind] = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexBlendAlphaUV(U& v, float value, int32_t ind)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexBlendUVDistortionUV(U& v, float value, int32_t ind)
{
	v.BlendUVDistortionUV[ind] = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexBlendUVDistortionUV(U& v, float value, int32_t ind)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexFlipbookIndexAndNextRate(U& v, float value)
{
	v.FlipbookIndexAndNextRate = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexFlipbookIndexAndNextRate(U& v, float value)
{
}

template <typename U, enable_if_contain_advanced_t<U> = nullptr>
void SetVertexAlphaThreshold(U& v, float value)
{
	v.AlphaThreshold = value;
}

template <typename U, enable_ifnot_contain_advanced_t<U> = nullptr>
void SetVertexAlphaThreshold(U& v, float value)
{
}

static int32_t GetMaximumVertexSizeInAllTypes()
{
	//size_t size = sizeof(DynamicVertexWithCustomData);
	//size = (std::max)(size, sizeof(SimpleVertex));
	//size = (std::max)(size, sizeof(LightingVertex));
	//size = (std::max)(size, sizeof(AdvancedSimpleVertex));
	//size = (std::max)(size, sizeof(AdvancedLightingVertex));

	//return static_cast<int32_t>(size);
	//test
	return sizeof(SimpleVertex);
};

template <typename T>
inline bool VertexNormalRequired()
{
	return false;
}

template <>
inline bool VertexNormalRequired<DynamicVertex>()
{
	return true;
}

template <>
inline bool VertexNormalRequired<LightingVertex>()
{
	return true;
}

template <>
inline bool VertexNormalRequired<AdvancedLightingVertex>()
{
	return true;
}

template <typename T>
inline bool VertexUV2Required()
{
	return false;
}

template <>
inline bool VertexUV2Required<DynamicVertex>()
{
	return true;
}

/**
	@brief	a view class to access an array with a stride
*/
template <typename T>
struct StrideView
{
	int32_t stride_;
	uint8_t* pointer_;
	uint8_t* pointerOrigin_;

#ifndef NDEBUG
	int32_t offset_;
	int32_t elementCount_;
#endif

	StrideView(void* pointer, int32_t stride, int32_t elementCount)
		: stride_(stride)
		, pointer_(reinterpret_cast<uint8_t*>(pointer))
		, pointerOrigin_(reinterpret_cast<uint8_t*>(pointer))
#ifndef NDEBUG
		, offset_(0)
		, elementCount_(elementCount)
#endif
	{
	}

	T& operator[](int i) const
	{
#ifndef NDEBUG
		assert(i >= 0);
		assert(i + offset_ < elementCount_);
#endif
		return *reinterpret_cast<T*>((pointer_ + stride_ * i));
	}

	StrideView& operator+=(const int& rhs)
	{
#ifndef NDEBUG
		offset_ += rhs;
#endif
		pointer_ += stride_ * rhs;
		return *this;
	}

	void Reset()
	{
#ifndef NDEBUG
		offset_ = 0;
#endif
		pointer_ = pointerOrigin_;
	}
};

void CalcBillboard(::Effekseer::BillboardType billboardType,
				   Effekseer::SIMD::Mat43f& dst,
				   ::Effekseer::SIMD::Vec3f& s,
				   ::Effekseer::SIMD::Vec3f& R,
				   ::Effekseer::SIMD::Vec3f& F,
				   const ::Effekseer::SIMD::Mat43f& src,
				   const ::Effekseer::SIMD::Vec3f& frontDirection);

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand);

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::SIMD::Vec3f& scaleValues,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand);

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  ::Effekseer::SIMD::Vec3f& translationValues,
						  ::Effekseer::SIMD::Vec3f& scaleValues,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand);

void ApplyDepthParameters(::Effekseer::SIMD::Mat44f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand);

void ApplyViewOffset(::Effekseer::SIMD::Mat43f& mat,
					 const ::Effekseer::SIMD::Mat44f& camera,
					 float distance);

void ApplyViewOffset(::Effekseer::SIMD::Mat44f& mat,
					 const ::Effekseer::SIMD::Mat44f& camera,
					 float distance);

template <typename Vertex>
inline void TransformVertexes(Vertex& vertexes, int32_t count, const ::Effekseer::SIMD::Mat43f& mat)
{
	using namespace Effekseer::SIMD;

	Float4 m0 = mat.X;
	Float4 m1 = mat.Y;
	Float4 m2 = mat.Z;
	Float4 m3 = Float4::SetZero();
	Float4::Transpose(m0, m1, m2, m3);

	for (int i = 0; i < count; i++)
	{
		Float4 iPos = Float4::Load3(&vertexes[i].Pos);

		Float4 oPos = Float4::MulAddLane<0>(m3, m0, iPos);
		oPos = Float4::MulAddLane<1>(oPos, m1, iPos);
		oPos = Float4::MulAddLane<2>(oPos, m2, iPos);

		Float4::Store3(&vertexes[i].Pos, oPos);
	}
}

inline Effekseer::SIMD::Vec3f SafeNormalize(const Effekseer::SIMD::Vec3f& v)
{
	auto lengthSq = v.GetSquaredLength();
	auto e = 0.0001f;
	if (lengthSq < e * e)
	{
		return v;
	}

	return v * Effekseer::SIMD::Rsqrt(lengthSq);
}

struct MaterialShaderParameterGenerator
{
	int32_t VertexSize = 0;
	int32_t VertexShaderUniformBufferSize = 0;
	int32_t PixelShaderUniformBufferSize = 0;

	int32_t VertexCameraMatrixOffset = -1;
	int32_t VertexProjectionMatrixOffset = -1;
	int32_t VertexInversedFlagOffset = -1;
	int32_t VertexPredefinedOffset = -1;
	int32_t VertexCameraPositionOffset = -1;
	int32_t VertexUserUniformOffset = -1;

	int32_t PixelInversedFlagOffset = -1;
	int32_t PixelPredefinedOffset = -1;
	int32_t PixelCameraPositionOffset = -1;
	int32_t PixelReconstructionParam1Offset = -1;
	int32_t PixelReconstructionParam2Offset = -1;
	int32_t PixelLightDirectionOffset = -1;
	int32_t PixelLightColorOffset = -1;
	int32_t PixelLightAmbientColorOffset = -1;
	int32_t PixelCameraMatrixOffset = -1;
	int32_t PixelUserUniformOffset = -1;

	int32_t VertexModelMatrixOffset = -1;
	int32_t VertexModelUVOffset = -1;
	int32_t VertexModelColorOffset = -1;

	int32_t VertexModelCustomData1Offset = -1;
	int32_t VertexModelCustomData2Offset = -1;

	MaterialShaderParameterGenerator(const ::Effekseer::MaterialFile& materialFile, bool isModel, int32_t stage, int32_t instanceCount)
	{
		if (isModel)
		{
			VertexSize = sizeof(::Effekseer::Model::Vertex);
		}
		else if (materialFile.GetIsSimpleVertex())
		{
			VertexSize = sizeof(EffekseerRenderer::SimpleVertex);
		}
		else
		{
			VertexSize = sizeof(EffekseerRenderer::DynamicVertex) +
						 sizeof(float) * (materialFile.GetCustomData1Count() + materialFile.GetCustomData2Count());
		}

		if (isModel)
		{
			int32_t vsOffset = 0;
			VertexProjectionMatrixOffset = vsOffset;
			vsOffset += sizeof(Effekseer::SIMD::Mat44f);

			VertexModelMatrixOffset = vsOffset;
			vsOffset += sizeof(Effekseer::SIMD::Mat44f) * instanceCount;

			VertexModelUVOffset = vsOffset;
			vsOffset += sizeof(float) * 4 * instanceCount;

			VertexModelColorOffset = vsOffset;
			vsOffset += sizeof(float) * 4 * instanceCount;

			VertexInversedFlagOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			VertexPredefinedOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			VertexCameraPositionOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			if (materialFile.GetCustomData1Count() > 0)
			{
				VertexModelCustomData1Offset = vsOffset;
				vsOffset += sizeof(float) * 4 * instanceCount;
			}

			if (materialFile.GetCustomData2Count() > 0)
			{
				VertexModelCustomData2Offset = vsOffset;
				vsOffset += sizeof(float) * 4 * instanceCount;
			}

			VertexUserUniformOffset = vsOffset;
			vsOffset += sizeof(float) * 4 * materialFile.GetUniformCount();

			VertexShaderUniformBufferSize = vsOffset;
		}
		else
		{
			int32_t vsOffset = 0;
			VertexCameraMatrixOffset = vsOffset;
			vsOffset += sizeof(Effekseer::SIMD::Mat44f);

			VertexProjectionMatrixOffset = vsOffset;
			vsOffset += sizeof(Effekseer::SIMD::Mat44f);

			VertexInversedFlagOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			VertexPredefinedOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			VertexCameraPositionOffset = vsOffset;
			vsOffset += sizeof(float) * 4;

			VertexUserUniformOffset = vsOffset;
			vsOffset += sizeof(float) * 4 * materialFile.GetUniformCount();

			VertexShaderUniformBufferSize = vsOffset;
		}

		int32_t psOffset = 0;

		PixelInversedFlagOffset = psOffset;
		psOffset += sizeof(float) * 4;

		PixelPredefinedOffset = psOffset;
		psOffset += sizeof(float) * 4;

		PixelCameraPositionOffset = psOffset;
		psOffset += sizeof(float) * 4;

		PixelReconstructionParam1Offset = psOffset;
		psOffset += sizeof(float) * 4;

		PixelReconstructionParam2Offset = psOffset;
		psOffset += sizeof(float) * 4;

		if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Lit)
		{
			PixelLightDirectionOffset = psOffset;
			psOffset += sizeof(float) * 4;

			PixelLightColorOffset = psOffset;
			psOffset += sizeof(float) * 4;

			PixelLightAmbientColorOffset = psOffset;
			psOffset += sizeof(float) * 4;
		}

		if (materialFile.GetHasRefraction() && stage == 1)
		{
			PixelCameraMatrixOffset = psOffset;
			psOffset += sizeof(Effekseer::SIMD::Mat44f);
		}

		PixelUserUniformOffset = psOffset;
		psOffset += sizeof(float) * 4 * materialFile.GetUniformCount();

		PixelShaderUniformBufferSize = psOffset;
	}
};

enum class RendererShaderType
{
	Unlit,
	Lit,
	BackDistortion,
	AdvancedUnlit,
	AdvancedLit,
	AdvancedBackDistortion,
	Material,
};

struct ShaderParameterCollector
{
	RendererShaderType ShaderType{};

	Effekseer::MaterialRenderData* MaterialRenderDataPtr = nullptr;
	Effekseer::MaterialRef MaterialDataPtr = nullptr;

	int32_t TextureCount = 0;
	std::array<::Effekseer::Backend::TextureRef, Effekseer::TextureSlotMax> Textures;
	std::array<::Effekseer::TextureFilterType, Effekseer::TextureSlotMax> TextureFilterTypes;
	std::array<::Effekseer::TextureWrapType, Effekseer::TextureSlotMax> TextureWrapTypes;

	bool IsDepthRequired = false;
	bool IsBackgroundRequiredOnFirstPass = false;
	bool HasMultiPass = false;
	int32_t BackgroundIndex = -1;
	int32_t DepthIndex = -1;

	bool DoRequireAdvancedRenderer() const
	{
		return ShaderType == RendererShaderType::AdvancedUnlit ||
			   ShaderType == RendererShaderType::AdvancedLit ||
			   ShaderType == RendererShaderType::AdvancedBackDistortion;
	}

	bool operator!=(const ShaderParameterCollector& state) const
	{
		if (ShaderType != state.ShaderType)
			return true;

		if (MaterialRenderDataPtr != state.MaterialRenderDataPtr)
			return true;

		if (MaterialDataPtr != state.MaterialDataPtr)
			return true;

		if (IsBackgroundRequiredOnFirstPass != state.IsBackgroundRequiredOnFirstPass)
			return true;

		if (HasMultiPass != state.HasMultiPass)
			return true;

		if (BackgroundIndex != state.BackgroundIndex)
			return true;

		if (TextureCount != state.TextureCount)
			return true;

		for (int32_t i = 0; i < TextureCount; i++)
		{
			if (Textures[i] != state.Textures[i])
				return true;

			if (TextureFilterTypes[i] != state.TextureFilterTypes[i])
				return true;

			if (TextureWrapTypes[i] != state.TextureWrapTypes[i])
				return true;
		}

		return false;
	}

	void Collect(Renderer* renderer, Effekseer::Effect* effect, Effekseer::NodeRendererBasicParameter* param, bool edgeFalloff, bool isSoftParticleEnabled)
	{
		::Effekseer::Backend::TextureRef TexturePtr = nullptr;
		::Effekseer::Backend::TextureRef NormalTexturePtr = nullptr;
		::Effekseer::Backend::TextureRef AlphaTexturePtr = nullptr;
		::Effekseer::Backend::TextureRef UVDistortionTexturePtr = nullptr;
		::Effekseer::Backend::TextureRef BlendTexturePtr = nullptr;
		::Effekseer::Backend::TextureRef BlendAlphaTexturePtr = nullptr;
		::Effekseer::Backend::TextureRef BlendUVDistortionTexturePtr = nullptr;

		Textures.fill(nullptr);
		TextureFilterTypes.fill(::Effekseer::TextureFilterType::Linear);
		TextureWrapTypes.fill(::Effekseer::TextureWrapType::Repeat);

		BackgroundIndex = -1;
		IsBackgroundRequiredOnFirstPass = false;

		DepthIndex = -1;
		IsDepthRequired = isSoftParticleEnabled;
		MaterialRenderDataPtr = nullptr;

		auto isMaterial = param->MaterialType == ::Effekseer::RendererMaterialType::File && param->MaterialRenderDataPtr != nullptr;
		if (isMaterial)
		{
			MaterialDataPtr = effect->GetMaterial(param->MaterialRenderDataPtr->MaterialIndex);

			if (MaterialDataPtr == nullptr)
			{
				isMaterial = false;
			}

			if (isMaterial && MaterialDataPtr->IsSimpleVertex)
			{
				isMaterial = false;
			}

			// Validate parameters
			if (isMaterial && (MaterialDataPtr->TextureCount != param->MaterialRenderDataPtr->MaterialTextures.size() ||
							   MaterialDataPtr->UniformCount != param->MaterialRenderDataPtr->MaterialUniforms.size()))
			{
				isMaterial = false;
			}
		}

		auto isAdvanced = param->GetIsRenderedWithAdvancedRenderer() || edgeFalloff;

		if (isMaterial)
		{
			IsDepthRequired = true;
		}

		if (param->MaterialType == ::Effekseer::RendererMaterialType::File)
		{
			MaterialRenderDataPtr = param->MaterialRenderDataPtr;
			if (MaterialRenderDataPtr != nullptr)
			{
				MaterialDataPtr = effect->GetMaterial(MaterialRenderDataPtr->MaterialIndex);
				if (MaterialDataPtr != nullptr)
				{
					ShaderType = RendererShaderType::Material;
					IsBackgroundRequiredOnFirstPass = MaterialDataPtr->IsRefractionRequired;

					if (IsBackgroundRequiredOnFirstPass)
					{
						HasMultiPass = true;
					}
				}
			}
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::Lighting && isAdvanced)
		{
			ShaderType = RendererShaderType::AdvancedLit;
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion && isAdvanced)
		{
			ShaderType = RendererShaderType::AdvancedBackDistortion;
			IsBackgroundRequiredOnFirstPass = true;
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::Default && isAdvanced)
		{
			ShaderType = RendererShaderType::AdvancedUnlit;
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::Lighting)
		{
			ShaderType = RendererShaderType::Lit;
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
		{
			ShaderType = RendererShaderType::BackDistortion;
			IsBackgroundRequiredOnFirstPass = true;
		}
		else if (param->MaterialType == ::Effekseer::RendererMaterialType::Default)
		{
			ShaderType = RendererShaderType::Unlit;
		}
		else
		{
			// Fallback
			ShaderType = RendererShaderType::Unlit;
		}

		if (MaterialRenderDataPtr != nullptr && MaterialDataPtr != nullptr)
		{
			TextureCount = static_cast<int32_t>(Effekseer::Min(MaterialRenderDataPtr->MaterialTextures.size(), ::Effekseer::UserTextureSlotMax));
			for (size_t i = 0; i < TextureCount; i++)
			{
				if (MaterialRenderDataPtr->MaterialTextures[i].Type == 1)
				{
					if (MaterialRenderDataPtr->MaterialTextures[i].Index >= 0)
					{
						auto resource = effect->GetNormalImage(MaterialRenderDataPtr->MaterialTextures[i].Index);
						Textures[i] = (resource != nullptr) ? resource->GetBackend() : nullptr;
					}
					else
					{
						Textures[i] = nullptr;
					}
				}
				else
				{
					if (MaterialRenderDataPtr->MaterialTextures[i].Index >= 0)
					{
						auto resource = effect->GetColorImage(MaterialRenderDataPtr->MaterialTextures[i].Index);
						Textures[i] = (resource != nullptr) ? resource->GetBackend() : nullptr;
					}
					else
					{
						Textures[i] = nullptr;
					}
				}

				TextureFilterTypes[i] = Effekseer::TextureFilterType::Linear;
				TextureWrapTypes[i] = MaterialDataPtr->TextureWrapTypes[i];
			}

			if (IsBackgroundRequiredOnFirstPass)
			{
				// Store from external
				TextureFilterTypes[TextureCount] = Effekseer::TextureFilterType::Linear;
				TextureWrapTypes[TextureCount] = Effekseer::TextureWrapType::Clamp;
				BackgroundIndex = TextureCount;
			}
			TextureCount += 1;

			if (IsDepthRequired)
			{
				// Store from external
				TextureFilterTypes[TextureCount] = Effekseer::TextureFilterType::Linear;
				TextureWrapTypes[TextureCount] = Effekseer::TextureWrapType::Clamp;
				DepthIndex = TextureCount;
				TextureCount += 1;
			}
		}
		else
		{
			if (isAdvanced)
			{
				if (param->MaterialType == ::Effekseer::RendererMaterialType::Default)
				{
					TextureCount = 6;
				}
				else
				{
					TextureCount = 7;
				}

				if (IsDepthRequired)
				{
					DepthIndex = TextureCount;
					TextureCount += 1;
				}
			}
			else
			{
				if (param->MaterialType == ::Effekseer::RendererMaterialType::Default)
				{
					TextureCount = 1;
				}
				else
				{
					TextureCount = 2;
				}

				if (IsDepthRequired)
				{
					DepthIndex = TextureCount;
					TextureCount += 1;
				}
			}

			// color/distortion
			if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
			{
				auto resource = effect->GetDistortionImage(param->TextureIndexes[0]);
				TexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
			}
			else
			{
				auto resource = effect->GetColorImage(param->TextureIndexes[0]);
				TexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
			}

			if (TexturePtr == nullptr && renderer != nullptr)
			{
				TexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
			}

			Textures[0] = TexturePtr;
			TextureFilterTypes[0] = param->TextureFilters[0];
			TextureWrapTypes[0] = param->TextureWraps[0];

			// normal/background
			if (param->MaterialType != ::Effekseer::RendererMaterialType::Default)
			{
				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					// Store from external
					IsBackgroundRequiredOnFirstPass = true;
					BackgroundIndex = 1;
				}
				else if (param->MaterialType == ::Effekseer::RendererMaterialType::Lighting)
				{
					auto resource = effect->GetNormalImage(param->TextureIndexes[1]);
					NormalTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;

					if (NormalTexturePtr == nullptr && renderer != nullptr)
					{
						NormalTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::Normal);
					}

					Textures[1] = NormalTexturePtr;
				}

				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					TextureFilterTypes[1] = Effekseer::TextureFilterType::Linear;
					TextureWrapTypes[1] = Effekseer::TextureWrapType::Clamp;
				}
				else
				{
					TextureFilterTypes[1] = param->TextureFilters[1];
					TextureWrapTypes[1] = param->TextureWraps[1];
				}
			}

			if (isAdvanced)
			{
				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					auto resource = effect->GetDistortionImage(param->TextureIndexes[2]);
					AlphaTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}
				else
				{
					auto resource = effect->GetColorImage(param->TextureIndexes[2]);
					AlphaTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}

				if (AlphaTexturePtr == nullptr && renderer != nullptr)
				{
					AlphaTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
				}

				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					auto resource = effect->GetDistortionImage(param->TextureIndexes[3]);
					UVDistortionTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}
				else
				{
					auto resource = effect->GetColorImage(param->TextureIndexes[3]);
					UVDistortionTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}

				if (UVDistortionTexturePtr == nullptr && renderer != nullptr)
				{
					UVDistortionTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::Normal);
				}

				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					auto resource = effect->GetDistortionImage(param->TextureIndexes[4]);
					BlendTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}
				else
				{
					auto resource = effect->GetColorImage(param->TextureIndexes[4]);
					BlendTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}

				if (BlendTexturePtr == nullptr && renderer != nullptr)
				{
					BlendTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
				}

				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					auto resource = effect->GetDistortionImage(param->TextureIndexes[5]);
					BlendAlphaTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}
				else
				{
					auto resource = effect->GetColorImage(param->TextureIndexes[5]);
					BlendAlphaTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}

				if (BlendAlphaTexturePtr == nullptr && renderer != nullptr)
				{
					BlendAlphaTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::White);
				}

				if (param->MaterialType == ::Effekseer::RendererMaterialType::BackDistortion)
				{
					auto resource = effect->GetDistortionImage(param->TextureIndexes[6]);
					BlendUVDistortionTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}
				else
				{
					auto resource = effect->GetColorImage(param->TextureIndexes[6]);
					BlendUVDistortionTexturePtr = (resource != nullptr) ? resource->GetBackend() : nullptr;
				}

				if (BlendUVDistortionTexturePtr == nullptr && renderer != nullptr)
				{
					BlendUVDistortionTexturePtr = renderer->GetImpl()->GetProxyTexture(EffekseerRenderer::ProxyTextureType::Normal);
				}

				int offset = 1;

				if (param->MaterialType != ::Effekseer::RendererMaterialType::Default)
				{
					offset += 1;
				}

				Textures[offset + 0] = AlphaTexturePtr;
				TextureFilterTypes[offset + 0] = param->TextureFilters[2];
				TextureWrapTypes[offset + 0] = param->TextureWraps[2];

				Textures[offset + 1] = UVDistortionTexturePtr;
				TextureFilterTypes[offset + 1] = param->TextureFilters[3];
				TextureWrapTypes[offset + 1] = param->TextureWraps[3];

				Textures[offset + 2] = BlendTexturePtr;
				TextureFilterTypes[offset + 2] = param->TextureFilters[4];
				TextureWrapTypes[offset + 2] = param->TextureWraps[4];

				Textures[offset + 3] = BlendAlphaTexturePtr;
				TextureFilterTypes[offset + 3] = param->TextureFilters[5];
				TextureWrapTypes[offset + 3] = param->TextureWraps[5];

				Textures[offset + 4] = BlendUVDistortionTexturePtr;
				TextureFilterTypes[offset + 4] = param->TextureFilters[6];
				TextureWrapTypes[offset + 4] = param->TextureWraps[6];
			}
		}
	}
};

struct SoftParticleParameter
{
	std::array<float, 4> softParticleParams;
	std::array<float, 4> reconstructionParam1;
	std::array<float, 4> reconstructionParam2;

	void SetParam(float distanceFar, float distanceNear, float distanceNearOffset, float magnification, float rescale1, float rescale2, float v33, float v34, float v43, float v44)
	{
		softParticleParams[0] = distanceFar * magnification;
		softParticleParams[1] = distanceNear * magnification;
		softParticleParams[2] = distanceNearOffset * magnification;
		softParticleParams[3] = distanceFar != 0.0f || distanceNear != 0.0f || distanceNearOffset != 0.0f ? 1.0f : 0.0f;

		reconstructionParam1[0] = rescale1;
		reconstructionParam1[1] = rescale2;

		reconstructionParam2[0] = v33;
		reconstructionParam2[1] = v34;
		reconstructionParam2[2] = v43;
		reconstructionParam2[3] = v44;
	}
};

struct FlipbookParameter
{
	union
	{
		float Buffer[4];

		struct
		{
			float EnableInterpolation;
			float InterpolationType;
		};
	};
};

struct UVDistortionParameter
{
	union
	{
		float Buffer[4];

		struct
		{
			float Intensity;
			float BlendIntensity;
			float UVInversed[2];
		};
	};
};

struct BlendTextureParameter
{
	union
	{
		float Buffer[4];

		struct
		{
			float BlendType;
		};
	};
};

struct EmmisiveParameter
{
	union
	{
		float Buffer[4];

		struct
		{
			float EmissiveScaling;
		};
	};
};

struct EdgeParameter
{
	std::array<float, 4> EdgeColor;

	union
	{
		float Buffer[4];

		struct
		{
			float Threshold;
			float ColorScaling;
		};
	};
};

struct FalloffParameter
{
	union
	{
		float Buffer[4];

		struct
		{
			float Enable;
			float ColorBlendType;
			float Pow;
		};
	};

	std::array<float, 4> BeginColor;
	std::array<float, 4> EndColor;
};

struct PixelConstantBuffer
{
	//! Lit only
	std::array<float, 4> LightDirection;
	std::array<float, 4> LightColor;
	std::array<float, 4> LightAmbientColor;

	FlipbookParameter FlipbookParam;
	UVDistortionParameter UVDistortionParam;
	BlendTextureParameter BlendTextureParam;

	//! model only
	float CameraFrontDirection[4];

	//! model only
	FalloffParameter FalloffParam;

	EmmisiveParameter EmmisiveParam;
	EdgeParameter EdgeParam;
	SoftParticleParameter SoftParticleParam;

	void SetModelFlipbookParameter(float enableInterpolation, float interpolationType)
	{
		FlipbookParam.EnableInterpolation = enableInterpolation;
		FlipbookParam.InterpolationType = interpolationType;
	}

	void SetModelUVDistortionParameter(float intensity, float blendIntensity, const std::array<float, 2>& uvInversed)
	{
		UVDistortionParam.Intensity = intensity;
		UVDistortionParam.BlendIntensity = blendIntensity;
		UVDistortionParam.UVInversed[0] = uvInversed[0];
		UVDistortionParam.UVInversed[1] = uvInversed[1];
	}

	void SetModelBlendTextureParameter(float blendType)
	{
		BlendTextureParam.BlendType = blendType;
	}

	void SetCameraFrontDirection(float x, float y, float z)
	{
		CameraFrontDirection[0] = x;
		CameraFrontDirection[1] = y;
		CameraFrontDirection[2] = z;
		CameraFrontDirection[3] = 0.0f;
	}

	void SetFalloffParameter(float enable, float colorBlendType, float pow, const std::array<float, 4>& beginColor, const std::array<float, 4>& endColor)
	{
		FalloffParam.Enable = enable;
		FalloffParam.ColorBlendType = colorBlendType;
		FalloffParam.Pow = pow;

		for (size_t i = 0; i < 4; i++)
		{
			FalloffParam.BeginColor[i] = beginColor[i];
		}

		for (size_t i = 0; i < 4; i++)
		{
			FalloffParam.EndColor[i] = endColor[i];
		}
	}

	void SetEmissiveScaling(float emissiveScaling)
	{
		EmmisiveParam.EmissiveScaling = emissiveScaling;
	}

	void SetEdgeParameter(const std::array<float, 4>& edgeColor, float threshold, float colorScaling)
	{
		for (size_t i = 0; i < 4; i++)
		{
			EdgeParam.EdgeColor[i] = edgeColor[i];
		}
		EdgeParam.Threshold = threshold;
		EdgeParam.ColorScaling = colorScaling;
	}
};

struct PixelConstantBufferDistortion
{
	float DistortionIntencity[4];
	float UVInversedBack[4];

	//! unused in none advanced renderer
	FlipbookParameter FlipbookParam;
	UVDistortionParameter UVDistortionParam;
	BlendTextureParameter BlendTextureParam;
	SoftParticleParameter SoftParticleParam;
};

void CalculateAlignedTextureInformation(Effekseer::Backend::TextureFormatType format, const std::array<int, 2>& size, int32_t& sizePerWidth, int32_t& height);

} // namespace EffekseerRenderer
#endif // __EFFEKSEERRENDERER_COMMON_UTILS_H__
