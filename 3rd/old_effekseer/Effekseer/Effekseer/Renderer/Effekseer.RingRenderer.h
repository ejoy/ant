
#ifndef __EFFEKSEER_RING_RENDERER_H__
#define __EFFEKSEER_RING_RENDERER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "../Effekseer.Base.h"
#include "../Effekseer.Color.h"
#include "../Effekseer.Matrix43.h"
#include "../Effekseer.Vector2D.h"
#include "../Effekseer.Vector3D.h"
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

class RingRenderer : public ReferenceObject
{
public:
	struct NodeParameter
	{
		Effect* EffectPointer;
		bool ZTest;
		bool ZWrite;
		BillboardType Billboard;
		int32_t VertexCount;
		bool IsRightHand;
		float Maginification = 1.0f;

		float StartingFade = 0.0f;
		float EndingFade = 0.0f;

		NodeRendererDepthParameter* DepthParameterPtr = nullptr;
		NodeRendererBasicParameter* BasicParameterPtr = nullptr;

		NodeRendererBasicParameter BasicParameter;

		bool EnableViewOffset = false;

		RefPtr<RenderingUserData> UserData;
	};

	struct InstanceParameter
	{
		SIMD::Mat43f SRTMatrix43;
		SIMD::Vec2f OuterLocation;
		SIMD::Vec2f InnerLocation;
		float ViewingAngleStart;
		float ViewingAngleEnd;
		float CenterRatio;
		Color OuterColor;
		Color CenterColor;
		Color InnerColor;

		RectF UV;

		RectF AlphaUV;

		RectF UVDistortionUV;

		RectF BlendUV;

		RectF BlendAlphaUV;

		RectF BlendUVDistortionUV;

		float FlipbookIndexAndNextRate;

		float AlphaThreshold;

		float ViewOffsetDistance;

		std::array<float, 4> CustomData1;
		std::array<float, 4> CustomData2;
	};

public:
	RingRenderer()
	{
	}

	virtual ~RingRenderer()
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
#endif // __EFFEKSEER_RING_RENDERER_H__
