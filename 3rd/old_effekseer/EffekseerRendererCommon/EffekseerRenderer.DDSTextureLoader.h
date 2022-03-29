#ifndef __EFFEKSEERRENDERER_DDS_TEXTURE_LOADER_H__
#define __EFFEKSEERRENDERER_DDS_TEXTURE_LOADER_H__

#include <Effekseer.h>
#include <assert.h>
#include <string.h>
#include <vector>

namespace EffekseerRenderer
{
class DDSTextureLoader
{
public:
	class Texture
	{
	public:
		const int32_t Width;
		const int32_t Height;
		const ::Effekseer::CustomVector<uint8_t> Data;

		Texture(int32_t width, int32_t height, ::Effekseer::CustomVector<uint8_t> data)
			: Width(width)
			, Height(height)
			, Data(std::move(data))
		{
		}
	};

private:
	::Effekseer::CustomVector<Texture> textures_;

	int32_t textureWidth = 0;
	int32_t textureHeight = 0;
	Effekseer::TextureFormatType textureFormatType = Effekseer::TextureFormatType::ABGR8;
	Effekseer::Backend::TextureFormatType backendTextureFormatType = Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM;

public:
	bool Load(const void* data, int32_t size);
	void Unload();

	const ::Effekseer::CustomVector<Texture>& GetTextures() const
	{
		return textures_;
	}

	Effekseer::TextureFormatType GetTextureFormat()
	{
		return textureFormatType;
	}

	Effekseer::Backend::TextureFormatType GetBackendTextureFormat() const
	{
		return backendTextureFormatType;
	}
};
} // namespace EffekseerRenderer

#endif // __EFFEKSEERRENDERER_DDS_TEXTURE_LOADER_H__