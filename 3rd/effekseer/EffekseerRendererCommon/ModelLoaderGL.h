#ifndef __EFFEKSEERRENDERER_MODELLOADER_H__
#define __EFFEKSEERRENDERER_MODELLOADER_H__

#include <Effekseer.h>

namespace EffekseerRenderer
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
	virtual ~ModelLoader();

public:
	Effekseer::ModelRef Load(const char16_t* path) override;

	Effekseer::ModelRef Load(const void* data, int32_t size) override;

	void Unload(Effekseer::ModelRef data) override;
};

} // namespace EffekseerRenderer

#endif // __EFFEKSEERRENDERER_MODELLOADER_H__
