
#ifndef __EFFEKSEER_PARTICLE_RENDERER_H__
#define __EFFEKSEER_PARTICLE_RENDERER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "../Effekseer.Base.h"
#include "../Effekseer.Color.h"
#include "../Effekseer.Matrix43.h"
#include "../Effekseer.Vector3D.h"
#include "../SIMD/Mat43f.h"
#include "../SIMD/Vec3f.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class ParticleRenderer
{
public:
	struct NodeParameter
	{
		Effect* EffectPointer;
		// int32_t				TextureIndex;
		// AlphaBlendType			AlphaBlend;
		// TextureFilterType	TextureFilter;
		// TextureWrapType	TextureWrap;

		// bool				Distortion;
		// float				DistortionIntensity;
	};

	struct InstanceParameter
	{
		SIMD::Vec3f Position;
		float Size;
		Color ParticleColor;
	};

public:
	ParticleRenderer()
	{
	}

	virtual ~ParticleRenderer()
	{
	}

	virtual void BeginRendering(const NodeParameter& parameter, void* userData)
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
#endif // __EFFEKSEER_PARTICLE_RENDERER_H__
