
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.Setting.h"
#include "Effekseer.EffectLoader.h"
#include "Effekseer.RectF.h"

#include "Effekseer.CurveLoader.h"
#include "Effekseer.MaterialLoader.h"
#include "Effekseer.SoundLoader.h"
#include "Effekseer.TextureLoader.h"
#include "Model/ModelLoader.h"
#include "Model/ProceduralModelGenerator.h"

#include "Renderer/Effekseer.ModelRenderer.h"
#include "Renderer/Effekseer.RibbonRenderer.h"
#include "Renderer/Effekseer.RingRenderer.h"
#include "Renderer/Effekseer.SpriteRenderer.h"
#include "Renderer/Effekseer.TrackRenderer.h"

#include "Effekseer.Effect.h"
#include "Effekseer.ResourceManager.h"
#include "IO/Effekseer.EfkEfcFactory.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Setting::Setting()
	: m_coordinateSystem(CoordinateSystem::RH)
{
	auto effectFactory = MakeRefPtr<EffectFactory>();
	AddEffectFactory(effectFactory);

	// this function is for 1.6
	auto efkefcFactory = MakeRefPtr<EfkEfcFactory>();
	AddEffectFactory(efkefcFactory);

	resourceManager_ = MakeRefPtr<ResourceManager>();
	resourceManager_->SetProceduralMeshGenerator(MakeRefPtr<ProceduralModelGenerator>());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Setting::~Setting()
{
	ClearEffectFactory();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
SettingRef Setting::Create()
{
	return SettingRef(new Setting());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
CoordinateSystem Setting::GetCoordinateSystem() const
{
	return m_coordinateSystem;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetCoordinateSystem(CoordinateSystem coordinateSystem)
{
	m_coordinateSystem = coordinateSystem;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectLoaderRef Setting::GetEffectLoader()
{
	return m_effectLoader;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetEffectLoader(EffectLoaderRef loader)
{
	m_effectLoader = loader;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
TextureLoaderRef Setting::GetTextureLoader() const
{
	return resourceManager_->GetTextureLoader();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetTextureLoader(TextureLoaderRef loader)
{
	resourceManager_->SetTextureLoader(loader);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ModelLoaderRef Setting::GetModelLoader() const
{
	return resourceManager_->GetModelLoader();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetModelLoader(ModelLoaderRef loader)
{
	resourceManager_->SetModelLoader(loader);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
SoundLoaderRef Setting::GetSoundLoader() const
{
	return resourceManager_->GetSoundLoader();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetSoundLoader(SoundLoaderRef loader)
{
	resourceManager_->SetSoundLoader(loader);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
MaterialLoaderRef Setting::GetMaterialLoader() const
{
	return resourceManager_->GetMaterialLoader();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetMaterialLoader(MaterialLoaderRef loader)
{
	resourceManager_->SetMaterialLoader(loader);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
CurveLoaderRef Setting::GetCurveLoader() const
{
	return resourceManager_->GetCurveLoader();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetCurveLoader(CurveLoaderRef loader)
{
	resourceManager_->SetCurveLoader(loader);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ProceduralModelGeneratorRef Setting::GetProceduralMeshGenerator() const
{
	return resourceManager_->GetProceduralMeshGenerator();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::SetProceduralMeshGenerator(ProceduralModelGeneratorRef generator)
{
	resourceManager_->SetProceduralMeshGenerator(generator);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::AddEffectFactory(const RefPtr<EffectFactory>& effectFactory)
{
	if (effectFactory.Get() == nullptr)
	{
		return;
	}

	auto effectFactoryCopied = effectFactory;
	effectFactories_.emplace_back(effectFactoryCopied);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Setting::ClearEffectFactory()
{
	effectFactories_.clear();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
const RefPtr<EffectFactory>& Setting::GetEffectFactory(int32_t ind) const
{
	return effectFactories_[ind];
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
int32_t Setting::GetEffectFactoryCount() const
{
	return static_cast<int32_t>(effectFactories_.size());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
const RefPtr<ResourceManager>& Setting::GetResourceManager() const
{
	return resourceManager_;
}

} // namespace Effekseer
