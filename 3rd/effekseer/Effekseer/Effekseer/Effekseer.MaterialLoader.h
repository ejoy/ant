
#ifndef __EFFEKSEER_MATERIALLOADER_H__
#define __EFFEKSEER_MATERIALLOADER_H__

#include "Effekseer.Base.Pre.h"
#include "Effekseer.Base.h"

namespace Effekseer
{

/**
	@brief
	\~English	Material loader
	\~Japanese	マテリアル読み込み破棄関数指定クラス
*/
class MaterialLoader : public ReferenceObject
{
public:
	/**
	@brief
	\~English	Constructor
	\~Japanese	コンストラクタ
	*/
	MaterialLoader() = default;

	/**
	@brief
	\~English	Destructor
	\~Japanese	デストラクタ
	*/
	virtual ~MaterialLoader() = default;

	/**
		@brief
		\~English	load a material
		\~Japanese	マテリアルを読み込む。
		@param	path
		\~English	a file path
		\~Japanese	読み込み元パス
		@return
		\~English	a pointer of loaded a material
		\~Japanese	読み込まれたマテリアルのポインタ
	*/
	virtual MaterialRef Load(const char16_t* path)
	{
		return nullptr;
	}

	/**
		@brief
		\~English	a function called when a material is loaded
		\~Japanese	マテリアルが読み込まれるときに呼ばれる関数
		@param	data
		\~English	data pointer
		\~Japanese	データのポインタ
		@param	size
		\~English	the size of data
		\~Japanese	データの大きさ
		@param	fileType
		\~English	file type
		\~Japanese	ファイルの種類
		@return
		\~English	a pointer of loaded a material
		\~Japanese	読み込まれたマテリアルのポインタ
	*/
	virtual MaterialRef Load(const void* data, int32_t size, MaterialFileType fileType)
	{
		return nullptr;
	}

	/**
		@brief
		\~English	dispose a material
		\~Japanese	マテリアルを破棄する。
		@param	data
		\~English	a pointer of loaded a material
		\~Japanese	読み込まれたマテリアルのポインタ
	*/
	virtual void Unload(MaterialRef data)
	{
	}
};

} // namespace Effekseer

#endif // __EFFEKSEER_TEXTURELOADER_H__
