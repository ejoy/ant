
#ifndef __EFFEKSEER_EFFECT_IMPLEMENTED_H__
#define __EFFEKSEER_EFFECT_IMPLEMENTED_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Effect.h"
#include "Effekseer.InternalScript.h"
#include "Effekseer.Vector3D.h"
#include "Model/ProceduralModelParameter.h"
#include "Utils/BinaryVersion.h"
#include "Utils/Effekseer.CustomAllocator.h"
#include <assert.h>
#include <memory>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

/**
	@brief	A class to backup resorces when effect is reloaded
*/
class EffectReloadingBackup
{
public:
	template <class T>
	class Holder
	{
	public:
		T value;
		int counter = 0;
	};

	template <class T>
	class HolderCollection
	{
		std::map<std::u16string, Holder<T>> collection;

	public:
		void Push(const char16_t* key, T value)
		{
			auto key_ = std::u16string(key);
			auto it = collection.find(key_);

			if (it == collection.end())
			{
				collection[key_].value = value;
				collection[key_].counter = 1;
			}
			else
			{
				assert(it->second.value == value);
				it->second.counter++;
			}
		}

		bool Pop(const char16_t* key, T& value)
		{
			auto key_ = std::u16string(key);
			auto it = collection.find(key_);

			if (it == collection.end())
			{
				return false;
			}
			else
			{
				it->second.counter--;
				value = it->second.value;
				if (it->second.counter == 0)
				{
					collection.erase(it);
				}
				return true;
			}
		}

		std::map<std::u16string, Holder<T>>& GetCollection()
		{
			return collection;
		}
	};

	HolderCollection<TextureRef> images;
	HolderCollection<TextureRef> normalImages;
	HolderCollection<TextureRef> distortionImages;
	HolderCollection<SoundDataRef> sounds;
	HolderCollection<ModelRef> models;
	HolderCollection<MaterialRef> materials;
	HolderCollection<CurveRef> curves;
};

/**
	@brief	Effect parameter
*/
class EffectImplemented : public Effect, public ReferenceObject
{
	friend class ManagerImplemented;
	friend class EffectNodeImplemented;
	friend class EffectFactory;
	friend class Instance;

	static const int32_t SupportBinaryVersion = Version16;

protected:
	SettingRef m_setting;

	mutable std::atomic<int32_t> m_reference;

	RefPtr<EffectFactory> factory;

	int m_version;

	CustomVector<std::unique_ptr<char16_t[]>> m_ImagePaths;
	CustomVector<TextureRef> m_pImages;

	CustomVector<std::unique_ptr<char16_t[]>> m_normalImagePaths;
	CustomVector<TextureRef> m_normalImages;

	CustomVector<std::unique_ptr<char16_t[]>> m_distortionImagePaths;
	CustomVector<TextureRef> m_distortionImages;

	CustomVector<std::unique_ptr<char16_t[]>> m_WavePaths;
	CustomVector<SoundDataRef> m_pWaves;

	CustomVector<std::unique_ptr<char16_t[]>> modelPaths_;
	CustomVector<ModelRef> models_;

	CustomVector<ModelRef> proceduralModels_;
	CustomVector<ProceduralModelParameter> proceduralModelParameters_;

	CustomVector<std::unique_ptr<char16_t[]>> materialPaths_;
	CustomVector<MaterialRef> materials_;

	CustomVector<std::unique_ptr<char16_t[]>> curvePaths_;
	CustomVector<CurveRef> curves_;

	std::u16string name_;
	std::u16string materialPath_;

	//! dynamic inputs
	std::array<float, 4> defaultDynamicInputs;

	//! dynamic parameters
	std::vector<InternalScript> dynamicEquation;

	int32_t renderingNodesCount = 0;
	int32_t renderingNodesThreshold = 0;

	//! scaling of this effect
	float m_maginification = 1.0f;

	float m_maginificationExternal = 1.0f;

	// default random seed
	int32_t m_defaultRandomSeed;

	//! child root node
	EffectNode* m_pRoot = nullptr;

	// culling
	struct
	{
		CullingShape Shape;
		Vector3D Location;

		union
		{
			struct
			{
			} None;

			struct
			{
				float Radius;
			} Sphere;
		};

	} Culling;

	//! a flag to reload
	bool isReloadingOnRenderingThread = false;

	//! backup to reload on rendering thread
	std::unique_ptr<EffectReloadingBackup> reloadingBackup;

	ReferenceObject* loadingObject = nullptr;

	bool LoadBody(const uint8_t* data, int32_t size, float mag);

	void ResetReloadingBackup();

public:
	static EffectRef Create(const ManagerRef& pManager, const void* pData, int size, float magnification, const char16_t* materialPath = nullptr);

	static EffectRef Create(const SettingRef& setting, const void* pData, int size, float magnification, const char16_t* materialPath = nullptr);

	EffectImplemented(const ManagerRef& pManager, const void* pData, int size);

	EffectImplemented(const SettingRef& setting, const void* pData, int size);

	virtual ~EffectImplemented();

	EffectNode* GetRoot() const override;

	float GetMaginification() const override;

	bool Load(const void* pData, int size, float mag, const char16_t* materialPath, ReloadingThreadType reloadingThreadType);

	/**
		@breif	何も読み込まれていない状態に戻す
	*/
	void Reset();

	/**
		@brief	Compatibility for magnification.
	*/
	bool IsDyanamicMagnificationValid() const;

	ReferenceObject* GetLoadingParameter() const override;

	void SetLoadingParameter(ReferenceObject* obj);

	std::vector<InternalScript>& GetDynamicEquation()
	{
		return dynamicEquation;
	}

public:
	const char16_t* GetName() const override;

	void SetName(const char16_t* name) override;

	const SettingRef& GetSetting() const override;

	int GetVersion() const override;

	TextureRef GetColorImage(int n) const override;

	int32_t GetColorImageCount() const override;

	const char16_t* GetColorImagePath(int n) const override;

	TextureRef GetNormalImage(int n) const override;

	int32_t GetNormalImageCount() const override;

	const char16_t* GetNormalImagePath(int n) const override;

	TextureRef GetDistortionImage(int n) const override;

	int32_t GetDistortionImageCount() const override;

	const char16_t* GetDistortionImagePath(int n) const override;

	SoundDataRef GetWave(int n) const override;

	int32_t GetWaveCount() const override;

	const char16_t* GetWavePath(int n) const override;

	ModelRef GetModel(int n) const override;

	int32_t GetModelCount() const override;

	const char16_t* GetModelPath(int n) const override;

	MaterialRef GetMaterial(int n) const override;

	int32_t GetMaterialCount() const override;

	const char16_t* GetMaterialPath(int n) const override;

	CurveRef GetCurve(int n) const override;

	int32_t GetCurveCount() const override;

	const char16_t* GetCurvePath(int n) const override;

	ModelRef GetProceduralModel(int n) const override;

	int32_t GetProceduralModelCount() const override;

	const ProceduralModelParameter* GetProceduralModelParameter(int n) const override;

	void SetTexture(int32_t index, TextureType type, TextureRef data) override;

	void SetSound(int32_t index, SoundDataRef data) override;

	void SetModel(int32_t index, ModelRef data) override;

	void SetMaterial(int32_t index, MaterialRef data) override;

	void SetCurve(int32_t index, CurveRef data) override;

	void SetProceduralModel(int32_t index, ModelRef data) override;

	bool Reload(ManagerRef* managers,
				int32_t managersCount,
				const void* data,
				int32_t size,
				const char16_t* materialPath,
				ReloadingThreadType reloadingThreadType) override;

	bool Reload(ManagerRef* managers,
				int32_t managersCount,
				const char16_t* path,
				const char16_t* materialPath,
				ReloadingThreadType reloadingThreadType) override;

	void ReloadResources(const void* data, int32_t size, const char16_t* materialPath) override;

	void UnloadResources(const char16_t* materialPath);

	void UnloadResources() override;

	EffectTerm CalculateTerm() const override;

	virtual int GetRef() override
	{
		return ReferenceObject::GetRef();
	}
	virtual int AddRef() override
	{
		return ReferenceObject::AddRef();
	}
	virtual int Release() override
	{
		return ReferenceObject::Release();
	}

	EffectImplemented* GetImplemented() override
	{
		return this;
	}
	const EffectImplemented* GetImplemented() const override
	{
		return this;
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_EFFECT_IMPLEMENTED_H__
