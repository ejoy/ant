#pragma once
#include <Effekseer.h>

namespace EffekseerRendererBGFX
{

	class ModelLoader : public ::Effekseer::ModelLoader
	{
	private:
		::Effekseer::Backend::GraphicsDeviceRef graphicsDevice_;
		::Effekseer::DefaultFileInterface defaultFileInterface_;
		::Effekseer::FileInterface* fileInterface_;
	public:
		ModelLoader(::Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
			::Effekseer::FileInterface* fileInterface = nullptr);

		virtual ~ModelLoader() = default;

		Effekseer::ModelRef Load(const char16_t* path) override;

		Effekseer::ModelRef Load(const void* data, int32_t size) override;

		void Unload(Effekseer::ModelRef data) override;
	};

}