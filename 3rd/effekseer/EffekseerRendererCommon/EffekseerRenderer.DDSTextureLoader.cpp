#include "EffekseerRenderer.DDSTextureLoader.h"
#include <stdint.h>

namespace EffekseerRenderer
{

enum class DdsDx10Format : uint32_t
{
	R8G8B8A8_UNORM = 28,
	R8G8B8A8_UNORM_SRGB = 29,
	BC1_UNORM = 71,
	BC1_UNORM_SRGB = 72,
	BC2_UNORM = 74,
	BC2_UNORM_SRGB = 75,
	BC3_UNORM = 77,
	BC3_UNORM_SRGB = 78,
	BC4_UNORM = 80,
	BC4_SNORM = 81,
	BC5_UNORM = 83,
	BC5_SNORM = 84,
};

constexpr uint32_t MakeFourCC(const char v1, const char v2, const char v3, const char v4)
{
	return ((static_cast<uint32_t>(v1)) | (static_cast<uint32_t>(v2) << 8) | (static_cast<uint32_t>(v3) << 16) | (static_cast<uint32_t>(v4) << 24));
}

bool DDSTextureLoader::Load(const void* data, int32_t size)
{
	textures_.clear();

	struct DDS_PIXELFORMAT
	{
		uint32_t dwSize;
		uint32_t dwFlags;
		uint32_t dwFourCC;
		uint32_t dwRGBBitCount;
		uint32_t dwRBitMask;
		uint32_t dwGBitMask;
		uint32_t dwBBitMask;
		uint32_t dwABitMask;
	};

	struct DDS_HEADER
	{
		uint32_t dwSize;
		uint32_t dwFlags;
		uint32_t dwHeight;
		uint32_t dwWidth;
		uint32_t dwPitchOrLinearSize;
		uint32_t dwDepth;
		uint32_t dwMipMapCount;
		uint32_t dwReserved1[11];
		DDS_PIXELFORMAT ddspf;
		uint32_t dwCaps1;
		uint32_t dwCaps2;
		uint32_t dwReserved2[3];
	};

	struct DDS_HEADER_DXT10
	{
		DdsDx10Format dxgiFormat;
		uint32_t resourceDimension;
		uint32_t miscFlag;
		uint32_t arraySize;
		uint32_t miscFlags2;
	};

	auto p = (uint8_t*)data;
	//const uint32_t FOURCC_DXT1 = 0x31545844; //(MAKEFOURCC('D','X','T','1'))
	//const uint32_t FOURCC_DXT3 = 0x33545844; //(MAKEFOURCC('D','X','T','3'))
	//const uint32_t FOURCC_DXT5 = 0x35545844; //(MAKEFOURCC('D','X','T','5'))

	const uint32_t FOURCC_DXT1 = MakeFourCC('D', 'X', 'T', '1');
	const uint32_t FOURCC_DXT3 = MakeFourCC('D', 'X', 'T', '3');
	const uint32_t FOURCC_DXT5 = MakeFourCC('D', 'X', 'T', '5');
	assert(FOURCC_DXT1 == 0x31545844);
	assert(FOURCC_DXT3 == 0x33545844);
	assert(FOURCC_DXT5 == 0x35545844);

	if (size < 4 + sizeof(DDS_HEADER))
		return false;

	if (p[0] == 'D' && p[1] == 'D' && p[2] == 'S' && p[3] == ' ')
	{
		p += 4;
	}
	else
	{
		return false;
	}

	DDS_HEADER dds;
	memcpy(&dds, p, sizeof(DDS_HEADER));
	p += sizeof(DDS_HEADER);

	DDS_HEADER_DXT10 dds_dxt10;

	bool hasDX10Flag = false;
	if (dds.ddspf.dwFourCC == MakeFourCC('D', 'X', '1', '0'))
	{
		hasDX10Flag = true;
		memcpy(&dds_dxt10, p, sizeof(DDS_HEADER_DXT10));
		p += sizeof(DDS_HEADER_DXT10);
	}

	const auto detectFormat = [&]() -> Effekseer::Backend::TextureFormatType {
		if (hasDX10Flag)
		{
			if (dds_dxt10.dxgiFormat == DdsDx10Format::R8G8B8A8_UNORM)
			{
				return Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::R8G8B8A8_UNORM_SRGB)
			{
				return Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM_SRGB;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC1_UNORM)
			{
				return Effekseer::Backend::TextureFormatType::BC1;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC1_UNORM_SRGB)
			{
				return Effekseer::Backend::TextureFormatType::BC1_SRGB;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC2_UNORM)
			{
				return Effekseer::Backend::TextureFormatType::BC2;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC2_UNORM_SRGB)
			{
				return Effekseer::Backend::TextureFormatType::BC2_SRGB;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC3_UNORM)
			{
				return Effekseer::Backend::TextureFormatType::BC3;
			}
			else if (dds_dxt10.dxgiFormat == DdsDx10Format::BC3_UNORM_SRGB)
			{
				return Effekseer::Backend::TextureFormatType::BC3_SRGB;
			}
			else
			{
				return Effekseer::Backend::TextureFormatType::Unknown;
			}
		}
		else
		{
			if (dds.ddspf.dwRGBBitCount == 32 && dds.ddspf.dwRBitMask == 0x000000FF && dds.ddspf.dwGBitMask == 0x0000FF00 &&
				dds.ddspf.dwBBitMask == 0x00FF0000 && dds.ddspf.dwABitMask == 0xFF000000)
			{
				return Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM;
			}
			if (dds.ddspf.dwFourCC == FOURCC_DXT1)
			{
				return Effekseer::Backend::TextureFormatType::BC1;
			}
			else if (dds.ddspf.dwFourCC == FOURCC_DXT3)
			{
				return Effekseer::Backend::TextureFormatType::BC2;
			}
			else if (dds.ddspf.dwFourCC == FOURCC_DXT5)
			{
				return Effekseer::Backend::TextureFormatType::BC3;
			}
			else
			{
				return Effekseer::Backend::TextureFormatType::Unknown;
			}
		}
	};

	auto format = detectFormat();
	int32_t blockSize = 0;
	bool isCompressed = false;

	if (format == Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM ||
		format == Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM_SRGB ||
		format == Effekseer::Backend::TextureFormatType::Unknown)
	{
		textureFormatType = Effekseer::TextureFormatType::ABGR8;
		blockSize = 4;
		isCompressed = false;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC1 ||
			 format == Effekseer::Backend::TextureFormatType::BC1_SRGB)
	{
		textureFormatType = Effekseer::TextureFormatType::BC1;
		blockSize = 8;
		isCompressed = true;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC2 ||
			 format == Effekseer::Backend::TextureFormatType::BC2_SRGB)
	{
		textureFormatType = Effekseer::TextureFormatType::BC2;
		blockSize = 16;
		isCompressed = true;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC3 ||
			 format == Effekseer::Backend::TextureFormatType::BC3_SRGB)
	{
		textureFormatType = Effekseer::TextureFormatType::BC3;
		blockSize = 16;
		isCompressed = true;
	}
	else
	{
		return false;
	}

	backendTextureFormatType = (format == Effekseer::Backend::TextureFormatType::Unknown) ? Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM : format;
	textures_.reserve(dds.dwMipMapCount);

	int32_t width = static_cast<int32_t>(dds.dwWidth);
	int32_t height = static_cast<int32_t>(dds.dwHeight);

	for (size_t i = 0; i < dds.dwMipMapCount; i++)
	{
		int32_t textureSize{};

		if (isCompressed)
		{
			textureSize = ((width + 3) / 4) * ((height + 3) / 4) * blockSize;
		}
		else
		{
			textureSize = width * height * blockSize;
		}

		::Effekseer::CustomVector<uint8_t> textureData;
		textureData.resize(textureSize);
		
		if (format == Effekseer::Backend::TextureFormatType::Unknown)
		{
			// for rgb format
			for (int32_t y = 0; y < height; y++)
			{
				for (int32_t x = 0; x < width; x++)
				{
					auto src = (x + y * width) * 3;
					auto dst = (x + y * width) * 4;
					textureData[dst + 0] = p[src + 0];
					textureData[dst + 1] = p[src + 1];
					textureData[dst + 2] = p[src + 2];
					textureData[dst + 3] = 255;
				}
			}
		}
		else
		{
			memcpy(textureData.data(), p, textureData.size());
		}
		textures_.emplace_back(Texture{width, height, std::move(textureData)});

		if (width > 1)
			width = (width >> 1);
		else
			width = 1;

		if (height > 1)
			height = (height >> 1);
		else
			height = 1;

		p += textureSize;
	}

	textureWidth = static_cast<int32_t>(dds.dwWidth);
	textureHeight = static_cast<int32_t>(dds.dwHeight);

	return true;
}

void DDSTextureLoader::Unload()
{
	textures_.clear();
}

} // namespace EffekseerRenderer