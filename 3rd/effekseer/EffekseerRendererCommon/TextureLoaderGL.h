#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__

#ifndef __EFFEKSEERRENDERER_TEXTURELOADER_H__
#define __EFFEKSEERRENDERER_TEXTURELOADER_H__

#include <Effekseer.h>

#include "../EffekseerRendererCommon/EffekseerRenderer.DDSTextureLoader.h"
#include "../EffekseerRendererCommon/EffekseerRenderer.PngTextureLoader.h"
#include "../EffekseerRendererCommon/EffekseerRenderer.TGATextureLoader.h"

namespace EffekseerRenderer
{

class TextureLoader : public ::Effekseer::TextureLoader
{
private:
	::Effekseer::FileInterface* m_fileInterface;
	::Effekseer::DefaultFileInterface m_defaultFileInterface;
	::Effekseer::ColorSpaceType colorSpaceType_;
	::Effekseer::Backend::GraphicsDevice* graphicsDevice_ = nullptr;
#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__
	::EffekseerRenderer::PngTextureLoader pngTextureLoader_;
	::EffekseerRenderer::DDSTextureLoader ddsTextureLoader_;
	::EffekseerRenderer::TGATextureLoader tgaTextureLoader_;
#endif

public:
	TextureLoader(::Effekseer::Backend::GraphicsDevice* graphicsDevice,
				  ::Effekseer::FileInterface* fileInterface = nullptr,
				  ::Effekseer::ColorSpaceType colorSpaceType = ::Effekseer::ColorSpaceType::Gamma);
	virtual ~TextureLoader();

public:
	Effekseer::TextureRef Load(const char16_t* path, ::Effekseer::TextureType textureType) override;

	Effekseer::TextureRef Load(const void* data, int32_t size, Effekseer::TextureType textureType, bool isMipMapEnabled) override;

	void Unload(Effekseer::TextureRef data) override;
};

} // namespace EffekseerRenderer

#endif // __EFFEKSEERRENDERER_TEXTURELOADER_H__

#endif // __EFFEKSEER_RENDERER_INTERNAL_LOADER__