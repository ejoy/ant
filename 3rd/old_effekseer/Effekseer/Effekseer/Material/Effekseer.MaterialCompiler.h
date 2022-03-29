#ifndef __EFFEKSEER_MATERIAL_COMPILER_H__
#define __EFFEKSEER_MATERIAL_COMPILER_H__

#include "../Effekseer.Base.h"
#include "Effekseer.MaterialFile.h"
#include <map>
#include <stdint.h>
#include <stdio.h>
#include <vector>

namespace Effekseer
{

enum class MaterialShaderType : int32_t
{
	Standard,
	Model,
	Refraction,
	RefractionModel,
	Max,
};

class CompiledMaterialBinary : public IReference
{
private:
public:
	CompiledMaterialBinary() = default;
	virtual ~CompiledMaterialBinary() = default;

	virtual const uint8_t* GetVertexShaderData(MaterialShaderType type) const = 0;

	virtual int32_t GetVertexShaderSize(MaterialShaderType type) const = 0;

	virtual const uint8_t* GetPixelShaderData(MaterialShaderType type) const = 0;

	virtual int32_t GetPixelShaderSize(MaterialShaderType type) const = 0;
};

class MaterialCompiler : public IReference
{

public:
	MaterialCompiler() = default;

	virtual ~MaterialCompiler() = default;

	/**
	 * @bbrief compile and store data into the cache
	 */
	virtual CompiledMaterialBinary* Compile(MaterialFile* materialFile) = 0;
};

} // namespace Effekseer

#endif
