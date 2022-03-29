#ifndef __EFFEKSEER_PROCEDURAL_MODEL_GENERATOR_H__
#define __EFFEKSEER_PROCEDURAL_MODEL_GENERATOR_H__

#include "../Effekseer.Base.h"
#include "../SIMD/Vec2f.h"
#include "../SIMD/Vec3f.h"
#include "../Utils/Effekseer.CustomAllocator.h"

namespace Effekseer
{

class ProceduralModelGenerator : public ReferenceObject
{
public:
	ProceduralModelGenerator() = default;
	virtual ~ProceduralModelGenerator() = default;

	virtual ModelRef Generate(const ProceduralModelParameter& parameter);

	virtual void Ungenerate(ModelRef model);
};

} // namespace Effekseer

#endif