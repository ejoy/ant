#include "Effekseer.EfkEfcFactory.h"
#include "../Utils/Effekseer.BinaryReader.h"

namespace Effekseer
{

bool EfkEfcFactory::OnLoading(Effect* effect, const void* data, int32_t size, float magnification, const char16_t* materialPath)
{
	BinaryReader<true> binaryReader(const_cast<uint8_t*>(reinterpret_cast<const uint8_t*>(data)), size);

	// EFKP
	int head = 0;
	binaryReader.Read(head);
	if (memcmp(&head, "EFKE", 4) != 0)
		return false;

	int32_t version = 0;

	binaryReader.Read(version);

	// load chunk
	while (binaryReader.GetOffset() < size)
	{
		int chunk = 0;
		binaryReader.Read(chunk);
		int chunkSize = 0;
		binaryReader.Read(chunkSize);

		if (memcmp(&chunk, "INFO", 4) == 0)
		{
		}

		if (memcmp(&chunk, "EDIT", 4) == 0)
		{
		}

		if (memcmp(&chunk, "BIN_", 4) == 0)
		{
			if (LoadBody(effect, reinterpret_cast<const uint8_t*>(data) + binaryReader.GetOffset(), chunkSize, magnification, materialPath))
			{
				return true;
			}
		}

		binaryReader.AddOffset(chunkSize);
	}

	return false;
}

bool EfkEfcFactory::OnCheckIsBinarySupported(const void* data, int32_t size)
{
	BinaryReader<true> binaryReader(const_cast<uint8_t*>(reinterpret_cast<const uint8_t*>(data)), size);

	// EFKP
	int head = 0;
	binaryReader.Read(head);
	if (memcmp(&head, "EFKE", 4) != 0)
		return false;

	return true;
}

bool EfkEfcProperty::Load(const void* data, int32_t size)
{
	BinaryReader<true> binaryReader(const_cast<uint8_t*>(reinterpret_cast<const uint8_t*>(data)), size);

	// EFKP
	int head = 0;
	binaryReader.Read(head);
	if (memcmp(&head, "EFKE", 4) != 0)
		return false;

	int32_t version = 0;

	binaryReader.Read(version);

	// load chunk
	while (binaryReader.GetOffset() < size)
	{
		int chunk = 0;
		binaryReader.Read(chunk);
		int chunkSize = 0;
		binaryReader.Read(chunkSize);

		if (memcmp(&chunk, "INFO", 4) == 0)
		{
			int32_t infoVersion = 0;

			auto loadStr = [this, &binaryReader, &infoVersion](std::vector<std::u16string>& dst) {
				int32_t dataCount = 0;
				binaryReader.Read(dataCount);

				// compatibility
				if (dataCount >= 1500)
				{
					infoVersion = dataCount;
					binaryReader.Read(dataCount);
				}

				dst.resize(dataCount);

				std::vector<char16_t> strBuf;

				for (int i = 0; i < dataCount; i++)
				{
					int length = 0;
					binaryReader.Read(length);
					strBuf.resize(length);
					binaryReader.Read(strBuf.data(), length);
					dst.at(i) = strBuf.data();
				}
			};

			loadStr(colorImages_);
			loadStr(normalImages_);
			loadStr(distortionImages_);
			loadStr(models_);
			loadStr(sounds_);

			if (infoVersion >= 1500)
			{
				loadStr(materials_);
			}
		}

		binaryReader.AddOffset(chunkSize);
	}

	return false;
}

const std::vector<std::u16string>& EfkEfcProperty::GetColorImages() const
{
	return colorImages_;
}
const std::vector<std::u16string>& EfkEfcProperty::GetNormalImages() const
{
	return normalImages_;
}
const std::vector<std::u16string>& EfkEfcProperty::GetDistortionImages() const
{
	return distortionImages_;
}
const std::vector<std::u16string>& EfkEfcProperty::GetSounds() const
{
	return sounds_;
}
const std::vector<std::u16string>& EfkEfcProperty::GetModels() const
{
	return models_;
}
const std::vector<std::u16string>& EfkEfcProperty::GetMaterials() const
{
	return materials_;
}

} // namespace Effekseer