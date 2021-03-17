
#ifndef __EFFEKSEERRENDERER_RENDERSTATE_BASE_H__
#define __EFFEKSEERRENDERER_RENDERSTATE_BASE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <Effekseer.h>
#include <assert.h>
#include <stack>
#include <string.h>

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
namespace EffekseerRenderer
{
//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
class RenderStateBase
{
public:
	struct State
	{
		bool DepthTest : 1;
		bool DepthWrite : 1;
		::Effekseer::AlphaBlendType AlphaBlend;
		::Effekseer::CullingType CullingType;
		std::array<::Effekseer::TextureFilterType, Effekseer::TextureSlotMax> TextureFilterTypes;
		std::array<::Effekseer::TextureWrapType, Effekseer::TextureSlotMax> TextureWrapTypes;

		//! for OpenGL
		std::array<uint64_t, Effekseer::TextureSlotMax> TextureIDs;

		State();

		void Reset();

		void CopyTo(State& state);
	};

protected:
	std::stack<State> m_stateStack;
	State m_active;
	State m_next;

public:
	RenderStateBase();
	virtual ~RenderStateBase();

	virtual void Update(bool forced) = 0;

	State& Push();
	void Pop();
	State& GetActiveState();
};

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_RENDERSTATE_BASE_H__