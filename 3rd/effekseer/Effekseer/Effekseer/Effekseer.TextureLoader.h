
#ifndef __EFFEKSEER_TEXTURELOADER_H__
#define __EFFEKSEER_TEXTURELOADER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Backend/GraphicsDevice.h"
#include "Effekseer.Base.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	テクスチャ読み込み破棄関数指定クラス
*/
class TextureLoader : public ReferenceObject
{
public:
	/**
		@brief	コンストラクタ
	*/
	TextureLoader()
	{
	}

	/**
		@brief	デストラクタ
	*/
	virtual ~TextureLoader()
	{
	}

	/**
		@brief	テクスチャを読み込む。
		@param	path	[in]	読み込み元パス
		@param	textureType	[in]	テクスチャの種類
		@return	テクスチャのポインタ
		@note
		テクスチャを読み込む。
		::Effekseer::Effect::Create実行時に使用される。
	*/
	virtual TextureRef Load(const char16_t* path, TextureType textureType)
	{
		return nullptr;
	}

	/**
		@brief
		\~English	a function called when texture is loaded
		\~Japanese	テクスチャが読み込まれるときに呼ばれる関数
		@param	data
		\~English	data pointer
		\~Japanese	データのポインタ
		@param	size
		\~English	the size of data
		\~Japanese	データの大きさ
		@param	textureType
		\~English	a kind of texture
		\~Japanese	テクスチャの種類
		@param	isMipMapEnabled
		\~English	whether is a mipmap enabled
		\~Japanese	MipMapが有効かどうか
		@return
		\~English	a pointer of loaded texture
		\~Japanese	読み込まれたテクスチャのポインタ
	*/
	virtual TextureRef Load(const void* data, int32_t size, TextureType textureType, bool isMipMapEnabled)
	{
		return nullptr;
	}

	/**
		@brief	テクスチャを破棄する。
		@param	data	[in]	テクスチャ
		@note
		テクスチャを破棄する。
		::Effekseer::Effectのインスタンスが破棄された時に使用される。
	*/
	virtual void Unload(TextureRef data)
	{
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_TEXTURELOADER_H__
