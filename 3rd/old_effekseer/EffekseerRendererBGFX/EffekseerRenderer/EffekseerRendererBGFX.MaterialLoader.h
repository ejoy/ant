#pragma once
#include "EffekseerRendererBGFX.RendererImplemented.h"

namespace Effekseer
{
class Material;
class CompiledMaterialBinary;
} // namespace Effekseer

namespace EffekseerRendererBGFX
{

class MaterialLoader : public ::Effekseer::MaterialLoader
{
private:
	Renderer* renderer_;
	std::string currentPath_;
	bool canLoadFromCache_ = false;
	::Effekseer::FileInterface* fileInterface_ = nullptr;
	::Effekseer::DefaultFileInterface defaultFileInterface_;
	::Effekseer::MaterialRef LoadAcutually(::Effekseer::MaterialFile& materialFile, ::Effekseer::CompiledMaterialBinary* binary);
public:
	MaterialLoader(Renderer* renderer, ::Effekseer::FileInterface* fileInterface, bool canLoadFromCache = false);
	virtual ~MaterialLoader();
	::Effekseer::MaterialRef Load(const char16_t* path) override;
	::Effekseer::MaterialRef Load(const void* data, int32_t size, Effekseer::MaterialFileType fileType) override;
	void Unload(::Effekseer::MaterialRef data) override;
};

} // namespace EffekseerRendererBGFX
