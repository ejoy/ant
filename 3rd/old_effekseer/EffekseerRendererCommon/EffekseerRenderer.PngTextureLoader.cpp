
#include "EffekseerRenderer.PngTextureLoader.h"
#include <chrono>

#ifdef __EFFEKSEER_USE_LIBPNG__
#include <png.h>
#else
#define STB_IMAGE_EFFEKSEER_IMPLEMENTATION
#include "../3rdParty/stb_effekseer/stb_image_effekseer.h"

#endif

namespace EffekseerRenderer
{
#ifdef __EFFEKSEER_USE_LIBPNG__
static void PngReadData(png_structp png_ptr, png_bytep data, png_size_t length)
{
	uint8_t** d = (uint8_t**)png_get_io_ptr(png_ptr);
	memcpy(data, *d, length);
	(*d) += length;
}
#endif

bool PngTextureLoader::Load(const void* data, int32_t size, bool rev)
{
#ifdef __EFFEKSEER_USE_LIBPNG__
	textureWidth = 0;
	textureHeight = 0;
	textureData.clear();

	uint8_t* data_ = (uint8_t*)data;

	png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);

	png_set_read_fn(png, &data_, &PngReadData);

	png_infop png_info = png_create_info_struct(png);

	if (setjmp(png_jmpbuf(png)))
	{
		png_destroy_read_struct(&png, &png_info, nullptr);
		return false;
	}

	png_read_info(png, png_info);

	const auto interlaceType = png_get_interlace_type(png, png_info);

	int passes = 1;
	if (interlaceType != PNG_INTERLACE_NONE)
		passes = png_set_interlace_handling(png);

	const png_byte bit_depth = png_get_bit_depth(png, png_info);
	if (bit_depth < 8)
	{
		png_set_packing(png);
	}
	else if (bit_depth == 16)
	{
		png_set_strip_16(png);
	}

	uint32_t pixelBytes = 4;
	const png_byte color_type = png_get_color_type(png, png_info);
	switch (color_type)
	{
	case PNG_COLOR_TYPE_PALETTE:
	{
		png_set_palette_to_rgb(png);

		png_bytep trans_alpha = nullptr;
		int num_trans = 0;
		png_color_16p trans_color = nullptr;

		png_get_tRNS(png, png_info, &trans_alpha, &num_trans, &trans_color);
		if (trans_alpha != nullptr)
		{
			pixelBytes = 4;
		}
		else
		{
			pixelBytes = 3;
		}
	}
	break;
	case PNG_COLOR_TYPE_GRAY:
		pixelBytes = 1;
		break;
	case PNG_COLOR_TYPE_GRAY_ALPHA:
		png_set_gray_to_rgb(png);
		pixelBytes = 4;
		break;
	case PNG_COLOR_TYPE_RGB:
		pixelBytes = 3;
		break;
	case PNG_COLOR_TYPE_RGBA:
		break;
	}

	textureWidth = png_get_image_width(png, png_info);
	textureHeight = png_get_image_height(png, png_info);

	uint8_t* image = new uint8_t[textureWidth * textureHeight * pixelBytes];
	uint32_t pitch = textureWidth * pixelBytes;

	for (int pass = 0; pass < passes; pass++)
	{
		if (rev)
		{
			for (int32_t i = 0; i < textureHeight; i++)
			{
				png_read_row(png, &image[(textureHeight - 1 - i) * pitch], nullptr);
			}
		}
		else
		{
			for (int32_t i = 0; i < textureHeight; i++)
			{
				png_read_row(png, &image[i * pitch], nullptr);
			}
		}
	}

	textureData.resize(textureWidth * textureHeight * 4);
	auto imagedst_ = textureData.data();

	if (pixelBytes == 4)
	{
		memcpy(imagedst_, image, textureWidth * textureHeight * 4);
	}
	else if (pixelBytes == 1)
	{
		for (int32_t y = 0; y < textureHeight; y++)
		{
			for (int32_t x = 0; x < textureWidth; x++)
			{
				auto src = (x + y * textureWidth) * 1;
				auto dst = (x + y * textureWidth) * 4;
				imagedst_[dst + 0] = image[src + 0];
				imagedst_[dst + 1] = image[src + 0];
				imagedst_[dst + 2] = image[src + 0];
				imagedst_[dst + 3] = 255;
			}
		}
	}
	else
	{
		for (int32_t y = 0; y < textureHeight; y++)
		{
			for (int32_t x = 0; x < textureWidth; x++)
			{
				auto src = (x + y * textureWidth) * 3;
				auto dst = (x + y * textureWidth) * 4;
				imagedst_[dst + 0] = image[src + 0];
				imagedst_[dst + 1] = image[src + 1];
				imagedst_[dst + 2] = image[src + 2];
				imagedst_[dst + 3] = 255;
			}
		}
	}

	delete[] image;
	png_destroy_read_struct(&png, &png_info, nullptr);

	return true;

#else

	unsigned char* pixels = nullptr;
	int width = 0;
	int height = 0;
	int bpp = 0;

	auto pre = std::chrono::high_resolution_clock::now();

	pixels = (uint8_t*)Effekseer::stbi_load_from_memory((Effekseer::stbi_uc const*)data, size, &width, &height, &bpp, 0);

	if (width > 0)
	{
		textureData.resize(width * height * 4);
		textureWidth = width;
		textureHeight = height;
		auto buf = textureData.data();

		if (bpp == 4)
		{
			memcpy(textureData.data(), pixels, width * height * 4);
		}
		else if (bpp == 2)
		{
			// Gray+Alpha
			for (int h = 0; h < height; h++)
			{
				for (int w = 0; w < width; w++)
				{
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = pixels[(w + h * width) * 2 + 1];
				}
			}
		}
		else if (bpp == 1)
		{
			// Gray
			for (int h = 0; h < height; h++)
			{
				for (int w = 0; w < width; w++)
				{
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = 255;
				}
			}
		}
		else
		{
			for (int h = 0; h < height; h++)
			{
				for (int w = 0; w < width; w++)
				{
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 3 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 3 + 1];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 3 + 2];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = 255;
				}
			}
		}

		Effekseer::stbi_image_free(pixels);
		return true;
	}

	Effekseer::stbi_image_free(pixels);
	return false;
#endif
}

void PngTextureLoader::Unload()
{
	textureData.clear();
}

} // namespace EffekseerRenderer
