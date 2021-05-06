
#ifndef __EFFEKSEER_ParameterNODE_SPRITE_H__
#define __EFFEKSEER_ParameterNODE_SPRITE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.EffectNode.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
struct SpriteColorParameter
{
	enum
	{
		Default = 0,
		Fixed = 1,

		Parameter_DWORD = 0x7fffffff,
	} type;

	union
	{
		struct
		{

		} def;

		struct
		{
			Color ll;
			Color lr;
			Color ul;
			Color ur;
		} fixed;
	};
};

struct SpritePositionParameter
{
	enum
	{
		Default = 0,
		Fixed = 1,

		Parameter_DWORD = 0x7fffffff,
	} type;

	union
	{
		struct
		{

		} def;

		struct
		{
			SIMD::Vec2f ll;
			SIMD::Vec2f lr;
			SIMD::Vec2f ul;
			SIMD::Vec2f ur;
		} fixed;
	};
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class EffectNodeSprite : public EffectNodeImplemented
{
	friend class Manager;
	friend class Effect;
	friend class Instance;

public:
	struct InstanceValues
	{
		// 色
		Color _color;

		Color _originalColor;

		union
		{
			struct
			{
				Color _color;
			} fixed;

			struct
			{
				Color _color;
			} random;

			struct
			{
				Color start;
				Color end;

			} easing;

			struct
			{
				std::array<float, 4> offset;
			} fcurve_rgba;

		} allColorValues;

		union
		{

		} colorValues;

		union
		{

		} positionValues;
	};

public:
	AlphaBlendType AlphaBlend;
	BillboardType Billboard;

	StandardColorParameter SpriteAllColor;

	SpriteColorParameter SpriteColor;
	SpritePositionParameter SpritePosition;

	int SpriteTexture;

	EffectNodeSprite(Effect* effect, unsigned char*& pos)
		: EffectNodeImplemented(effect, pos)
	{
	}

	void LoadRendererParameter(unsigned char*& pos, const SettingRef& setting) override;

	void BeginRendering(int32_t count, Manager* manager, void* userData) override;

	void Rendering(const Instance& instance, const Instance* next_instance, Manager* manager, void* userData) override;

	void EndRendering(Manager* manager, void* userData) override;

	void InitializeRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager) override;

	void UpdateRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager) override;

	eEffectNodeType GetType() const override
	{
		return EFFECT_NODE_TYPE_SPRITE;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_ParameterNODE_SPRITE_H__
