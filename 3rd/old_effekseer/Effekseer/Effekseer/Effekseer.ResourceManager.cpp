

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.ResourceManager.h"
#include "Effekseer.CurveLoader.h"
#include "Effekseer.MaterialLoader.h"
#include "Effekseer.SoundLoader.h"
#include "Effekseer.TextureLoader.h"
#include "Model/ModelLoader.h"
#include "Model/ProceduralModelGenerator.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
TextureRef ResourceManager::LoadTexture(const char16_t* path, TextureType textureType)
{
	return cachedTextures_.Load(path, textureType);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ResourceManager::UnloadTexture(TextureRef resource)
{
	cachedTextures_.Unload(resource);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ModelRef ResourceManager::LoadModel(const char16_t* path)
{
	return cachedModels_.Load(path);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ResourceManager::UnloadModel(ModelRef resource)
{
	cachedModels_.Unload(resource);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
SoundDataRef ResourceManager::LoadSoundData(const char16_t* path)
{
	return cachedSounds_.Load(path);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ResourceManager::UnloadSoundData(SoundDataRef resource)
{
	cachedSounds_.Unload(resource);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
MaterialRef ResourceManager::LoadMaterial(const char16_t* path)
{
	return cachedMaterials_.Load(path);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ResourceManager::UnloadMaterial(MaterialRef resource)
{
	cachedMaterials_.Unload(resource);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
CurveRef ResourceManager::LoadCurve(const char16_t* path)
{
	return cachedCurves_.Load(path);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ResourceManager::UnloadCurve(CurveRef resource)
{
	cachedCurves_.Unload(resource);
}

ModelRef ResourceManager::GenerateProceduralModel(const ProceduralModelParameter& param)
{
	return proceduralMeshGenerator_.Load(param);
}

void ResourceManager::UngenerateProceduralModel(ModelRef resource)
{
	proceduralMeshGenerator_.Unload(resource);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------