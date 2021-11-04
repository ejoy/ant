#include "EffekseerRendererBGFX.RenderState.h"

#include "EffekseerRendererBGFX.Renderer.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

namespace EffekseerRendererBGFX {

RenderState::RenderState(RendererImplemented* renderer)
	: m_renderer(renderer)
{
	//if (m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGL3 || m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGLES3)
	//{
	//	GLExt::glGenSamplers(Effekseer::TextureSlotMax, m_samplers.data());
	//}

	//GLint frontFace = 0;
	//glGetIntegerv(GL_FRONT_FACE, &frontFace);

	//if (GL_CW == frontFace)
	//{
	//	m_isCCW = false;
	//}
}

RenderState::~RenderState()
{
	//if (m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGL3 || m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGLES3)
	//{
	//	GLExt::glDeleteSamplers(Effekseer::TextureSlotMax, m_samplers.data());
	//}
}

void RenderState::Update(bool forced)
{
	forced = true;
	uint64_t state = 0
		| BGFX_STATE_WRITE_RGB
		| BGFX_STATE_WRITE_A
		| BGFX_STATE_FRONT_CCW
		| BGFX_STATE_MSAA;

	if (m_active.DepthTest != m_next.DepthTest || forced)
	{
		if (m_next.DepthTest)
		{
			state |= BGFX_STATE_DEPTH_TEST_LEQUAL;
		}
		else
		{
			state |= BGFX_STATE_DEPTH_TEST_ALWAYS;
		}
	}

	if (m_active.DepthWrite != m_next.DepthWrite || forced)
	{
		if (m_next.DepthWrite)
		{
			state |= BGFX_STATE_WRITE_Z;
		}
	}

	if (m_active.CullingType != m_next.CullingType || forced)
	{
		if (m_isCCW)
		{
			if (m_next.CullingType == Effekseer::CullingType::Front)
			{
				state |= BGFX_STATE_CULL_CW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Back)
			{
				state |= BGFX_STATE_CULL_CCW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Double)
			{
				//state |= BGFX_STATE_CULL_CW;
			}
		}
		else
		{
			if (m_next.CullingType == Effekseer::CullingType::Front)
			{
				state |= BGFX_STATE_CULL_CCW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Back)
			{
				state |= BGFX_STATE_CULL_CW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Double)
			{
				//state |= BGFX_STATE_CULL_CCW;
			}
		}
	}
	if (m_active.AlphaBlend != m_next.AlphaBlend || forced)
	{
		{
			if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Opacity ||
				m_renderer->GetRenderMode() == ::Effekseer::RenderMode::Wireframe)
			{
				//GLExt::glBlendEquationSeparate(GL_FUNC_ADD, GL_MAX);
				//GLExt::glBlendFuncSeparate(GL_ONE, GL_ZERO, GL_ONE, GL_ONE);
				state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_ADD, BGFX_STATE_BLEND_EQUATION_MAX);
				state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE);
			}
			else if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Sub)
			{
				//GLExt::glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
				//GLExt::glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE, GL_ZERO, GL_ONE);
				state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_REVSUB, BGFX_STATE_BLEND_EQUATION_ADD);
				state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_ONE);
			}
			else
			{
				//GLExt::glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
				if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Blend)
				{
					//GLExt::glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
					state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_ADD, BGFX_STATE_BLEND_EQUATION_MAX);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE);
				}
				else if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Add)
				{
					//GLExt::glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE, GL_ONE, GL_ONE);
					state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_ADD, BGFX_STATE_BLEND_EQUATION_MAX);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE);
				}
				else if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Mul)
				{
					//GLExt::glBlendFuncSeparate(GL_ZERO, GL_SRC_COLOR, GL_ZERO, GL_ONE);
					state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_ADD, BGFX_STATE_BLEND_EQUATION_ADD);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_SRC_COLOR, BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_ONE);
				}
			}
		}
	}
	m_renderer->SetCurrentState(state);
	//BGFX(set_state)(state, 0);
	m_active = m_next;
}

} // namespace EffekseerRendererBGFX
