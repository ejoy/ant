
#ifndef __EFFEKSEER_COLOR_H__
#define __EFFEKSEER_COLOR_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ColorMode
{
	COLOR_MODE_RGBA,
	COLOR_MODE_HSVA,
	COLOR_MODE_DWORD = 0x7FFFFFFF
};

/**
	@brief	色
*/
#pragma pack(push, 1)
struct Color
{
	/**
		@brief	赤
	*/
	uint8_t R;

	/**
		@brief	緑
	*/
	uint8_t G;

	/**
		@brief	青
	*/
	uint8_t B;

	/**
		@brief	透明度
	*/
	uint8_t A;

	/**
		@brief	コンストラクタ
	*/
	Color() = default;

	/**
		@brief	コンストラクタ
	*/
	Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255);

	/**
		@brief 
		\~English	Convert Color into std::array<float,4>
		\~Japanese	Color から std::array<float,4> に変換する。
	*/
	std::array<float, 4> ToFloat4() const
	{
		std::array<float, 4> fc;
		fc[0] = static_cast<float>(R) / 255.0f;
		fc[1] = static_cast<float>(G) / 255.0f;
		fc[2] = static_cast<float>(B) / 255.0f;
		fc[3] = static_cast<float>(A) / 255.0f;
		return fc;
	}

	/**
		@brief	乗算
	*/
	static Color Mul(Color in1, Color in2);
	static Color Mul(Color in1, float in2);

	/**
		@brief	線形補間
	*/
	static Color Lerp(const Color in1, const Color in2, float t);

	bool operator!=(const Color& o) const
	{
		if (R != o.R)
			return true;

		if (G != o.G)
			return true;

		if (B != o.B)
			return true;

		if (A != o.A)
			return true;

		return false;
	}

	bool operator<(const Color& o) const
	{
		if (R != o.R)
			return R < o.R;

		if (G != o.G)
			return G < o.G;

		if (B != o.B)
			return B < o.B;

		if (A != o.A)
			return A < o.A;

		return false;
	}
};
#pragma pack(pop)
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_COLOR_H__
