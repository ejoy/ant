
#ifndef __EFFEKSEER_ParameterNODE_TRACK_H__
#define __EFFEKSEER_ParameterNODE_TRACK_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.EffectNode.h"
#include "Renderer/Effekseer.TrackRenderer.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct TrackSizeParameter
{
	enum
	{
		Fixed = 0,

		Parameter_DWORD = 0x7fffffff,
	} type;

	union
	{
		struct
		{
			float size;
		} fixed;
	};
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class EffectNodeTrack : public EffectNodeImplemented
{
public:
	struct InstanceGroupValues
	{
		struct Color
		{
			union
			{
				struct
				{
					Effekseer::Color color_;
				} fixed;

				struct
				{
					Effekseer::Color color_;
				} random;

				struct
				{
					Effekseer::Color start;
					Effekseer::Color end;
				} easing;

				struct
				{
					std::array<float, 4> offset;
				} fcurve_rgba;

			} color;
		};

		struct Size
		{
			union
			{
				struct
				{
					float size_;
				} fixed;
			} size;
		};

		Color ColorLeft;
		Color ColorCenter;
		Color ColorRight;

		Color ColorLeftMiddle;
		Color ColorCenterMiddle;
		Color ColorRightMiddle;

		Size SizeFor;
		Size SizeMiddle;
		Size SizeBack;
	};

	struct InstanceValues
	{
		Color colorLeft;
		Color colorCenter;
		Color colorRight;

		Color colorLeftMiddle;
		Color colorCenterMiddle;
		Color colorRightMiddle;

		Color _colorLeft;
		Color _colorCenter;
		Color _colorRight;

		Color _colorLeftMiddle;
		Color _colorCenterMiddle;
		Color _colorRightMiddle;

		float SizeFor;
		float SizeMiddle;
		float SizeBack;
	};

	TrackRenderer::NodeParameter m_nodeParameter;
	TrackRenderer::InstanceParameter m_instanceParameter;

	InstanceGroupValues m_currentGroupValues;

public:
	AlphaBlendType AlphaBlend;

	StandardColorParameter TrackColorLeft;
	StandardColorParameter TrackColorCenter;
	StandardColorParameter TrackColorRight;

	StandardColorParameter TrackColorLeftMiddle;
	StandardColorParameter TrackColorCenterMiddle;
	StandardColorParameter TrackColorRightMiddle;

	TrackSizeParameter TrackSizeFor;
	TrackSizeParameter TrackSizeMiddle;
	TrackSizeParameter TrackSizeBack;

	int TrackTexture;

	int32_t SplineDivision = 1;

	NodeRendererTextureUVTypeParameter TextureUVType;

	EffectNodeTrack(Effect* effect, unsigned char*& pos)
		: EffectNodeImplemented(effect, pos)
		, TrackTexture(-1)
	{
	}

	~EffectNodeTrack()
	{
	}

	void LoadRendererParameter(unsigned char*& pos, const SettingRef& setting) override;

	void BeginRendering(int32_t count, Manager* manager, void* userData) override;

	void BeginRenderingGroup(InstanceGroup* group, Manager* manager, void* userData) override;

	void EndRenderingGroup(InstanceGroup* group, Manager* manager, void* userData) override;

	void Rendering(const Instance& instance, const Instance* next_instance, Manager* manager, void* userData) override;

	void EndRendering(Manager* manager, void* userData) override;

	void InitializeRenderedInstanceGroup(InstanceGroup& instanceGroup, Manager* manager) override;

	void InitializeRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager) override;

	void UpdateRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager) override;

	eEffectNodeType GetType() const override
	{
		return EFFECT_NODE_TYPE_TRACK;
	}

	void InitializeValues(InstanceGroupValues::Color& value, StandardColorParameter& param, IRandObject* rand);
	void InitializeValues(InstanceGroupValues::Size& value, TrackSizeParameter& param, Manager* manager);
	void SetValues(Color& c,
				   const Instance& instance,
				   InstanceGroupValues::Color& value,
				   StandardColorParameter& param,
				   int32_t time,
				   int32_t livedTime);
	void SetValues(float& s, InstanceGroupValues::Size& value, TrackSizeParameter& param, float time);
	void LoadValues(TrackSizeParameter& param, unsigned char*& pos);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_ParameterNODE_TRACK_H__
