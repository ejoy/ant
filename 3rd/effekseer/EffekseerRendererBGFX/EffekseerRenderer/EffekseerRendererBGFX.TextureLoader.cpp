#include "EffekseerRendererBGFX.TextureLoader.h"
#include "../EffekseerRendererCommon/PathUtils.h"

namespace EffekseerRendererBGFX
{
	TextureLoader::TextureLoader(::Effekseer::Backend::GraphicsDevice* graphicsDevice,
								 ::Effekseer::FileInterface* fileInterface,
								 ::Effekseer::ColorSpaceType colorSpaceType)
		: graphics_device_{ graphicsDevice }
		, color_space_type_{ colorSpaceType }
	{
		if (!fileInterface) {
			file_interface_ = &default_file_interface_;
		} else {
			file_interface_ = fileInterface;
		}
	}
	
	Effekseer::TextureRef TextureLoader::Load(const char16_t* path, Effekseer::TextureType textureType)
	{
		auto ant_path = u2w(get_ant_file_path(w2u(path)));
		std::unique_ptr<::Effekseer::FileReader> reader(file_interface_->OpenRead(ant_path.data()));
		if (reader.get()) {
			::Effekseer::Backend::TextureParameter param;
			size_t fileSize = reader->GetLength();
			param.InitialData.resize(fileSize);
			reader->Read(param.InitialData.data(), fileSize);

			if (color_space_type_ == ::Effekseer::ColorSpaceType::Linear && textureType == Effekseer::TextureType::Color) {
				param.Format = ::Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM_SRGB;
			} else {
				param.Format = ::Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM;
			}
			auto path16 = std::u16string(ant_path.data());
			param.GenerateMipmap = (path16.find(u"_NoMip") == std::u16string::npos);
			param.Size[0] = 0;
			param.Size[1] = 0;

			auto texture = ::Effekseer::MakeRefPtr<::Effekseer::Texture>();
			texture->SetBackend(graphics_device_->CreateTexture(param));
			return texture;
		}
		return nullptr;		
	}

	void TextureLoader::Unload(Effekseer::TextureRef textureData)
	{

	}
}