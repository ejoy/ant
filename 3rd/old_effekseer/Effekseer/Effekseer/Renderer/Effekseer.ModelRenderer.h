
#ifndef __EFFEKSEER_MODEL_RENDERER_H__
#define __EFFEKSEER_MODEL_RENDERER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "../Effekseer.Base.h"
#include "../Effekseer.Color.h"
#include "../Effekseer.Matrix43.h"
#include "../Effekseer.Vector2D.h"
#include "../Effekseer.Vector3D.h"
#include "../Parameter/Effekseer.Parameters.h"
#include "../SIMD/Mat43f.h"
#include "../SIMD/Vec2f.h"
#include "../SIMD/Vec3f.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

class ModelRenderer : public ReferenceObject
{
public:
	struct NodeParameter
	{
		Effect* EffectPointer;
		bool ZTest;
		bool ZWrite;
		BillboardType Billboard;

		// bool				Lighting;
		CullingType Culling;
		int32_t ModelIndex;
		float Magnification;
		bool IsRightHand;
		float Maginification = 1.0f;

		NodeRendererDepthParameter* DepthParameterPtr = nullptr;
		NodeRendererBasicParameter* BasicParameterPtr = nullptr;

		bool EnableFalloff;
		FalloffParameter FalloffParam;

		bool EnableViewOffset = false;

		bool IsProceduralMode = false;

		RefPtr<RenderingUserData> UserData;
	};

	struct InstanceParameter
	{
		SIMD::Mat43f SRTMatrix43;
		RectF UV;

		RectF AlphaUV;

		RectF UVDistortionUV;

		RectF BlendUV;

		RectF BlendAlphaUV;

		RectF BlendUVDistortionUV;

		float FlipbookIndexAndNextRate;

		float AlphaThreshold;

		float ViewOffsetDistance;

		Color AllColor;
		int32_t Time;
		std::array<float, 4> CustomData1;
		std::array<float, 4> CustomData2;
	};

public:
	ModelRenderer()
	{
	}

	virtual ~ModelRenderer()
	{
	}

	virtual void BeginRendering(const NodeParameter& parameter, int32_t count, void* userData)
	{
	}

	virtual void Rendering(const NodeParameter& parameter, const InstanceParameter& instanceParameter, void* userData)
	{
	}

	virtual void EndRendering(const NodeParameter& parameter, void* userData)
	{
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_MODEL_RENDERER_H__
