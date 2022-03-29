#include <locale>
#include <codecvt>
#include "EffekseerRendererBGFX.ModelLoader.h"
#include "EffekseerRendererBGFX.RenderResources.h"

static std::string w2u(const std::u16string& source)
{
	return std::wstring_convert<std::codecvt_utf8<char16_t>, char16_t>().to_bytes(source);
}
static std::u16string u2w(const std::string& source)
{
	return std::wstring_convert<std::codecvt_utf8<char16_t>, char16_t>().from_bytes(source);
}

std::string get_ant_file_path(const std::string& path);

namespace EffekseerRendererBGFX
{
	ModelLoader::ModelLoader(::Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
		::Effekseer::FileInterface* fileInterface)
		: graphicsDevice_(graphicsDevice)
		, fileInterface_(fileInterface)
	{
		if (!fileInterface) {
			fileInterface_ = &defaultFileInterface_;
		}
	}
	Effekseer::ModelRef ModelLoader::Load(const char16_t* path)
	{
		auto ant_path = u2w(get_ant_file_path(w2u(path)));

		std::unique_ptr<::Effekseer::FileReader> reader(fileInterface_->OpenRead(ant_path.data()));
		if (reader.get() == nullptr)
		{
			return nullptr;
		}

		size_t size = reader->GetLength();
		std::unique_ptr<uint8_t[]> data(new uint8_t[size]);
		reader->Read(data.get(), size);

		auto model = Load(data.get(), (int32_t)size);

		return model;
	}

	Effekseer::ModelRef ModelLoader::Load(const void* data, int32_t size)
	{
		return Effekseer::MakeRefPtr<Backend::Model>(data, size);
	}

	void ModelLoader::Unload(Effekseer::ModelRef data)
	{
	}

}