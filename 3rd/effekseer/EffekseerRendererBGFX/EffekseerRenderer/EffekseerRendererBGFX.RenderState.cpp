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
		//| BGFX_STATE_CULL_CW
		//| BGFX_STATE_WRITE_Z
		//| BGFX_STATE_DEPTH_TEST_LESS
		| BGFX_STATE_FRONT_CCW
		| BGFX_STATE_MSAA;

	if (m_active.DepthTest != m_next.DepthTest || forced)
	{
		if (m_next.DepthTest)
		{
			state |= BGFX_STATE_DEPTH_TEST_LESS;
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
//				glEnable(GL_CULL_FACE);
//				glCullFace(GL_FRONT);
				state |= BGFX_STATE_CULL_CCW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Back)
			{
//				glEnable(GL_CULL_FACE);
//				glCullFace(GL_BACK);
				state |= BGFX_STATE_CULL_CCW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Double)
			{
//				glDisable(GL_CULL_FACE);
//				glCullFace(GL_FRONT_AND_BACK);
			}
		}
		else
		{
			if (m_next.CullingType == Effekseer::CullingType::Front)
			{
//				glEnable(GL_CULL_FACE);
//				glCullFace(GL_BACK);
				state |= BGFX_STATE_CULL_CW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Back)
			{
//				glEnable(GL_CULL_FACE);
//				glCullFace(GL_FRONT);
				state |= BGFX_STATE_CULL_CW;
			}
			else if (m_next.CullingType == Effekseer::CullingType::Double)
			{
//				glDisable(GL_CULL_FACE);
//				glCullFace(GL_FRONT_AND_BACK);
			}
		}
	}

//	GLCheckError();

	if (m_active.AlphaBlend != m_next.AlphaBlend || forced)
	{
		{
			//glEnable(GL_BLEND);

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
				state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(BGFX_STATE_BLEND_EQUATION_ADD, BGFX_STATE_BLEND_EQUATION_ADD);
				if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Blend)
				{
					//GLExt::glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE);
				}
				else if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Add)
				{
					//GLExt::glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE, GL_ONE, GL_ONE);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE);
				}
				else if (m_next.AlphaBlend == ::Effekseer::AlphaBlendType::Mul)
				{
					//GLExt::glBlendFuncSeparate(GL_ZERO, GL_SRC_COLOR, GL_ZERO, GL_ONE);
					state |= BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_SRC_COLOR, BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_ONE);
				}
			}
		}
	}

	//GLCheckError();

	//static const GLint glfilterMin[] = {GL_NEAREST, GL_LINEAR_MIPMAP_LINEAR};
	//static const GLint glfilterMin_NoneMipmap[] = {GL_NEAREST, GL_LINEAR};
	//static const GLint glfilterMag[] = {GL_NEAREST, GL_LINEAR};
	//static const GLint glwrap[] = {GL_REPEAT, GL_CLAMP_TO_EDGE};

	if (true/*m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGL3 || m_renderer->GetDeviceType() == OpenGLDeviceType::OpenGLES3*/)
	{
		for (int32_t i = 0; i < (int32_t)m_renderer->GetCurrentTextures().size(); i++)
		{
			// If a texture is not assigned, skip it.
			const auto& texture = m_renderer->GetCurrentTextures()[i];
			if (texture == nullptr)
				continue;

			if (m_active.TextureFilterTypes[i] != m_next.TextureFilterTypes[i] || forced || m_active.TextureIDs[i] != m_next.TextureIDs[i])
			{
				//GLExt::glActiveTexture(GL_TEXTURE0 + i);

				// for webngl
#ifndef NDEBUG
				// GLint bound = 0;
				// glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
				// assert(bound > 0);
#endif

				//int32_t filter_ = (int32_t)m_next.TextureFilterTypes[i];
				auto filter_ = m_next.TextureFilterTypes[i];

				//GLExt::glSamplerParameteri(m_samplers[i], GL_TEXTURE_MAG_FILTER, glfilterMag[filter_]);
				if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
					state |= BGFX_SAMPLER_MAG_POINT;
				}
				
				if (texture->GetHasMipmap())
				{
					//GLExt::glSamplerParameteri(m_samplers[i], GL_TEXTURE_MIN_FILTER, glfilterMin[filter_]);
					if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
						state |= BGFX_SAMPLER_MIP_POINT;
					}
				}
				else
				{
					//GLExt::glSamplerParameteri(m_samplers[i], GL_TEXTURE_MIN_FILTER, glfilterMin_NoneMipmap[filter_]);
					if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
						state |= BGFX_SAMPLER_MIN_POINT;
					}
				}

				// glSamplerParameteri( m_samplers[i],  GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
				// glSamplerParameteri( m_samplers[i],  GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);

				//GLExt::glBindSampler(i, m_samplers[i]);
			}

			if (m_active.TextureWrapTypes[i] != m_next.TextureWrapTypes[i] || forced || m_active.TextureIDs[i] != m_next.TextureIDs[i])
			{
				//GLExt::glActiveTexture(GL_TEXTURE0 + i);

				auto wrap_ = m_next.TextureWrapTypes[i];
				if (wrap_ == ::Effekseer::TextureWrapType::Repeat) {
					state |= BGFX_SAMPLER_U_MIRROR | BGFX_SAMPLER_V_MIRROR | BGFX_SAMPLER_W_MIRROR;
				} else {
					state |= BGFX_SAMPLER_U_CLAMP | BGFX_SAMPLER_V_CLAMP | BGFX_SAMPLER_W_CLAMP;
				}
				//GLExt::glSamplerParameteri(m_samplers[i], GL_TEXTURE_WRAP_S, glwrap[wrap_]);
				//GLExt::glSamplerParameteri(m_samplers[i], GL_TEXTURE_WRAP_T, glwrap[wrap_]);

				//GLExt::glBindSampler(i, m_samplers[i]);
			}
		}
	}
	else
	{
//		GLCheckError();
//		for (int32_t i = 0; i < (int32_t)m_renderer->GetCurrentTextures().size(); i++)
//		{
//			// If a texture is not assigned, skip it.
//			const auto& texture = m_renderer->GetCurrentTextures()[i];
//			if (texture == nullptr)
//				continue;
//
//			// always changes because a flag is assigned into a texture
//			// if (m_active.TextureFilterTypes[i] != m_next.TextureFilterTypes[i] || forced)
//			{
//				GLExt::glActiveTexture(GL_TEXTURE0 + i);
//				GLCheckError();
//
//				// for webngl
//#ifndef NDEBUG
//				GLint bound = 0;
//				glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
//				assert(bound > 0);
//#endif
//
//				int32_t filter_ = (int32_t)m_next.TextureFilterTypes[i];
//
//				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, glfilterMag[filter_]);
//				GLCheckError();
//
//				if (texture->GetHasMipmap())
//				{
//					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, glfilterMin[filter_]);
//				}
//				else
//				{
//					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, glfilterMin_NoneMipmap[filter_]);
//				}
//			}
//
//			// always changes because a flag is assigned into a texture
//			// if (m_active.TextureWrapTypes[i] != m_next.TextureWrapTypes[i] || forced)
//			{
//				//GLExt::glActiveTexture(GL_TEXTURE0 + i);
//				//GLCheckError();
//
//				//int32_t wrap_ = (int32_t)m_next.TextureWrapTypes[i];
//				auto wrap_ = m_next.TextureWrapTypes[i];
//				//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, glwrap[wrap_]);
//				//GLCheckError();
//
//				//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, glwrap[wrap_]);
//				//GLCheckError();
//			}
//		}
//		GLCheckError();
	}

//	GLExt::glActiveTexture(GL_TEXTURE0);

	BGFX(set_state)(state, 0);

	m_active = m_next;

//	GLCheckError();
}

} // namespace EffekseerRendererBGFX
