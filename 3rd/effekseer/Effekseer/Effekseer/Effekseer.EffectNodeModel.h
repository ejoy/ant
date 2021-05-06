
#ifndef __EFFEKSEER_ParameterNODE_MODEL_H__
#define __EFFEKSEER_ParameterNODE_MODEL_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.EffectNode.h"
#include "Renderer/Effekseer.ModelRenderer.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

class EffectNodeModel : public EffectNodeImplemented
{
	friend class Manager;
	friend class Effect;
	friend class Instance;

public:
	struct InstanceValues
	{
		// 色
		Color _color;
		Color _original;

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
	};

public:
	AlphaBlendType AlphaBlend;
	int32_t ModelIndex;

	//! this value is not used
	int32_t NormalTextureIndex;

	BillboardType Billboard;

	//! this value is not used
	bool Lighting;
	CullingType Culling;

	StandardColorParameter AllColor;

	ModelReferenceType Mode = ModelReferenceType::File;

	EffectNodeModel(Effect* effect, unsigned char*& pos)
		: EffectNodeImplemented(effect, pos)
	{
	}

	~EffectNodeModel()
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
		return EFFECT_NODE_TYPE_MODEL;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_ParameterNODE_MODEL_H__
