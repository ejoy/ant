
#pragma once

#include "Effekseer/Material/Effekseer.MaterialCompiler.h"
#include <vector>

namespace Effekseer
{

class MaterialCompilerBGFX : public MaterialCompiler, public ReferenceObject
{
private:
public:
	MaterialCompilerBGFX() = default;

	virtual ~MaterialCompilerBGFX() = default;

	CompiledMaterialBinary* Compile(MaterialFile* materialFile, int32_t maximumTextureCount);

	CompiledMaterialBinary* Compile(MaterialFile* materialFile) override;

	int AddRef() override
	{
		return ReferenceObject::AddRef();
	}

	int Release() override
	{
		return ReferenceObject::Release();
	}

	int GetRef() override
	{
		return ReferenceObject::GetRef();
	}
};

} // namespace Effekseer
