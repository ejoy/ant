
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
	CurveLoader(::Effekseer::FileInterface* fileInterface = nullptr)
	{
		if (fileInterface != nullptr)
		{
			fileInterface_ = fileInterface;
		}
		else
		{
			fileInterface_ = &defaultFileInterface_;
		}
	}

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
	virtual Effekseer::CurveRef Load(const char16_t* path)
	{

		std::unique_ptr<::Effekseer::FileReader> reader(fileInterface_->OpenRead(path));
		if (reader.get() == nullptr)
		{
			return nullptr;
		}

		auto curve = Effekseer::MakeRefPtr<Effekseer::Curve>();

		// load converter version
		int converter_version = 0;
		reader->Read(&converter_version, sizeof(int));

		// load controll point count
		reader->Read(&curve->mControllPointCount, sizeof(int));

		// load controll points
		for (int i = 0; i < curve->mControllPointCount; i++)
		{
			dVector4 value;
			reader->Read(&value, sizeof(dVector4));
			curve->mControllPoint.push_back(value);
		}

		// load knot count
		reader->Read(&curve->mKnotCount, sizeof(int));

		// load knot values
		for (int i = 0; i < curve->mKnotCount; i++)
		{
			double value;
			reader->Read(&value, sizeof(double));
			curve->mKnotValue.push_back(value);
		}

		// load order
		reader->Read(&curve->mOrder, sizeof(int));

		// load step
		reader->Read(&curve->mStep, sizeof(int));

		// load type
		reader->Read(&curve->mType, sizeof(int));

		// load dimension
		reader->Read(&curve->mDimension, sizeof(int));

		// calc curve length
		curve->mLength = 0;

		for (int i = 1; i < curve->mControllPointCount; i++)
		{
			dVector4 p0 = curve->mControllPoint[i - 1];
			dVector4 p1 = curve->mControllPoint[i];

			float len = Vector3D::Length(Vector3D((float)p1.X, (float)p1.Y, (float)p1.Z) - Vector3D((float)p0.X, (float)p0.Y, (float)p0.Z));
			curve->mLength += len;
		}

		return curve;
	}

	/**
		@brief
		\~English	dispose a curve
		\~Japanese	カーブを破棄する。
		@param	data
		\~English	a pointer of loaded a curve
		\~Japanese	読み込まれたカーブのポインタ
	*/
	virtual void Unload(CurveRef data)
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
#endif // __EFFEKSEER_MODELLOADER_H__
