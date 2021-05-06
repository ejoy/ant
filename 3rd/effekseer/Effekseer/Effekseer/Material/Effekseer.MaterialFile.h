
#ifndef __EFFEKSEER_MATERIAL_H__
#define __EFFEKSEER_MATERIAL_H__

#include "../Effekseer.Base.Pre.h"
#include "../Utils/BinaryVersion.h"
#include <array>
#include <assert.h>
#include <map>
#include <sstream>
#include <string.h>
#include <vector>

namespace Effekseer
{

class MaterialFile
{
private:
	const int32_t customDataMinCount_ = 2;

	struct Texture
	{
		std::string Name;
		int32_t Index;
		TextureWrapType Wrap;
	};

	struct Uniform
	{
		std::string Name;
		int32_t Index;
	};

	uint64_t guid_ = 0;

	std::string genericCode_;

	bool hasRefraction_ = false;

	bool isSimpleVertex_ = false;

	ShadingModelType shadingModel_;

	int32_t customData1Count_ = 0;
	int32_t customData2Count_ = 0;

	std::vector<Texture> textures_;

	std::vector<Uniform> uniforms_;

	static const int32_t LatestSupportVersion = MaterialVersion16;
	static const int32_t OldestSupportVersion = 0;

public:
	MaterialFile() = default;
	virtual ~MaterialFile() = default;

	virtual bool Load(const uint8_t* data, int32_t size);

	virtual ShadingModelType GetShadingModel() const;

	virtual void SetShadingModel(ShadingModelType shadingModel);

	virtual bool GetIsSimpleVertex() const;

	virtual void SetIsSimpleVertex(bool isSimpleVertex);

	virtual bool GetHasRefraction() const;

	virtual void SetHasRefraction(bool hasRefraction);

	virtual const char* GetGenericCode() const;

	virtual void SetGenericCode(const char* code);

	virtual uint64_t GetGUID() const;

	virtual void SetGUID(uint64_t guid);

	virtual TextureWrapType GetTextureWrap(int32_t index) const;

	virtual void SetTextureWrap(int32_t index, TextureWrapType value);

	virtual int32_t GetTextureIndex(int32_t index) const;

	virtual void SetTextureIndex(int32_t index, int32_t value);

	virtual const char* GetTextureName(int32_t index) const;

	virtual void SetTextureName(int32_t index, const char* name);

	virtual int32_t GetTextureCount() const;

	virtual void SetTextureCount(int32_t count);

	virtual int32_t GetUniformIndex(int32_t index) const;

	virtual void SetUniformIndex(int32_t index, int32_t value);

	virtual const char* GetUniformName(int32_t index) const;

	virtual void SetUniformName(int32_t index, const char* name);

	virtual int32_t GetUniformCount() const;

	virtual void SetUniformCount(int32_t count);

	virtual int32_t GetCustomData1Count() const;

	virtual void SetCustomData1Count(int32_t count);

	virtual int32_t GetCustomData2Count() const;

	virtual void SetCustomData2Count(int32_t count);
};

} // namespace Effekseer

#endif // __EFFEKSEER_MATERIAL_H__