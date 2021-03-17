
#ifndef __EFFEKSEER_PARAMETERS_H__
#define __EFFEKSEER_PARAMETERS_H__

#include "../Effekseer.Base.Pre.h"
#include "../Effekseer.InternalStruct.h"

namespace Effekseer
{

/**
	@brief
	\~English	How to treat an uv of texture type for ribbon and track
	\~Japanese	リボンと軌跡向けのテクスチャのUVの扱い方
*/
enum class TextureUVType : int32_t
{
	Strech,
	Tile,
};

/**
	@brief	\~english	uv texture parameters which is passed into a renderer
			\~japanese	レンダラーに渡されるUVTextureに関するパラメーター
*/
struct NodeRendererTextureUVTypeParameter
{
	TextureUVType Type = TextureUVType::Strech;
	float TileLength = 0.0f;
	int32_t TileEdgeHead = 0;
	int32_t TileEdgeTail = 0;
	float TileLoopAreaBegin = 0.0f;
	float TileLoopAreaEnd = 0.0f;

	void Load(uint8_t*& pos, int32_t version);
};

struct FalloffParameter
{
	enum BlendType
	{
		Add = 0,
		Sub = 1,
		Mul = 2,
	} ColorBlendType;
	Color BeginColor;
	Color EndColor;
	float Pow;

	FalloffParameter()
	{
		ColorBlendType = BlendType::Add;
		BeginColor = Color(255, 255, 255, 255);
		EndColor = Color(255, 255, 255, 255);
		Pow = 1.0f;
	}
};

} // namespace Effekseer

#endif // __EFFEKSEER_PARAMETERS_H__