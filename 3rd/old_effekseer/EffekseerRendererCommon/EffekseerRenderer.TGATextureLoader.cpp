
#include "EffekseerRenderer.TGATextureLoader.h"

namespace EffekseerRenderer
{

bool TGATextureLoader::Load(const void* data, int32_t size)
{
	uint8_t* data_texture = (uint8_t*)data;

	const int TGA_HEADER_SIZE = 18;
	uint8_t TgaHeader[TGA_HEADER_SIZE];

	// tga ヘッダー読み込み
	for (int i = 0; i < TGA_HEADER_SIZE; i++)
	{
		TgaHeader[i] = data_texture[i];
	}

	textureWidth = TgaHeader[12] + TgaHeader[13] * 256;
	textureHeight = TgaHeader[14] + TgaHeader[15] * 256;

	int ColorStep{};

	if (TgaHeader[16] == 16)
	{
		ColorStep = 2;
	}
	else if (TgaHeader[16] == 24)
	{
		ColorStep = 3;
	}
	else if (TgaHeader[16] == 32)
	{
		ColorStep = 4;
	}
	else
	{
		return false;
	}

	// カラーマップ取得
	int MapSize = textureWidth * textureHeight * 4;
	textureData.resize(MapSize);

	uint8_t* SrcTextureRef = &data_texture[TGA_HEADER_SIZE];

	for (int h = 0; h < textureHeight; h++)
	{
		for (int w = 0; w < textureWidth; w++)
		{
			// 出力データ走査用(左上~)
			int LU_Index = (h * textureWidth + w) * 4;

			// 元データ走査用(左下~)
			int LD_Index = (((textureHeight - 1 - h) * textureWidth) + w) * ColorStep;

			for (int c = 0; c < ColorStep; c++)
			{
				textureData[LU_Index + c] = SrcTextureRef[LD_Index + c];
			}

			if (ColorStep == 2)
			{
				textureData[LU_Index + 3] = textureData[LU_Index + 1];
				textureData[LU_Index + 1] = textureData[LU_Index + 0];
				textureData[LU_Index + 2] = textureData[LU_Index + 0];
			}

			if (ColorStep == 3)
			{
				textureData[LU_Index + 3] = 255;
			}
		}
	}

	// BGR -> RGBへ変換
	for (int h = 0; h < textureHeight; h++)
	{
		for (int w = 0; w < textureWidth; w++)
		{
			int index = (h * textureWidth + w) * 4;

			uint8_t tmp = textureData[index + 0];
			textureData[index + 0] = textureData[index + 2];
			textureData[index + 2] = tmp;
		}
	}

	return true;
}

void TGATextureLoader::Unload()
{
	textureData.clear();
}

void TGATextureLoader::Initialize()
{
}

void TGATextureLoader::Finalize()
{
}

} // namespace EffekseerRenderer
