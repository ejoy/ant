
#ifndef __EFFEKSEER_RESOURCE_MANAGER_H__
#define __EFFEKSEER_RESOURCE_MANAGER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.Pre.h"
#include "Effekseer.Resource.h"
#include "Model/ProceduralModelGenerator.h"
#include "Model//ProceduralModelParameter.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

class ResourceManager : public ReferenceObject
{
public:
	ResourceManager() = default;

	~ResourceManager() = default;

	TextureLoaderRef GetTextureLoader() const
	{
		return cachedTextures_.loader;
	}

	void SetTextureLoader(TextureLoaderRef loader)
	{
		cachedTextures_.loader = loader;
	}

	ModelLoaderRef GetModelLoader() const
	{
		return cachedModels_.loader;
	}

	void SetModelLoader(ModelLoaderRef loader)
	{
		cachedModels_.loader = loader;
	}

	SoundLoaderRef GetSoundLoader() const
	{
		return cachedSounds_.loader;
	}

	void SetSoundLoader(SoundLoaderRef loader)
	{
		cachedSounds_.loader = loader;
	}

	MaterialLoaderRef GetMaterialLoader() const
	{
		return cachedMaterials_.loader;
	}

	void SetMaterialLoader(MaterialLoaderRef loader)
	{
		cachedMaterials_.loader = loader;
	}

	CurveLoaderRef GetCurveLoader() const
	{
		return cachedCurves_.loader;
	}

	void SetCurveLoader(CurveLoaderRef loader)
	{
		cachedCurves_.loader = loader;
	}

	ProceduralModelGeneratorRef GetProceduralMeshGenerator() const
	{
		return proceduralMeshGenerator_.loader;
	}

	void SetProceduralMeshGenerator(ProceduralModelGeneratorRef generator)
	{
		proceduralMeshGenerator_.loader = generator;
	}

	TextureRef LoadTexture(const char16_t* path, TextureType textureType);

	void UnloadTexture(TextureRef resource);

	ModelRef LoadModel(const char16_t* path);

	void UnloadModel(ModelRef resource);

	SoundDataRef LoadSoundData(const char16_t* path);

	void UnloadSoundData(SoundDataRef resource);

	MaterialRef LoadMaterial(const char16_t* path);

	void UnloadMaterial(MaterialRef resource);

	CurveRef LoadCurve(const char16_t* path);

	void UnloadCurve(CurveRef resource);

	ModelRef GenerateProceduralModel(const ProceduralModelParameter& param);

	void UngenerateProceduralModel(ModelRef resource);

private:

	template <typename T>
	struct LoadCounted
	{
		T resource;
		int32_t loadCount;
	};

	template <typename LOADER, typename RESOURCE>
	struct CachedResources
	{
		LOADER loader;
		CustomUnorderedMap<StringView, LoadCounted<RESOURCE>, StringView::Hash> cached;

		template <typename... Arg>
		RESOURCE Load(const char16_t* path, Arg&&... args)
		{
			if (loader != nullptr)
			{
				auto it = cached.find(path);
				if (it != cached.end())
				{
					it->second.loadCount++;
					return it->second.resource;
				}

				auto resource = loader->Load(path, args...);
				if (resource != nullptr)
				{
					resource->SetPath(path);
					const StringView view = resource->GetPath();
					cached.emplace(view, LoadCounted<RESOURCE>{resource, 1});
					return resource;
				}
			}
			return nullptr;
		}

		void Unload(const RESOURCE& resource)
		{
			if (loader != nullptr && resource != nullptr)
			{
				auto it = cached.find(resource->GetPath());
				if (it != cached.end())
				{
					if (--it->second.loadCount <= 0)
					{
						cached.erase(it);
						loader->Unload(resource);
					}
				}
			}
		}
	};

	template <typename PARAMETER, typename T>
	struct GenerateCounted
	{
		PARAMETER param;
		T resource;
		int32_t loadCount;
	};

	template <typename LOADER, typename PARAMETER, typename RESOURCE>
	struct CachedParameterResources
	{
		LOADER loader;
		CustomMap<PARAMETER, GenerateCounted<PARAMETER, RESOURCE>> cached;

		template <typename... Arg>
		RESOURCE Load(const PARAMETER& parameter)
		{
			if (loader != nullptr)
			{
				auto it = cached.find(parameter);
				if (it != cached.end())
				{
					it->second.loadCount++;
					return it->second.resource;
				}

				auto resource = loader->Generate(parameter);
				if (resource != nullptr)
				{
					cached.emplace(parameter, GenerateCounted<PARAMETER, RESOURCE>{parameter, resource, 1});
					return resource;
				}
			}
			return nullptr;
		}

		void Unload(const RESOURCE& resource)
		{
			if (loader != nullptr && resource != nullptr)
			{
				auto it = std::find_if(cached.begin(), cached.end(), [&](const std::pair<PARAMETER, GenerateCounted<PARAMETER, RESOURCE>>& v) { return v.second.resource == resource; });
				if (it != cached.end())
				{
					if (--it->second.loadCount <= 0)
					{
						cached.erase(it);
						loader->Ungenerate(resource);
					}
				}
			}
		}
	};

	CachedResources<TextureLoaderRef, TextureRef> cachedTextures_;
	CachedResources<ModelLoaderRef, ModelRef> cachedModels_;
	CachedResources<SoundLoaderRef, SoundDataRef> cachedSounds_;
	CachedResources<MaterialLoaderRef, MaterialRef> cachedMaterials_;
	CachedResources<CurveLoaderRef, CurveRef> cachedCurves_;
	CachedParameterResources<ProceduralModelGeneratorRef, ProceduralModelParameter, ModelRef> proceduralMeshGenerator_;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_RESOURCE_MANAGER_H__
