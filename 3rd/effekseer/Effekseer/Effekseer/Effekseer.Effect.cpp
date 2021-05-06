
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.Effect.h"
#include "Backend/GraphicsDevice.h"
#include "Effekseer.CurveLoader.h"
#include "Effekseer.DefaultEffectLoader.h"
#include "Effekseer.EffectImplemented.h"
#include "Effekseer.EffectLoader.h"
#include "Effekseer.EffectNode.h"
#include "Effekseer.Manager.h"
#include "Effekseer.ManagerImplemented.h"
#include "Effekseer.MaterialLoader.h"
#include "Effekseer.Resource.h"
#include "Effekseer.ResourceManager.h"
#include "Effekseer.Setting.h"
#include "Effekseer.SoundLoader.h"
#include "Effekseer.TextureLoader.h"
#include "Model/Model.h"
#include "Model/ModelLoader.h"
#include "Model/ProceduralModelGenerator.h"
#include "Model/ProceduralModelParameter.h"
#include "Utils/Effekseer.BinaryReader.h"

#include <array>
#include <functional>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

static void PathCombine(char16_t* dst, const char16_t* src1, const char16_t* src2)
{
	int len1 = 0, len2 = 0;
	if (src1 != nullptr)
	{
		for (len1 = 0; src1[len1] != L'\0'; len1++)
		{
		}
		memcpy(dst, src1, len1 * sizeof(char16_t));
		if (len1 > 0 && src1[len1 - 1] != L'/' && src1[len1 - 1] != L'\\')
		{
			dst[len1++] = L'/';
		}
	}
	if (src2 != nullptr)
	{
		for (len2 = 0; src2[len2] != L'\0'; len2++)
		{
		}
		memcpy(&dst[len1], src2, len2 * sizeof(char16_t));
	}

	for (int i = 0; i < len1 + len2; i++)
	{
		if (dst[i] == u'\\')
		{
			dst[i] = u'/';
		}
	}

	dst[len1 + len2] = L'\0';
}

static void GetParentDir(char16_t* dst, const char16_t* src)
{
	int i, last = -1;
	for (i = 0; src[i] != L'\0'; i++)
	{
		if (src[i] == L'/' || src[i] == L'\\')
			last = i;
	}
	if (last >= 0)
	{
		memcpy(dst, src, last * sizeof(char16_t));
		dst[last] = L'\0';
	}
	else
	{
		dst[0] = L'\0';
	}
}

static std::u16string getFilenameWithoutExt(const char16_t* path)
{
	int start = 0;
	int end = 0;

	for (int i = 0; path[i] != 0; i++)
	{
		if (path[i] == u'/' || path[i] == u'\\')
		{
			start = i;
		}
	}

	for (int i = start; path[i] != 0; i++)
	{
		if (path[i] == u'.')
		{
			end = i;
		}
	}

	std::vector<char16_t> ret;

	for (int i = start; i < end; i++)
	{
		ret.push_back(path[i]);
	}
	ret.push_back(0);

	return std::u16string(ret.data());
}

bool EffectFactory::LoadBody(Effect* effect, const void* data, int32_t size, float magnification, const char16_t* materialPath)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	auto data_ = static_cast<const uint8_t*>(data);
	return effect_->LoadBody(data_, size, magnification);
}

void EffectFactory::SetTexture(Effect* effect, int32_t index, TextureType type, TextureRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);

	if (type == TextureType::Color)
	{
		assert(0 <= index && index < effect_->m_pImages.size());
		effect_->m_pImages[index] = data;
	}

	if (type == TextureType::Normal)
	{
		assert(0 <= index && index < effect_->m_normalImages.size());
		effect_->m_normalImages[index] = data;
	}

	if (type == TextureType::Distortion)
	{
		assert(0 <= index && index < effect_->m_distortionImages.size());
		effect_->m_distortionImages[index] = data;
	}
}

void EffectFactory::SetSound(Effect* effect, int32_t index, SoundDataRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	assert(0 <= index && index < effect_->m_pWaves.size());
	effect_->m_pWaves[index] = data;
}

void EffectFactory::SetModel(Effect* effect, int32_t index, ModelRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	assert(0 <= index && index < effect_->models_.size());
	effect_->models_[index] = data;
}

void EffectFactory::SetMaterial(Effect* effect, int32_t index, MaterialRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	assert(0 <= index && index < effect_->materials_.size());
	effect_->materials_[index] = data;
}

void EffectFactory::SetCurve(Effect* effect, int32_t index, CurveRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	assert(0 <= index && index < effect_->curves_.size());
	effect_->curves_[index] = data;
}

void EffectFactory::SetProceduralModel(Effect* effect, int32_t index, ModelRef data)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	assert(0 <= index && index < effect_->proceduralModels_.size());
	effect_->proceduralModels_[index] = data;
}

void EffectFactory::SetLoadingParameter(Effect* effect, ReferenceObject* parameter)
{
	auto effect_ = static_cast<EffectImplemented*>(effect);
	effect_->SetLoadingParameter(parameter);
}

bool EffectFactory::OnCheckIsBinarySupported(const void* data, int32_t size)
{
	// EFKS
	int head = 0;
	memcpy(&head, data, sizeof(int));
	if (memcmp(&head, "SKFE", 4) != 0)
		return false;
	return true;
}

bool EffectFactory::OnCheckIsReloadSupported()
{
	return true;
}

bool EffectFactory::OnLoading(Effect* effect, const void* data, int32_t size, float magnification, const char16_t* materialPath)
{
	return this->LoadBody(effect, data, size, magnification, materialPath);
}

void EffectFactory::OnLoadingResource(Effect* effect, const void* data, int32_t size, const char16_t* materialPath)
{
	auto resourceMgr = effect->GetSetting()->GetResourceManager();

	for (auto i = 0; i < effect->GetColorImageCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetColorImagePath(i));

		auto resource = resourceMgr->LoadTexture(fullPath, TextureType::Color);
		SetTexture(effect, i, TextureType::Color, resource);
	}

	for (auto i = 0; i < effect->GetNormalImageCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetNormalImagePath(i));

		auto resource = resourceMgr->LoadTexture(fullPath, TextureType::Normal);
		SetTexture(effect, i, TextureType::Normal, resource);
	}

	for (auto i = 0; i < effect->GetDistortionImageCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetDistortionImagePath(i));

		auto resource = resourceMgr->LoadTexture(fullPath, TextureType::Distortion);
		SetTexture(effect, i, TextureType::Distortion, resource);
	}

	for (auto i = 0; i < effect->GetWaveCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetWavePath(i));

		auto resource = resourceMgr->LoadSoundData(fullPath);
		SetSound(effect, i, resource);
	}

	for (auto i = 0; i < effect->GetModelCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetModelPath(i));

		auto resource = resourceMgr->LoadModel(fullPath);
		SetModel(effect, i, resource);
	}

	for (auto i = 0; i < effect->GetMaterialCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetMaterialPath(i));

		auto resource = resourceMgr->LoadMaterial(fullPath);
		SetMaterial(effect, i, resource);
	}

	for (auto i = 0; i < effect->GetCurveCount(); i++)
	{
		char16_t fullPath[512];
		PathCombine(fullPath, materialPath, effect->GetCurvePath(i));

		auto resource = resourceMgr->LoadCurve(fullPath);
		SetCurve(effect, i, resource);
	}

	for (int32_t ind = 0; ind < effect->GetProceduralModelCount(); ind++)
	{
		const auto param = effect->GetProceduralModelParameter(ind);
		if (param != nullptr)
		{
			auto model = resourceMgr->GenerateProceduralModel(*param);
			SetProceduralModel(effect, ind, model);
		}
	}
}

void EffectFactory::OnUnloadingResource(Effect* effect)
{
	auto resourceMgr = effect->GetSetting()->GetResourceManager();

	for (auto i = 0; i < effect->GetColorImageCount(); i++)
	{
		resourceMgr->UnloadTexture(effect->GetColorImage(i));
		SetTexture(effect, i, TextureType::Color, nullptr);
	}

	for (auto i = 0; i < effect->GetNormalImageCount(); i++)
	{
		resourceMgr->UnloadTexture(effect->GetNormalImage(i));
		SetTexture(effect, i, TextureType::Normal, nullptr);
	}

	for (auto i = 0; i < effect->GetDistortionImageCount(); i++)
	{
		resourceMgr->UnloadTexture(effect->GetDistortionImage(i));
		SetTexture(effect, i, TextureType::Distortion, nullptr);
	}

	for (auto i = 0; i < effect->GetWaveCount(); i++)
	{
		resourceMgr->UnloadSoundData(effect->GetWave(i));
		SetSound(effect, i, nullptr);
	}

	for (auto i = 0; i < effect->GetModelCount(); i++)
	{
		resourceMgr->UnloadModel(effect->GetModel(i));
		SetModel(effect, i, nullptr);
	}

	for (auto i = 0; i < effect->GetMaterialCount(); i++)
	{
		resourceMgr->UnloadMaterial(effect->GetMaterial(i));
		SetMaterial(effect, i, nullptr);
	}

	for (auto i = 0; i < effect->GetCurveCount(); i++)
	{
		resourceMgr->UnloadCurve(effect->GetCurve(i));
		SetCurve(effect, i, nullptr);
	}

	for (int32_t ind = 0; ind < effect->GetProceduralModelCount(); ind++)
	{
		resourceMgr->UngenerateProceduralModel(effect->GetProceduralModel(ind));
		SetProceduralModel(effect, ind, nullptr);
	}
}

const char* EffectFactory::GetName() const
{
	static const char* name = "Default";
	return name;
}

bool EffectFactory::GetIsResourcesLoadedAutomatically() const
{
	return true;
}

EffectFactory::EffectFactory()
{
}

EffectFactory::~EffectFactory()
{
}

EffectRef Effect::Create(const ManagerRef& manager, const void* data, int32_t size, float magnification, const char16_t* materialPath)
{
	return EffectImplemented::Create(manager, data, size, magnification, materialPath);
}

EffectRef Effect::Create(const ManagerRef& manager, const char16_t* path, float magnification, const char16_t* materialPath)
{
	auto setting = manager->GetSetting();

	EffectLoaderRef eLoader = setting->GetEffectLoader();

	if (setting == nullptr)
		return nullptr;

	void* data = nullptr;
	int32_t size = 0;

	if (!eLoader->Load(path, data, size))
		return nullptr;

	char16_t parentDir[512];
	if (materialPath == nullptr)
	{
		GetParentDir(parentDir, path);
		materialPath = parentDir;
	}

	auto effect = EffectImplemented::Create(manager, data, size, magnification, materialPath);

	eLoader->Unload(data, size);

	effect->SetName(getFilenameWithoutExt(path).c_str());

	return effect;
}

bool EffectImplemented::LoadBody(const uint8_t* data, int32_t size, float mag)
{
	// TODO share with an editor
	const int32_t elementCountMax = 1024;
	const int32_t dynamicBinaryCountMax = 102400;

	uint8_t* pos = const_cast<uint8_t*>(data);

	BinaryReader<true> binaryReader(const_cast<uint8_t*>(data), size);

	// EFKS
	int head = 0;
	binaryReader.Read(head);
	if (memcmp(&head, "SKFE", 4) != 0)
		return false;

	binaryReader.Read(m_version);

	// too new version
	if (m_version > SupportBinaryVersion)
	{
		return false;
	}

	{
		// Color Image
		uint32_t imageCount = 0;
		binaryReader.Read(imageCount, 0, elementCountMax);

		if (imageCount > 0)
		{
			m_ImagePaths.resize(imageCount);
			m_pImages.resize(imageCount);

			for (uint32_t i = 0; i < imageCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				m_ImagePaths[i].reset(new char16_t[length]);
				binaryReader.Read(m_ImagePaths[i].get(), length);
			}
		}
	}

	if (m_version >= 9)
	{
		// Normal Image
		uint32_t normalImageCount = 0;
		binaryReader.Read(normalImageCount, 0, elementCountMax);

		if (normalImageCount > 0)
		{
			m_normalImagePaths.resize(normalImageCount);
			m_normalImages.resize(normalImageCount);

			for (uint32_t i = 0; i < normalImageCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				m_normalImagePaths[i].reset(new char16_t[length]);
				binaryReader.Read(m_normalImagePaths[i].get(), length);
			}
		}

		// Distortion Image
		uint32_t distortionImageCount = 0;
		binaryReader.Read(distortionImageCount, 0, elementCountMax);

		if (distortionImageCount > 0)
		{
			m_distortionImagePaths.resize(distortionImageCount);
			m_distortionImages.resize(distortionImageCount);

			for (uint32_t i = 0; i < distortionImageCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				m_distortionImagePaths[i].reset(new char16_t[length]);
				binaryReader.Read(m_distortionImagePaths[i].get(), length);
			}
		}
	}

	if (m_version >= 1)
	{
		// Sound
		uint32_t waveCount = 0;
		binaryReader.Read(waveCount, 0, elementCountMax);

		if (waveCount > 0)
		{
			m_WavePaths.resize(waveCount);
			m_pWaves.resize(waveCount);

			for (uint32_t i = 0; i < waveCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				m_WavePaths[i].reset(new char16_t[length]);
				binaryReader.Read(m_WavePaths[i].get(), length);
			}
		}
	}

	if (m_version >= 6)
	{
		// Model
		uint32_t modelCount = 0;
		binaryReader.Read(modelCount, 0, elementCountMax);

		if (modelCount > 0)
		{
			modelPaths_.resize(modelCount);
			models_.resize(modelCount);

			for (uint32_t i = 0; i < modelCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				modelPaths_[i].reset(new char16_t[length]);
				binaryReader.Read(modelPaths_[i].get(), length);
			}
		}
	}

	if (m_version >= 15)
	{
		// material
		uint32_t materialCount = 0;
		binaryReader.Read(materialCount, 0, elementCountMax);

		if (materialCount > 0)
		{
			materialPaths_.resize(materialCount);
			materials_.resize(materialCount);

			for (uint32_t i = 0; i < materialCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				materialPaths_[i].reset(new char16_t[length]);
				binaryReader.Read(materialPaths_[i].get(), length);
			}
		}
	}

	const auto loadCurves = [&]() -> void {
		// curve
		int32_t curveCount = 0;
		binaryReader.Read(curveCount, 0, elementCountMax);

		if (curveCount > 0)
		{
			curvePaths_.resize(curveCount);
			curves_.resize(curveCount);

			for (int i = 0; i < curveCount; i++)
			{
				int length = 0;
				binaryReader.Read(length, 0, elementCountMax);

				curvePaths_[i].reset(new char16_t[length]);
				binaryReader.Read(curvePaths_[i].get(), length);
			}
		}
	};

	const auto loadProceduralModels = [&]() -> void {
		// curve
		int32_t pmCount = 0;

		binaryReader.Read(pmCount, 0, elementCountMax);

		proceduralModelParameters_.resize(pmCount);
		proceduralModels_.resize(pmCount);

		for (int32_t i = 0; i < pmCount; i++)
		{
			proceduralModelParameters_[i].Load(binaryReader, m_version);
			proceduralModels_[i] = nullptr;
		}
	};

	if (Version16Alpha8 <= m_version)
	{
		loadCurves();

		loadProceduralModels();
	}

	if (m_version >= 14)
	{
		// inputs
		defaultDynamicInputs.fill(0);
		uint32_t dynamicInputCount = 0;
		binaryReader.Read(dynamicInputCount, 0, elementCountMax);

		for (size_t i = 0; i < dynamicInputCount; i++)
		{
			float param = 0.0f;
			binaryReader.Read(param);

			if (i < defaultDynamicInputs.size())
			{
				defaultDynamicInputs[i] = param;
			}
		}

		// dynamic parameter
		int32_t dynamicEquationCount = 0;
		binaryReader.Read(dynamicEquationCount, 0, elementCountMax);

		if (dynamicEquationCount > 0)
		{
			dynamicEquation.resize(dynamicEquationCount);

			for (size_t dp = 0; dp < dynamicEquation.size(); dp++)
			{
				int size_ = 0;
				binaryReader.Read(size_, 0, dynamicBinaryCountMax);

				auto data_ = pos + binaryReader.GetOffset();
				dynamicEquation[dp].Load(data_, size_);

				binaryReader.AddOffset(size_);
			}
		}
	}
	else
	{
		defaultDynamicInputs.fill(0);
	}

	if (Version16Alpha8 > m_version && m_version >= Version16Alpha1)
	{
		loadCurves();

		loadProceduralModels();
	}

	if (m_version >= 13)
	{
		binaryReader.Read(renderingNodesCount, 0, elementCountMax);
		binaryReader.Read(renderingNodesThreshold, 0, elementCountMax);
	}

	// magnification
	if (m_version >= 2)
	{
		binaryReader.Read(m_maginification);
	}

	m_maginification *= mag;
	m_maginificationExternal = mag;

	if (m_version >= 11)
	{
		binaryReader.Read(m_defaultRandomSeed);
	}
	else
	{
		m_defaultRandomSeed = -1;
	}

	// Culling
	if (m_version >= 9)
	{
		binaryReader.Read(Culling.Shape);
		if (Culling.Shape == CullingShape::Sphere)
		{
			binaryReader.Read(Culling.Sphere.Radius);
			binaryReader.Read(Culling.Location.X);
			binaryReader.Read(Culling.Location.Y);
			binaryReader.Read(Culling.Location.Z);

			Culling.Sphere.Radius *= m_maginification;
			Culling.Location.X *= m_maginification;
			Culling.Location.Y *= m_maginification;
			Culling.Location.Z *= m_maginification;
		}
	}

	// Check
	if (binaryReader.GetStatus() == BinaryReaderStatus::Failed)
		return false;

	// Nodes
	auto nodeData = pos + binaryReader.GetOffset();
	m_pRoot = EffectNodeImplemented::Create(this, nullptr, nodeData);

	return true;
}

void EffectImplemented::ResetReloadingBackup()
{
	if (reloadingBackup == nullptr)
		return;

	auto loader = GetSetting();
	auto resourceMgr = loader->GetResourceManager();

	for (auto it : reloadingBackup->images.GetCollection())
	{
		resourceMgr->UnloadTexture(it.second.value);
	}

	for (auto it : reloadingBackup->normalImages.GetCollection())
	{
		resourceMgr->UnloadTexture(it.second.value);
	}

	for (auto it : reloadingBackup->distortionImages.GetCollection())
	{
		resourceMgr->UnloadTexture(it.second.value);
	}

	for (auto it : reloadingBackup->sounds.GetCollection())
	{
		resourceMgr->UnloadSoundData(it.second.value);
	}

	for (auto it : reloadingBackup->models.GetCollection())
	{
		resourceMgr->UnloadModel(it.second.value);
	}

	reloadingBackup.reset();
}

EffectRef EffectImplemented::Create(const ManagerRef& pManager, const void* pData, int size, float magnification, const char16_t* materialPath)
{
	if (pData == nullptr || size == 0)
		return nullptr;

	auto effect = MakeRefPtr<EffectImplemented>(pManager, pData, size);
	if (!effect->Load(pData, size, magnification, materialPath, ReloadingThreadType::Main))
	{
		return nullptr;
	}
	return effect;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectRef Effect::Create(const SettingRef& setting, const void* data, int32_t size, float magnification, const char16_t* materialPath)
{
	return EffectImplemented::Create(setting, data, size, magnification, materialPath);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectRef Effect::Create(const SettingRef& setting, const char16_t* path, float magnification, const char16_t* materialPath)
{
	if (setting == nullptr)
		return nullptr;
	EffectLoaderRef eLoader = setting->GetEffectLoader();

	if (setting == nullptr)
		return nullptr;

	void* data = nullptr;
	int32_t size = 0;

	if (!eLoader->Load(path, data, size))
		return nullptr;

	char16_t parentDir[512];
	if (materialPath == nullptr)
	{
		GetParentDir(parentDir, path);
		materialPath = parentDir;
	}

	auto effect = EffectImplemented::Create(setting, data, size, magnification, materialPath);

	eLoader->Unload(data, size);

	effect->SetName(getFilenameWithoutExt(path).c_str());

	return effect;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectRef EffectImplemented::Create(const SettingRef& setting, const void* pData, int size, float magnification, const char16_t* materialPath)
{
	if (pData == nullptr || size == 0)
		return nullptr;

	auto effect = MakeRefPtr<EffectImplemented>(setting, pData, size);
	if (!effect->Load(pData, size, magnification, materialPath, ReloadingThreadType::Main))
	{
		effect = nullptr;
	}
	return effect;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
::Effekseer::EffectLoaderRef Effect::CreateEffectLoader(::Effekseer::FileInterface* fileInterface)
{
	return EffectLoaderRef(new ::Effekseer::DefaultEffectLoader(fileInterface));
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectImplemented::EffectImplemented(const ManagerRef& pManager, const void* pData, int size)
	: m_setting(pManager->GetSetting())
	, m_reference(1)
	, m_version(0)
	, m_defaultRandomSeed(-1)

{
	Culling.Shape = CullingShape::NoneShape;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectImplemented::EffectImplemented(const SettingRef& setting, const void* pData, int size)
	: m_setting(setting)
	, m_reference(1)
	, m_version(0)
{
	Culling.Shape = CullingShape::NoneShape;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectImplemented::~EffectImplemented()
{
	ResetReloadingBackup();
	Reset();
	SetLoadingParameter(nullptr);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
EffectNode* EffectImplemented::GetRoot() const
{
	return m_pRoot;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
float EffectImplemented::GetMaginification() const
{
	return m_maginification;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
bool EffectImplemented::Load(const void* pData, int size, float mag, const char16_t* materialPath, ReloadingThreadType reloadingThreadType)
{
	factory.Reset();

	if (m_setting != nullptr)
	{
		for (int i = 0; i < m_setting->GetEffectFactoryCount(); i++)
		{
			auto f = m_setting->GetEffectFactory(i);

			if (f->OnCheckIsBinarySupported(pData, size))
			{
				factory = f;
				break;
			}
		}
	}

	if (factory == nullptr)
		return false;

	// if reladingThreadType == ReloadingThreadType::Main, this function was regarded as loading function actually

	if (!factory->OnCheckIsBinarySupported(pData, size))
	{
		return false;
	}

	EffekseerPrintDebug("** Create : Effect\n");

	if (!factory->OnLoading(this, pData, size, mag, materialPath))
	{
		return false;
	}

	// save materialPath for reloading
	if (materialPath != nullptr)
		materialPath_ = materialPath;

	if (factory->GetIsResourcesLoadedAutomatically())
	{
		ReloadResources(pData, size, materialPath);
	}

	return true;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectImplemented::Reset()
{
	UnloadResources();

	m_ImagePaths.clear();
	m_pImages.clear();
	m_normalImagePaths.clear();
	m_normalImages.clear();
	m_distortionImagePaths.clear();
	m_distortionImagePaths.clear();
	m_WavePaths.clear();
	m_pWaves.clear();
	modelPaths_.clear();
	models_.clear();
	materialPaths_.clear();
	materials_.clear();
	curvePaths_.clear();
	curves_.clear();

	ES_SAFE_DELETE(m_pRoot);
}

bool EffectImplemented::IsDyanamicMagnificationValid() const
{
	return GetVersion() >= 8 || GetVersion() < 2;
}

ReferenceObject* EffectImplemented::GetLoadingParameter() const
{
	return loadingObject;
}

void EffectImplemented::SetLoadingParameter(ReferenceObject* obj)
{
	ES_SAFE_ADDREF(obj);
	ES_SAFE_RELEASE(loadingObject);
	loadingObject = obj;
}

const char16_t* EffectImplemented::GetName() const
{
	return name_.c_str();
}

void EffectImplemented::SetName(const char16_t* name)
{
	name_ = name;
}

const SettingRef& EffectImplemented::GetSetting() const
{
	return m_setting;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
int EffectImplemented::GetVersion() const
{
	return m_version;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
TextureRef EffectImplemented::GetColorImage(int n) const
{
	if (n < 0 || n >= GetColorImageCount())
	{
		return nullptr;
	}

	return m_pImages[n];
}

int32_t EffectImplemented::GetColorImageCount() const
{
	return static_cast<int32_t>(m_pImages.size());
}

const char16_t* EffectImplemented::GetColorImagePath(int n) const
{
	if (n < 0 || n >= GetColorImageCount())
	{
		return nullptr;
	}

	return m_ImagePaths[n].get();
}

TextureRef EffectImplemented::GetNormalImage(int n) const
{
	/* 強制的に互換をとる */
	if (this->m_version <= 8)
	{
		return GetColorImage(n);
	}

	if (n < 0 || n >= GetNormalImageCount())
	{
		return nullptr;
	}

	return m_normalImages[n];
}

int32_t EffectImplemented::GetNormalImageCount() const
{
	return static_cast<int32_t>(m_normalImages.size());
}

const char16_t* EffectImplemented::GetNormalImagePath(int n) const
{
	if (n < 0 || n >= GetNormalImageCount())
	{
		return nullptr;
	}

	return m_normalImagePaths[n].get();
}

TextureRef EffectImplemented::GetDistortionImage(int n) const
{
	/* 強制的に互換をとる */
	if (this->m_version <= 8)
	{
		return GetColorImage(n);
	}

	if (n < 0 || n >= GetDistortionImageCount())
	{
		return nullptr;
	}

	return m_distortionImages[n];
}

int32_t EffectImplemented::GetDistortionImageCount() const
{
	return static_cast<int32_t>(m_distortionImages.size());
}

const char16_t* EffectImplemented::GetDistortionImagePath(int n) const
{
	if (n < 0 || n >= GetDistortionImageCount())
	{
		return nullptr;
	}

	return m_distortionImagePaths[n].get();
}

SoundDataRef EffectImplemented::GetWave(int n) const
{
	if (n < 0 || n >= GetWaveCount())
	{
		return nullptr;
	}

	return m_pWaves[n];
}

int32_t EffectImplemented::GetWaveCount() const
{
	return static_cast<int32_t>(m_pWaves.size());
}

const char16_t* EffectImplemented::GetWavePath(int n) const
{
	if (n < 0 || n >= GetWaveCount())
	{
		return nullptr;
	}

	return m_WavePaths[n].get();
}

ModelRef EffectImplemented::GetModel(int n) const
{
	if (n < 0 || n >= GetModelCount())
	{
		return nullptr;
	}

	return models_[n];
}

int32_t EffectImplemented::GetModelCount() const
{
	return static_cast<int32_t>(models_.size());
}

const char16_t* EffectImplemented::GetModelPath(int n) const
{
	if (n < 0 || n >= GetModelCount())
	{
		return nullptr;
	}

	return modelPaths_[n].get();
}

MaterialRef EffectImplemented::GetMaterial(int n) const
{
	if (n < 0 || n >= GetMaterialCount())
	{
		return nullptr;
	}

	return materials_[n];
}

int32_t EffectImplemented::GetMaterialCount() const
{
	return static_cast<int32_t>(materials_.size());
}

const char16_t* EffectImplemented::GetMaterialPath(int n) const
{
	if (n < 0 || n >= GetMaterialCount())
	{
		return nullptr;
	}

	return materialPaths_[n].get();
}

CurveRef EffectImplemented::GetCurve(int n) const
{
	if (n < 0 || n >= GetCurveCount())
	{
		return nullptr;
	}

	return curves_[n];
}

int32_t EffectImplemented::GetCurveCount() const
{
	return static_cast<int32_t>(curves_.size());
}

const char16_t* EffectImplemented::GetCurvePath(int n) const
{
	if (n < 0 || n >= GetCurveCount())
	{
		return nullptr;
	}

	return curvePaths_[n].get();
}

ModelRef EffectImplemented::GetProceduralModel(int n) const
{
	if (n < 0 || n >= GetProceduralModelCount())
	{
		return nullptr;
	}

	return proceduralModels_[n];
}

int32_t EffectImplemented::GetProceduralModelCount() const
{
	return static_cast<int32_t>(proceduralModelParameters_.size());
}

const ProceduralModelParameter* EffectImplemented::GetProceduralModelParameter(int n) const
{
	if (n < 0 || n >= GetProceduralModelCount())
	{
		return nullptr;
	}

	return &proceduralModelParameters_[n];
}

void EffectImplemented::SetTexture(int32_t index, TextureType type, TextureRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();

	if (type == TextureType::Color)
	{
		assert(0 <= index && index < m_pImages.size());
		if (m_pImages[index] != nullptr)
		{
			resourceMgr->UnloadTexture(m_pImages[index]);
		}

		m_pImages[index] = data;
	}

	if (type == TextureType::Normal)
	{
		assert(0 <= index && index < m_normalImages.size());
		if (m_normalImages[index] != nullptr)
		{
			resourceMgr->UnloadTexture(m_normalImages[index]);
		}

		m_normalImages[index] = data;
	}

	if (type == TextureType::Distortion)
	{
		assert(0 <= index && index < m_distortionImages.size());
		if (m_distortionImages[index] != nullptr)
		{
			resourceMgr->UnloadTexture(m_distortionImages[index]);
		}

		m_distortionImages[index] = data;
	}
}

void EffectImplemented::SetSound(int32_t index, SoundDataRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();
	assert(0 <= index && index < m_pWaves.size());
	resourceMgr->UnloadSoundData(m_pWaves[index]);
	m_pWaves[index] = data;
}

void EffectImplemented::SetModel(int32_t index, ModelRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();
	assert(0 <= index && index < models_.size());
	resourceMgr->UnloadModel(models_[index]);
	models_[index] = data;
}

void EffectImplemented::SetMaterial(int32_t index, MaterialRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();
	assert(0 <= index && index < materials_.size());
	resourceMgr->UnloadMaterial(materials_[index]);
	materials_[index] = data;
}

void EffectImplemented::SetCurve(int32_t index, CurveRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();
	assert(0 <= index && index < curves_.size());
	resourceMgr->UnloadCurve(curves_[index]);
	curves_[index] = data;
}

void EffectImplemented::SetProceduralModel(int32_t index, ModelRef data)
{
	auto resourceMgr = GetSetting()->GetResourceManager();
	assert(0 <= index && index < proceduralModels_.size());
	resourceMgr->UngenerateProceduralModel(proceduralModels_[index]);
	proceduralModels_[index] = data;
}

bool EffectImplemented::Reload(ManagerRef* managers,
							   int32_t managersCount,
							   const void* data,
							   int32_t size,
							   const char16_t* materialPath,
							   ReloadingThreadType reloadingThreadType)
{
	if (!factory->OnCheckIsReloadSupported())
		return false;

	const char16_t* matPath = materialPath != nullptr ? materialPath : materialPath_.c_str();

	for (int32_t i = 0; i < managersCount; i++)
	{
		// to call only once
		for (int32_t j = 0; j < i; j++)
		{
			if (managers[i] == managers[j])
				continue;
		}

		auto manager = managers[i]->GetImplemented();
		manager->BeginReloadEffect(EffectRef::FromPinned(this), true);
	}

	// HACK for scale
	auto originalMag = this->GetMaginification() / this->m_maginificationExternal;
	auto originalMagExt = this->m_maginificationExternal;

	isReloadingOnRenderingThread = reloadingThreadType == ReloadingThreadType::Render;
	Reset();
	Load(data, size, originalMag * originalMagExt, matPath, reloadingThreadType);

	// HACK for scale
	m_maginification = originalMag * originalMagExt;
	m_maginificationExternal = originalMagExt;

	isReloadingOnRenderingThread = false;

	for (int32_t i = 0; i < managersCount; i++)
	{
		// to call only once
		for (int32_t j = 0; j < i; j++)
		{
			if (managers[i] == managers[j])
				continue;
		}

		auto manager = managers[i]->GetImplemented();
		manager->EndReloadEffect(EffectRef::FromPinned(this), true);
	}

	return true;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
bool EffectImplemented::Reload(
	ManagerRef* managers, int32_t managersCount, const char16_t* path, const char16_t* materialPath, ReloadingThreadType reloadingThreadType)
{
	if (!factory->OnCheckIsReloadSupported())
		return false;

	auto loader = GetSetting();

	EffectLoaderRef eLoader = loader->GetEffectLoader();
	if (loader == nullptr)
		return false;

	void* data = nullptr;
	int32_t size = 0;

	if (!eLoader->Load(path, data, size))
		return false;

	char16_t parentDir[512];
	if (materialPath == nullptr)
	{
		GetParentDir(parentDir, path);
		materialPath = parentDir;
	}

	int lockCount = 0;

	for (int32_t i = 0; i < managersCount; i++)
	{
		auto manager = managers[i]->GetImplemented();
		manager->BeginReloadEffect(EffectRef::FromPinned(this), true);
		lockCount++;
	}

	isReloadingOnRenderingThread = reloadingThreadType == ReloadingThreadType::Render;
	Reset();
	Load(data, size, m_maginificationExternal, materialPath, reloadingThreadType);
	isReloadingOnRenderingThread = false;

	for (int32_t i = 0; i < managersCount; i++)
	{
		lockCount--;
		auto manager = managers[i]->GetImplemented();
		manager->EndReloadEffect(EffectRef::FromPinned(this), true);
	}

	eLoader->Unload(data, size);

	return true;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void EffectImplemented::ReloadResources(const void* data, int32_t size, const char16_t* materialPath)
{
	UnloadResources();

	const char16_t* matPath = materialPath != nullptr ? materialPath : materialPath_.c_str();

	auto loader = GetSetting();

	// reloading on render thread
	if (isReloadingOnRenderingThread)
	{
		assert(reloadingBackup != nullptr);

		for (uint32_t ind = 0; ind < m_pImages.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_ImagePaths[ind].get());

			TextureRef value = nullptr;
			if (reloadingBackup->images.Pop(fullPath, value))
			{
				m_pImages[ind] = value;
			}
		}

		for (uint32_t ind = 0; ind < m_normalImages.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_normalImagePaths[ind].get());

			TextureRef value = nullptr;
			if (reloadingBackup->normalImages.Pop(fullPath, value))
			{
				m_normalImages[ind] = value;
			}
		}

		for (uint32_t ind = 0; ind < m_distortionImages.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_distortionImagePaths[ind].get());

			TextureRef value = nullptr;
			if (reloadingBackup->distortionImages.Pop(fullPath, value))
			{
				m_distortionImages[ind] = value;
			}
		}

		for (uint32_t ind = 0; ind < m_pWaves.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_WavePaths[ind].get());

			SoundDataRef value;
			if (reloadingBackup->sounds.Pop(fullPath, value))
			{
				m_pWaves[ind] = value;
			}
		}

		for (size_t ind = 0; ind < models_.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, modelPaths_[ind].get());

			ModelRef value = nullptr;
			if (reloadingBackup->models.Pop(fullPath, value))
			{
				models_[ind] = value;
			}
		}

		for (uint32_t ind = 0; ind < materials_.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, materialPaths_[ind].get());

			MaterialRef value = nullptr;
			if (reloadingBackup->materials.Pop(fullPath, value))
			{
				materials_[ind] = value;
			}
		}

		for (uint32_t ind = 0; ind < curves_.size(); ind++)
		{
			char16_t fullPath[512];
			PathCombine(fullPath, matPath, curvePaths_[ind].get());

			CurveRef value = nullptr;
			if (reloadingBackup->curves.Pop(fullPath, value))
			{
				curves_[ind] = value;
			}
		}

		return;
	}

	factory->OnLoadingResource(this, data, size, matPath);
}

void EffectImplemented::UnloadResources(const char16_t* materialPath)
{
	auto loader = GetSetting();

	// reloading on render thread
	if (isReloadingOnRenderingThread)
	{
		if (reloadingBackup == nullptr)
		{
			reloadingBackup = std::unique_ptr<EffectReloadingBackup>(new EffectReloadingBackup());
		}

		const char16_t* matPath = materialPath != nullptr ? materialPath : materialPath_.c_str();

		for (uint32_t ind = 0; ind < m_pImages.size(); ind++)
		{
			if (m_pImages[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_ImagePaths[ind].get());
			reloadingBackup->images.Push(fullPath, m_pImages[ind]);
		}

		for (uint32_t ind = 0; ind < m_normalImages.size(); ind++)
		{
			if (m_normalImages[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_normalImagePaths[ind].get());
			reloadingBackup->normalImages.Push(fullPath, m_normalImages[ind]);
		}

		for (uint32_t ind = 0; ind < m_distortionImages.size(); ind++)
		{
			if (m_distortionImagePaths[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_distortionImagePaths[ind].get());
			reloadingBackup->distortionImages.Push(fullPath, m_distortionImages[ind]);
		}

		for (uint32_t ind = 0; ind < m_pWaves.size(); ind++)
		{
			if (m_pWaves[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, m_WavePaths[ind].get());
			reloadingBackup->sounds.Push(fullPath, m_pWaves[ind]);
		}

		for (size_t ind = 0; ind < models_.size(); ind++)
		{
			if (models_[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, modelPaths_[ind].get());
			reloadingBackup->models.Push(fullPath, models_[ind]);
		}

		for (uint32_t ind = 0; ind < materials_.size(); ind++)
		{
			if (materials_[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, materialPaths_[ind].get());
			reloadingBackup->materials.Push(fullPath, materials_[ind]);
		}

		for (uint32_t ind = 0; ind < curves_.size(); ind++)
		{
			if (curves_[ind] == nullptr)
				continue;

			char16_t fullPath[512];
			PathCombine(fullPath, matPath, curvePaths_[ind].get());
			reloadingBackup->curves.Push(fullPath, curves_[ind]);
		}

		return;
	}
	else
	{
		ResetReloadingBackup();
	}

	if (factory != nullptr)
	{
		factory->OnUnloadingResource(this);
	}
}

void EffectImplemented::UnloadResources()
{
	UnloadResources(nullptr);
}

EffectTerm EffectImplemented::CalculateTerm() const
{

	EffectTerm effectTerm;
	effectTerm.TermMin = 0;
	effectTerm.TermMax = 0;

	auto root = GetRoot();
	EffectInstanceTerm rootTerm;

	std::function<void(EffectNode*, EffectInstanceTerm&)> recurse;
	recurse = [&effectTerm, &recurse](EffectNode* node, EffectInstanceTerm& term) -> void {
		for (int i = 0; i < node->GetChildrenCount(); i++)
		{
			auto cterm = node->GetChild(i)->CalculateInstanceTerm(term);
			effectTerm.TermMin = Max(effectTerm.TermMin, cterm.LastInstanceEndMin);
			effectTerm.TermMax = Max(effectTerm.TermMax, cterm.LastInstanceEndMax);

			recurse(node->GetChild(i), cterm);
		}
	};

	recurse(root, rootTerm);

	return effectTerm;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
