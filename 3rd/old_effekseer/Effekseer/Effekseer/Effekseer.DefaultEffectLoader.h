
#ifndef __EFFEKSEER_DEFAULTEFFECTLOADER_H__
#define __EFFEKSEER_DEFAULTEFFECTLOADER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.DefaultFile.h"
#include "Effekseer.EffectLoader.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	標準のエフェクトファイル読み込み破棄関数指定クラス
*/
class DefaultEffectLoader : public EffectLoader
{
	DefaultFileInterface m_defaultFileInterface;
	FileInterface* m_fileInterface;

public:
	DefaultEffectLoader(FileInterface* fileInterface = nullptr);

	virtual ~DefaultEffectLoader();

	bool Load(const char16_t* path, void*& data, int32_t& size);

	void Unload(void* data, int32_t size);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_DEFAULTEFFECTLOADER_H__
