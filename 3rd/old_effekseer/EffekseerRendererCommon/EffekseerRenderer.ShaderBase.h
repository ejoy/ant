
#ifndef __EFFEKSEERRENDERER_SHADER_BASE_H__
#define __EFFEKSEERRENDERER_SHADER_BASE_H__

#include <Effekseer.h>
#include <assert.h>
#include <sstream>
#include <string.h>

namespace EffekseerRenderer
{
class ShaderBase
{
public:
	ShaderBase()
	{
	}
	virtual ~ShaderBase()
	{
	}

	virtual void SetVertexConstantBufferSize(int32_t size) = 0;
	virtual void SetPixelConstantBufferSize(int32_t size) = 0;

	virtual void* GetVertexConstantBuffer() = 0;
	virtual void* GetPixelConstantBuffer() = 0;

	virtual void SetConstantBuffer() = 0;
};

} // namespace EffekseerRenderer

#endif // __EFFEKSEERRENDERER_SHADER_BASE_H__