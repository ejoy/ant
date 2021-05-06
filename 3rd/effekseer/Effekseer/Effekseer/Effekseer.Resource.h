
#ifndef __EFFEKSEER_RESOURCE_H__
#define __EFFEKSEER_RESOURCE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Backend/GraphicsDevice.h"
#include "Effekseer.Base.Pre.h"
#include "Utils/Effekseer.CustomAllocator.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

/**
	@brief	\~english	Resource base
			\~japanese	リソース基底
*/
class Resource : public ReferenceObject
{
public:
	Resource() = default;

	virtual ~Resource() = default;

	const CustomString& GetPath()
	{
		return path_;
	}

private:
	friend class ResourceManager;

	void SetPath(const char16_t* path)
	{
		path_ = path;
	}

	CustomString path_;
};

/**
	@brief	\~english	Texture resource
			\~japanese	テクスチャリソース
*/
class Texture : public Resource
{
public:
	Texture() = default;
	~Texture() = default;

	int32_t GetWidth() const
	{
		return backend_->GetSize()[0];
	}
	int32_t GetHeight() const
	{
		return backend_->GetSize()[1];
	}

	const Backend::TextureRef& GetBackend()
	{
		return backend_;
	}

	void SetBackend(const Backend::TextureRef& backend)
	{
		backend_ = backend;
	}

private:
	Backend::TextureRef backend_;
};

/**
	@brief	\~english	Material resource
			\~japanese	マテリアルリソース
*/
class Material : public Resource
{
public:
	ShadingModelType ShadingModel = ShadingModelType::Lit;
	bool IsSimpleVertex = false;
	bool IsRefractionRequired = false;
	int32_t CustomData1 = 0;
	int32_t CustomData2 = 0;
	int32_t TextureCount = 0;
	int32_t UniformCount = 0;
	std::array<TextureWrapType, UserTextureSlotMax> TextureWrapTypes;
	void* UserPtr = nullptr;
	void* ModelUserPtr = nullptr;
	void* RefractionUserPtr = nullptr;
	void* RefractionModelUserPtr = nullptr;

	Material() = default;
	virtual ~Material() = default;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_RESOURCE_H__
