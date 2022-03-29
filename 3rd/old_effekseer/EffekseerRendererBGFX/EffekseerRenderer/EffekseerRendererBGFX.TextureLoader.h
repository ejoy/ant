#pragma once

#include <Effekseer.h>

namespace EffekseerRendererBGFX
{
	class TextureLoader : public Effekseer::TextureLoader
	{
	public:
		TextureLoader(::Effekseer::Backend::GraphicsDevice* graphicsDevice,
					  ::Effekseer::FileInterface* fileInterface = nullptr,
					  ::Effekseer::ColorSpaceType colorSpaceType = ::Effekseer::ColorSpaceType::Gamma);
		virtual ~TextureLoader() = default;
		Effekseer::TextureRef Load(const char16_t* path, Effekseer::TextureType textureType) override;
		void Unload(Effekseer::TextureRef texture) override;
	private:
		::Effekseer::FileInterface* file_interface_{ nullptr };
		::Effekseer::ColorSpaceType color_space_type_;
		::Effekseer::DefaultFileInterface default_file_interface_;
		::Effekseer::Backend::GraphicsDevice* graphics_device_{ nullptr };

	};
}