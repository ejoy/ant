
#ifndef __EFFEKSEER_LOADER_H__
#define __EFFEKSEER_LOADER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

class EffectFactory;
class ResourceManager;

/**
	@brief	設定クラス
	@note
	EffectLoader等、ファイル読み込みに関する設定することができる。
	Managerの代わりにエフェクト読み込み時に使用することで、Managerとは独立してEffectインスタンスを生成することができる。
*/
class Setting : public ReferenceObject
{
private:
	//! coordinate system
	CoordinateSystem m_coordinateSystem;
	EffectLoaderRef m_effectLoader;

	std::vector<RefPtr<EffectFactory>> effectFactories_;
	RefPtr<ResourceManager> resourceManager_;

protected:
	Setting();

	~Setting();

public:
	/**
		@brief	設定インスタンスを生成する。
	*/
	static SettingRef Create();

	/**
	@brief	座標系を取得する。
	@return	座標系
	*/
	CoordinateSystem GetCoordinateSystem() const;

	/**
	@brief	座標系を設定する。
	@param	coordinateSystem	[in]	座標系
	@note
	座標系を設定する。
	エフェクトファイルを読み込む前に設定する必要がある。
	*/
	void SetCoordinateSystem(CoordinateSystem coordinateSystem);

	/**
		@brief	エフェクトローダーを取得する。
		@return	エフェクトローダー
		*/
	EffectLoaderRef GetEffectLoader();

	/**
		@brief	エフェクトローダーを設定する。
		@param	loader	[in]		ローダー
		*/
	void SetEffectLoader(EffectLoaderRef loader);

	/**
		@brief
		\~English get a texture loader
		\~Japanese テクスチャローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	TextureLoaderRef GetTextureLoader() const;

	/**
		@brief
		\~English specfiy a texture loader
		\~Japanese テクスチャローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	void SetTextureLoader(TextureLoaderRef loader);

	/**
		@brief
		\~English get a model loader
		\~Japanese モデルローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	ModelLoaderRef GetModelLoader() const;

	/**
		@brief
		\~English specfiy a model loader
		\~Japanese モデルローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	void SetModelLoader(ModelLoaderRef loader);

	/**
		@brief
		\~English get a sound loader
		\~Japanese サウンドローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	SoundLoaderRef GetSoundLoader() const;

	/**
		@brief
		\~English specfiy a sound loader
		\~Japanese サウンドローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	void SetSoundLoader(SoundLoaderRef loader);

	/**
		@brief
		\~English get a material loader
		\~Japanese マテリアルローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	MaterialLoaderRef GetMaterialLoader() const;

	/**
		@brief
		\~English specfiy a material loader
		\~Japanese マテリアルローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	void SetMaterialLoader(MaterialLoaderRef loader);

	/**
		@brief
		\~English get a curve loader
		\~Japanese カーブローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	CurveLoaderRef GetCurveLoader() const;

	/**
		@brief
		\~English specfiy a curve loader
		\~Japanese カーブローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	void SetCurveLoader(CurveLoaderRef loader);

	/**
		@brief
		\~English get a mesh generator
		\~Japanese メッシュジェネレーターを取得する。
		@return
		\~English	generator
		\~Japanese ジェネレータ
	*/
	ProceduralModelGeneratorRef GetProceduralMeshGenerator() const;

	/**
		@brief
		\~English specfiy a mesh generator
		\~Japanese メッシュジェネレーターを設定する。
		@param	generator
		\~English	generator
		\~Japanese ジェネレータ
	*/
	void SetProceduralMeshGenerator(ProceduralModelGeneratorRef generator);

	/**
		@brief
		\~English	Add effect factory
		\~Japanese Effect factoryを追加する。
	*/
	void AddEffectFactory(const RefPtr<EffectFactory>& effectFactory);

	/**
		@brief
		\~English	Get effect factory
		\~Japanese Effect Factoryを取得する。
	*/
	const RefPtr<EffectFactory>& GetEffectFactory(int32_t ind) const;

	/**
		@brief
		\~English	clear effect factories
		\~Japanese 全てのEffect Factoryを削除する。
	*/
	void ClearEffectFactory();

	/**
		@brief
		\~English	Get the number of effect factory
		\~Japanese Effect Factoryの数を取得する。
	*/
	int32_t GetEffectFactoryCount() const;

	/**
		@brief
		\~English	Get resource manager
		\~Japanese Resource Managerを取得する。
	*/
	const RefPtr<ResourceManager>& GetResourceManager() const;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_LOADER_H__
