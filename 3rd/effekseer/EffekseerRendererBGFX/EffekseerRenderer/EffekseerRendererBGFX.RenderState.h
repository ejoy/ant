#pragma once
#include "../../EffekseerRendererCommon/EffekseerRenderer.RenderStateBase.h"
#include "EffekseerRendererBGFX.Base.h"
#include "EffekseerRendererBGFX.Renderer.h"

namespace EffekseerRendererBGFX
{
class RenderState : public ::EffekseerRenderer::RenderStateBase
{
private:
	RendererImplemented* m_renderer;
	bool m_isCCW = true;

	//std::array<GLuint, Effekseer::TextureSlotMax> m_samplers;

public:
	RenderState(RendererImplemented* renderer);
	virtual ~RenderState();

	void Update(bool forced);
};
} // namespace EffekseerRendererBGFX
