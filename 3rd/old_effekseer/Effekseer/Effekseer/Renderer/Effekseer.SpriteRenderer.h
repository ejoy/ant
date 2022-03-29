
#ifndef __EFFEKSEER_SPRITE_RENDERER_H__
#define __EFFEKSEER_SPRITE_RENDERER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "../Effekseer.Base.h"
#include "../Effekseer.Color.h"
#include "../Effekseer.Matrix43.h"
#include "../Effekseer.Vector2D.h"
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

class SpriteRenderer : public ReferenceObject
{
public:
	struct NodeParameter
	{
		Effect* EffectPointer;
		bool ZTest;
		bool ZWrite;
		BillboardType Billboard;
		bool IsRightHand;
		float Maginification = 1.0f;

		ZSortType ZSort;

		NodeRendererDepthParameter* DepthParameterPtr = nullptr;
		NodeRendererBasicParameter* BasicParameterPtr = nullptr;

		bool EnableViewOffset = false;

		RefPtr<RenderingUserData> UserData;
	};

	struct InstanceParameter
	{
		SIMD::Mat43f SRTMatrix43;
		Color AllColor;

		// Lower left, Lower right, Upper left, Upper right
		Color Colors[4];

		SIMD::Vec2f Positions[4];

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
	SpriteRenderer()
	{
	}

	virtual ~SpriteRenderer()
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
#endif // __EFFEKSEER_SPRITE_RENDERER_H__
