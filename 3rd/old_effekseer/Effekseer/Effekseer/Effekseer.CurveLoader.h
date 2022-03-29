
#ifndef __EFFEKSEER_CURVELOADER_H__
#define __EFFEKSEER_CURVELOADER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"

#include "Effekseer.Curve.h"
#include "Effekseer.DefaultFile.h"
#include "Effekseer.File.h"
#include <memory>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

/**
	\~English	Curve loader
	\~Japanese	カーブ読み込み破棄関数指定クラス
*/
class CurveLoader : public ReferenceObject
{
private:
	::Effekseer::DefaultFileInterface defaultFileInterface_;
	::Effekseer::FileInterface* fileInterface_ = nullptr;

public:
	CurveLoader(::Effekseer::FileInterface* fileInterface = nullptr);

	virtual ~CurveLoader() = default;

	/*
	@brief
	\~English load a curve
	\~Japanese カーブを読み込む。
	@param path
	\~English a file path
	\~Japanese 読み込み元パス
	@ return
	\~English a pointer of loaded a curve
	\~Japanese 読み込まれたカーブのポインタ
	*/
	virtual CurveRef Load(const char16_t* path);

	/*
	@brief
	\~English load a curve
	\~Japanese カーブを読み込む。
	@param	data
	\~English	data pointer
	\~Japanese	データのポインタ
	@param	size
	\~English	the size of data
	\~Japanese	データの大きさ
	@ return
	\~English a pointer of loaded a curve
	\~Japanese 読み込まれたカーブのポインタ
	*/
	virtual CurveRef Load(const void* data, int32_t size);

	/**
		@brief
		\~English	dispose a curve
		\~Japanese	カーブを破棄する。
		@param	data
		\~English	a pointer of loaded a curve
		\~Japanese	読み込まれたカーブのポインタ
	*/
	virtual void Unload(CurveRef data);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
  //----------------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------------
#endif // __EFFEKSEER_MODELLOADER_H__
