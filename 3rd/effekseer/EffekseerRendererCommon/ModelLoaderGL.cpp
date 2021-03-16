#include "ModelLoaderGL.h"

namespace EffekseerRenderer
{

ModelLoader::ModelLoader(::Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
						 ::Effekseer::FileInterface* fileInterface)
	: graphicsDevice_(graphicsDevice)
	, fileInterface_(fileInterface)
{
	if (fileInterface == nullptr)
	{
		fileInterface_ = &defaultFileInterface_;
	}
}

ModelLoader::~ModelLoader()
{
}

::Effekseer::ModelRef ModelLoader::Load(const char16_t* path)
{
	std::unique_ptr<::Effekseer::FileReader> reader(fileInterface_->OpenRead(path));
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

::Effekseer::ModelRef ModelLoader::Load(const void* data, int32_t size)
{
	auto model = ::Effekseer::MakeRefPtr<::Effekseer::Model>((const uint8_t*)data, size);

	return model;
}

void ModelLoader::Unload(::Effekseer::ModelRef data)
{
}

} // namespace EffekseerRenderer
