//#include "bgfx_utils.h"
#include "EffekseerRendererBGFX.Shader.h"
#include "EffekseerRendererBGFX.Renderer.h"

namespace EffekseerRendererBGFX {
bgfx_view_id_t g_view_id = 0;

Shader::Shader(bgfx_program_handle_t programHandle)
	: m_vertexConstantBuffer(nullptr)
	, m_pixelConstantBuffer(nullptr)
	, m_program{ programHandle }
{
	m_textureSlots.fill(BGFX_INVALID_HANDLE/*0*/);
	m_textureSlotEnables.fill(false);

	//baseInstance_ = GLExt::glGetUniformLocation(m_program, "SPIRV_Cross_BaseInstance");
}

Shader::~Shader()
{
	ES_SAFE_DELETE_ARRAY(m_vertexConstantBuffer);
	ES_SAFE_DELETE_ARRAY(m_pixelConstantBuffer);
}

Shader* Shader::Create(bgfx_program_handle_t program)
{
	if (BGFX_HANDLE_IS_VALID(program)) {
		return new Shader(program);
	} else {
		return nullptr;
	}
}

void Shader::SetUniforms(std::unordered_map<std::string, bgfx_uniform_handle_t>&& uniforms)
{
	uniforms_ = std::move(uniforms);
}

bgfx_program_handle_t Shader::GetInterface() const
{
	return m_program;
}

void Shader::BeginScene()
{
	//GLExt::glUseProgram(m_program);
}

void Shader::EndScene()
{
	BGFX(submit)(g_view_id, m_program, 0, BGFX_DISCARD_ALL);
}

void Shader::SetVertexConstantBufferSize(int32_t size)
{
	ES_SAFE_DELETE_ARRAY(m_vertexConstantBuffer);
	m_vertexConstantBuffer = new uint8_t[size];
}

void Shader::SetPixelConstantBufferSize(int32_t size)
{
	ES_SAFE_DELETE_ARRAY(m_pixelConstantBuffer);
	m_pixelConstantBuffer = new uint8_t[size];
}

void Shader::AddVertexConstantLayout(eConstantType type, bgfx_uniform_handle_t id, int32_t offset, int32_t count)
{
	ConstantLayout l;
	l.Type = type;
	l.ID = id;
	l.Offset = offset;
	l.Count = count;
	m_vertexConstantLayout.push_back(l);
}

void Shader::AddPixelConstantLayout(eConstantType type, bgfx_uniform_handle_t id, int32_t offset, int32_t count)
{
	ConstantLayout l;
	l.Type = type;
	l.ID = id;
	l.Offset = offset;
	l.Count = count;
	m_pixelConstantLayout.push_back(l);
}

void Shader::SetConstantBuffer()
{
	// baseInstance_
	//if (baseInstance_ >= 0)
	//{
	//	GLExt::glUniform1i(baseInstance_, 0);
	//}

	for (size_t i = 0; i < m_vertexConstantLayout.size(); i++)
	{
		if (m_vertexConstantLayout[i].Type == CONSTANT_TYPE_MATRIX44)
		{
			uint8_t* data = (uint8_t*)m_vertexConstantBuffer;
			data += m_vertexConstantLayout[i].Offset;
			//GLExt::glUniformMatrix4fv(m_vertexConstantLayout[i].ID, m_vertexConstantLayout[i].Count, isTransposeEnabled_ ? GL_TRUE : GL_FALSE, (const GLfloat*)data);
			//::Effekseer::Matrix44 mat;
			//memcpy(mat.Values, data, sizeof(float) * 16);
			//mat.Transpose();
			if (BGFX_HANDLE_IS_VALID(m_vertexConstantLayout[i].ID)) {
				BGFX(set_uniform)(m_vertexConstantLayout[i].ID, data, m_vertexConstantLayout[i].Count);
			}
		}

		else if (m_vertexConstantLayout[i].Type == CONSTANT_TYPE_VECTOR4)
		{
			uint8_t* data = (uint8_t*)m_vertexConstantBuffer;
			data += m_vertexConstantLayout[i].Offset;
			//GLExt::glUniform4fv(m_vertexConstantLayout[i].ID, m_vertexConstantLayout[i].Count, (const GLfloat*)data);
			if (BGFX_HANDLE_IS_VALID(m_vertexConstantLayout[i].ID)) {
				BGFX(set_uniform)(m_vertexConstantLayout[i].ID, data, m_vertexConstantLayout[i].Count);
			}
		}
	}

	for (size_t i = 0; i < m_pixelConstantLayout.size(); i++)
	{
		if (m_pixelConstantLayout[i].Type == CONSTANT_TYPE_MATRIX44)
		{
			uint8_t* data = (uint8_t*)m_pixelConstantBuffer;
			data += m_pixelConstantLayout[i].Offset;
			//GLExt::glUniformMatrix4fv(m_pixelConstantLayout[i].ID, m_pixelConstantLayout[i].Count, isTransposeEnabled_ ? GL_TRUE : GL_FALSE, (const GLfloat*)data);
			//::Effekseer::Matrix44 mat;
			//memcpy(mat.Values, data, sizeof(float) * 16);
			//mat.Transpose();
			if (BGFX_HANDLE_IS_VALID(m_pixelConstantLayout[i].ID)) {
				BGFX(set_uniform)(m_pixelConstantLayout[i].ID, data, m_pixelConstantLayout[i].Count);
			}
		}

		else if (m_pixelConstantLayout[i].Type == CONSTANT_TYPE_VECTOR4)
		{
			uint8_t* data = (uint8_t*)m_pixelConstantBuffer;
			data += m_pixelConstantLayout[i].Offset;
			//GLExt::glUniform4fv(m_pixelConstantLayout[i].ID, m_pixelConstantLayout[i].Count, (const GLfloat*)data);
			if (BGFX_HANDLE_IS_VALID(m_pixelConstantLayout[i].ID)) {
				BGFX(set_uniform)(m_pixelConstantLayout[i].ID, data, m_pixelConstantLayout[i].Count);
			}
		}
	}

	//GLCheckError();
}

void Shader::SetTextureSlot(int32_t index, bgfx_uniform_handle_t value)
{
	if (BGFX_HANDLE_IS_VALID(value))
	{
		m_textureSlots[index] = value;
		m_textureSlotEnables[index] = true;
	}
}

bgfx_uniform_handle_t Shader::GetTextureSlot(int32_t index)
{
	return m_textureSlots[index];
}

bool Shader::GetTextureSlotEnable(int32_t index)
{
	return m_textureSlotEnables[index];
}

bool Shader::IsValid() const
{
	return BGFX_HANDLE_IS_VALID(m_program);
}

} // namespace EffekseerRendererBGFX
