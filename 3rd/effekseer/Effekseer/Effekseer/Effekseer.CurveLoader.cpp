#include "Effekseer.CurveLoader.h"
#include "Utils/Effekseer.BinaryReader.h"

namespace Effekseer
{

CurveLoader::CurveLoader(::Effekseer::FileInterface* fileInterface)
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

CurveRef CurveLoader::Load(const char16_t* path)
{
	std::unique_ptr<::Effekseer::FileReader> reader(fileInterface_->OpenRead(path));
	if (reader.get() == nullptr)
	{
		return nullptr;
	}

	size_t size = reader->GetLength();
	std::vector<uint8_t> data;
	data.resize(size);

	reader->Read(data.data(), size);

	return Load(data.data(), size);
}

CurveRef CurveLoader::Load(const void* data, int32_t size)
{
	BinaryReader<false> reader((uint8_t*)(data), size);

	auto curve = Effekseer::MakeRefPtr<Effekseer::Curve>();

	// load converter version
	int converter_version = 0;
	reader.Read(converter_version);

	// load controll point count
	reader.Read(curve->mControllPointCount);

	// load controll points
	for (int i = 0; i < curve->mControllPointCount; i++)
	{
		dVector4 value;
		reader.Read(value);
		curve->mControllPoint.push_back(value);
	}

	// load knot count
	reader.Read(curve->mKnotCount);

	// load knot values
	for (int i = 0; i < curve->mKnotCount; i++)
	{
		double value;
		reader.Read(value);
		curve->mKnotValue.push_back(value);
	}

	// load order
	reader.Read(curve->mOrder);

	// load step
	reader.Read(curve->mStep);

	// load type
	reader.Read(curve->mType);

	// load dimension
	reader.Read(curve->mDimension);

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

void CurveLoader::Unload(CurveRef data)
{
}

} // namespace Effekseer