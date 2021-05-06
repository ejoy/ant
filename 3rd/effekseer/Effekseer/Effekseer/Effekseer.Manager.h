
#ifndef __EFFEKSEER_MANAGER_H__
#define __EFFEKSEER_MANAGER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Vector3D.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

/**
	@brief エフェクト管理クラス
*/
class Manager : public IReference
{
public:
	/**
		@brief
		\~English Parameters when a manager is updated
		\~Japanese マネージャーが更新されるときのパラメーター
	*/
	struct UpdateParameter
	{
		/**
			@brief
			\~English A passing frame
			\~Japanese 経過するフレーム
		*/
		float DeltaFrame = 1.0f;

		/**
			@brief
			\~English An update interval
			\~Japanese 更新間隔
			@note
			\~English For example, DeltaTime is 2 and UpdateInterval is 1, an effect is update twice
			\~Japanese 例えば、DeltaTimeが2でUpdateIntervalが1の場合、エフェクトは2回更新される。
		*/
		float UpdateInterval = 1.0f;

		/**
			@brief
			\~English Perform synchronous update
			\~Japanese 同期更新を行う
			@note
			\~English If true, update processing is performed synchronously. If false, update processing is performed asynchronously (after this, do not call anything other than Draw)
			\~Japanese trueなら同期的に更新処理を行う。falseなら非同期的に更新処理を行う（次はDraw以外呼び出してはいけない）
		*/
		bool SyncUpdate = true;
	};

	/**
	@brief
		@brief
		\~English Parameters for Manager::Draw and Manager::DrawHandle
		\~Japanese Manager::Draw and Manager::DrawHandleに使用するパラメーター
	*/
	struct DrawParameter
	{
		Vector3D CameraPosition;

		/**
			@brief
			\~English A direction of camera
			\~Japanese カメラの方向
			@note
			\~English It means that the direction is normalize(focus - position)
			\~Japanese normalize(focus-position)を意味する。
		*/
		Vector3D CameraFrontDirection;

		/**
			@brief
			\~English A bitmask to show effects
			\~Japanese エフェクトを表示するためのビットマスク
			@note
			\~English For example, if effect's layer is 1 and CameraCullingMask's first bit is 1, this effect is shown.
			\~Japanese 例えば、エフェクトのレイヤーが0でカリングマスクの最初のビットが1のときエフェクトは表示される。
		*/
		int32_t CameraCullingMask;

		/**
			@brief
			\~English Whether effects should be sorted by camera position and direction
			\~Japanese エフェクトをカメラの位置と方向でソートするかどうか
		*/
		bool IsSortingEffectsEnabled = false;

		DrawParameter();
	};

protected:
	Manager()
	{
	}
	virtual ~Manager()
	{
	}

public:
	/**
		@brief マネージャーを生成する。
		@param	instance_max	[in]	最大インスタンス数
		@param	autoFlip		[in]	自動でスレッド間のデータを入れ替えるかどうか、を指定する。trueの場合、Update時に入れ替わる。
		@return	マネージャー
	*/
	static ManagerRef Create(int instance_max, bool autoFlip = true);

	/**
		@brief
		\~English Starts a specified number of worker threads
		\~Japanese 指定した数のワーカースレッドを起動する
	*/
	virtual void LaunchWorkerThreads(uint32_t threadCount) = 0;

	/**
		@brief
		\~English Get a thread handle (HANDLE(win32), pthread_t(posix) or etc.)
		\~Japanese スレッドハンドルを取得する。(HANDLE(win32) や pthread_t(posix) など)
	*/
	virtual ThreadNativeHandleType GetWorkerThreadHandle(uint32_t threadID) = 0;

	/**
		@brief
		\~English get an allocator
		\~Japanese メモリ確保関数を取得する。
	*/
	virtual MallocFunc GetMallocFunc() const = 0;

	/**
		\~English specify an allocator
		\~Japanese メモリ確保関数を設定する。
	*/
	virtual void SetMallocFunc(MallocFunc func) = 0;

	/**
		@brief
		\~English get a deallocator
		\~Japanese メモリ破棄関数を取得する。
	*/
	virtual FreeFunc GetFreeFunc() const = 0;

	/**
		\~English specify a deallocator
		\~Japanese メモリ破棄関数を設定する。
	*/
	virtual void SetFreeFunc(FreeFunc func) = 0;

	/**
		@brief	ランダム関数を取得する。
	*/
	virtual RandFunc GetRandFunc() const = 0;

	/**
		@brief	ランダム関数を設定する。
	*/
	virtual void SetRandFunc(RandFunc func) = 0;

	/**
		@brief	ランダム最大値を取得する。
	*/
	virtual int GetRandMax() const = 0;

	/**
		@brief	ランダム関数を設定する。
	*/
	virtual void SetRandMax(int max_) = 0;

	/**
		@brief	座標系を取得する。
		@return	座標系
	*/
	virtual CoordinateSystem GetCoordinateSystem() const = 0;

	/**
		@brief	座標系を設定する。
		@param	coordinateSystem	[in]	座標系
		@note
		座標系を設定する。
		エフェクトファイルを読み込む前に設定する必要がある。
	*/
	virtual void SetCoordinateSystem(CoordinateSystem coordinateSystem) = 0;

	/**
		@brief	スプライト描画機能を取得する。
	*/
	virtual SpriteRendererRef GetSpriteRenderer() = 0;

	/**
		@brief	スプライト描画機能を設定する。
	*/
	virtual void SetSpriteRenderer(SpriteRendererRef renderer) = 0;

	/**
		@brief	ストライプ描画機能を取得する。
	*/
	virtual RibbonRendererRef GetRibbonRenderer() = 0;

	/**
		@brief	ストライプ描画機能を設定する。
	*/
	virtual void SetRibbonRenderer(RibbonRendererRef renderer) = 0;

	/**
		@brief	リング描画機能を取得する。
	*/
	virtual RingRendererRef GetRingRenderer() = 0;

	/**
		@brief	リング描画機能を設定する。
	*/
	virtual void SetRingRenderer(RingRendererRef renderer) = 0;

	/**
		@brief	モデル描画機能を取得する。
	*/
	virtual ModelRendererRef GetModelRenderer() = 0;

	/**
		@brief	モデル描画機能を設定する。
	*/
	virtual void SetModelRenderer(ModelRendererRef renderer) = 0;

	/**
		@brief	軌跡描画機能を取得する。
	*/
	virtual TrackRendererRef GetTrackRenderer() = 0;

	/**
		@brief	軌跡描画機能を設定する。
	*/
	virtual void SetTrackRenderer(TrackRendererRef renderer) = 0;

	/**
		@brief	設定クラスを取得する。
	*/
	virtual const SettingRef& GetSetting() const = 0;

	/**
		@brief	設定クラスを設定する。
		@param	setting	[in]	設定
	*/
	virtual void SetSetting(const SettingRef& setting) = 0;

	/**
		@brief	エフェクト読込クラスを取得する。
	*/
	virtual EffectLoaderRef GetEffectLoader() = 0;

	/**
		@brief	エフェクト読込クラスを設定する。
	*/
	virtual void SetEffectLoader(EffectLoaderRef effectLoader) = 0;

	/**
		@brief	テクスチャ読込クラスを取得する。
	*/
	virtual TextureLoaderRef GetTextureLoader() = 0;

	/**
		@brief	テクスチャ読込クラスを設定する。
	*/
	virtual void SetTextureLoader(TextureLoaderRef textureLoader) = 0;

	/**
		@brief	サウンド再生機能を取得する。
	*/
	virtual SoundPlayerRef GetSoundPlayer() = 0;

	/**
		@brief	サウンド再生機能を設定する。
	*/
	virtual void SetSoundPlayer(SoundPlayerRef soundPlayer) = 0;

	/**
		@brief	サウンド読込クラスを取得する
	*/
	virtual SoundLoaderRef GetSoundLoader() = 0;

	/**
		@brief	サウンド読込クラスを設定する。
	*/
	virtual void SetSoundLoader(SoundLoaderRef soundLoader) = 0;

	/**
		@brief	モデル読込クラスを取得する。
	*/
	virtual ModelLoaderRef GetModelLoader() = 0;

	/**
		@brief	モデル読込クラスを設定する。
	*/
	virtual void SetModelLoader(ModelLoaderRef modelLoader) = 0;

	/**
		@brief
		\~English get a material loader
		\~Japanese マテリアルローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	virtual MaterialLoaderRef GetMaterialLoader() = 0;

	/**
		@brief
		\~English specfiy a material loader
		\~Japanese マテリアルローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	virtual void SetMaterialLoader(MaterialLoaderRef loader) = 0;

	/**
		@brief
		\~English get a curve loader
		\~Japanese カーブローダーを取得する。
		@return
		\~English	loader
		\~Japanese ローダー
	*/
	virtual CurveLoaderRef GetCurveLoader() = 0;

	/**
		@brief
		\~English specfiy a curve loader
		\~Japanese カーブローダーを設定する。
		@param	loader
		\~English	loader
		\~Japanese ローダー
	*/
	virtual void SetCurveLoader(CurveLoaderRef loader) = 0;

	/**
		@brief	エフェクトを停止する。
		@param	handle	[in]	インスタンスのハンドル
	*/
	virtual void StopEffect(Handle handle) = 0;

	/**
		@brief	全てのエフェクトを停止する。
	*/
	virtual void StopAllEffects() = 0;

	/**
		@brief	エフェクトのルートだけを停止する。
		@param	handle	[in]	インスタンスのハンドル
	*/
	virtual void StopRoot(Handle handle) = 0;

	/**
		@brief	エフェクトのルートだけを停止する。
		@param	effect	[in]	エフェクト
	*/
	virtual void StopRoot(const EffectRef& effect) = 0;

	/**
		@brief	エフェクトのインスタンスが存在しているか取得する。
		@param	handle	[in]	インスタンスのハンドル
		@return	存在してるか?
	*/
	virtual bool Exists(Handle handle) = 0;

	/**
		@brief	エフェクトに使用されているインスタンス数を取得する。
		@param	handle	[in]	インスタンスのハンドル
		@return	インスタンス数
		@note
		Rootも個数に含まれる。つまり、Root削除をしていない限り、
		Managerに残っているインスタンス数+エフェクトに使用されているインスタンス数は存在しているRootの数だけ
		最初に確保した個数よりも多く存在する。
	*/
	virtual int32_t GetInstanceCount(Handle handle) = 0;

	/**
		@brief
		\~English Get the number of instances which is used in playing effects
		\~Japanese 全てのエフェクトに使用されているインスタンス数を取得する。
		@return
		\~English The number of instances
		\~Japanese インスタンス数
		@note
		\~English
		The number of Root is included.
		This means that the number of used instances added resting resting instances is larger than the number of allocated onces by the
	   number of root.
		\~Japanese
		Rootも個数に含まれる。つまり、Root削除をしていない限り、
		Managerに残っているインスタンス数+エフェクトに使用されているインスタンス数は、最初に確保した個数よりも存在しているRootの数の分だけ多く存在する。
	*/
	virtual int32_t GetTotalInstanceCount() const = 0;

	/**
		@brief	エフェクトのインスタンスに設定されている行列を取得する。
		@param	handle	[in]	インスタンスのハンドル
		@return	行列
	*/
	virtual Matrix43 GetMatrix(Handle handle) = 0;

	/**
		@brief	エフェクトのインスタンスに変換行列を設定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	mat		[in]	変換行列
	*/
	virtual void SetMatrix(Handle handle, const Matrix43& mat) = 0;

	/**
		@brief	エフェクトのインスタンスの位置を取得する。
		@param	handle	[in]	インスタンスのハンドル
		@return	位置
	*/
	virtual Vector3D GetLocation(Handle handle) = 0;

	/**
		@brief	エフェクトのインスタンスの位置を指定する。
		@param	x	[in]	X座標
		@param	y	[in]	Y座標
		@param	z	[in]	Z座標
	*/
	virtual void SetLocation(Handle handle, float x, float y, float z) = 0;

	/**
		@brief	エフェクトのインスタンスの位置を指定する。
		@param	location	[in]	位置
	*/
	virtual void SetLocation(Handle handle, const Vector3D& location) = 0;

	/**
		@brief	エフェクトのインスタンスの位置に加算する。
		@param	location	[in]	加算する値
	*/
	virtual void AddLocation(Handle handle, const Vector3D& location) = 0;

	/**
		@brief	エフェクトのインスタンスの回転角度を指定する。(ラジアン)
	*/
	virtual void SetRotation(Handle handle, float x, float y, float z) = 0;

	/**
		@brief	エフェクトのインスタンスの任意軸周りの反時計周りの回転角度を指定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	axis	[in]	軸
		@param	angle	[in]	角度(ラジアン)
	*/
	virtual void SetRotation(Handle handle, const Vector3D& axis, float angle) = 0;

	/**
		@brief	エフェクトのインスタンスの拡大率を指定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	x		[in]	X方向拡大率
		@param	y		[in]	Y方向拡大率
		@param	z		[in]	Z方向拡大率
	*/
	virtual void SetScale(Handle handle, float x, float y, float z) = 0;

	/**
	@brief
		\~English	Specify the color of overall effect.
		\~Japanese	エフェクト全体の色を指定する。
	*/
	virtual void SetAllColor(Handle handle, Color color) = 0;

	/**
		@brief	エフェクトのインスタンスのターゲット位置を指定する。
		@param	x	[in]	X座標
		@param	y	[in]	Y座標
		@param	z	[in]	Z座標
	*/
	virtual void SetTargetLocation(Handle handle, float x, float y, float z) = 0;

	/**
		@brief	エフェクトのインスタンスのターゲット位置を指定する。
		@param	location	[in]	位置
	*/
	virtual void SetTargetLocation(Handle handle, const Vector3D& location) = 0;

	/**
		@brief
		\~English get a dynamic parameter, which changes effect parameters dynamically while playing
		\~Japanese 再生中にエフェクトのパラメーターを変更する動的パラメーターを取得する。
	*/
	virtual float GetDynamicInput(Handle handle, int32_t index) = 0;

	/**
		@brief
		\~English specfiy a dynamic parameter, which changes effect parameters dynamically while playing
		\~Japanese 再生中にエフェクトのパラメーターを変更する動的パラメーターを設定する。
	*/
	virtual void SetDynamicInput(Handle handle, int32_t index, float value) = 0;

	/**
		@brief	エフェクトのベース行列を取得する。
		@param	handle	[in]	インスタンスのハンドル
		@return	ベース行列
	*/
	virtual Matrix43 GetBaseMatrix(Handle handle) = 0;

	/**
		@brief	エフェクトのベース行列を設定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	mat		[in]	設定する行列
		@note
		エフェクト全体の表示位置を指定する行列を設定する。
	*/
	virtual void SetBaseMatrix(Handle handle, const Matrix43& mat) = 0;

	/**
		@brief	エフェクトのインスタンスに廃棄時のコールバックを設定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	callback	[in]	コールバック
	*/
	virtual void SetRemovingCallback(Handle handle, EffectInstanceRemovingCallback callback) = 0;

	/**
	@brief	\~English	Get status that a particle of effect specified is shown.
	\~Japanese	指定したエフェクトのパーティクルが表示されているか取得する。

	@param	handle	\~English	Particle's handle
	\~Japanese	パーティクルのハンドル
	*/
	virtual bool GetShown(Handle handle) = 0;

	/**
		@brief	エフェクトのインスタンスをDraw時に描画するか設定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	shown	[in]	描画するか?
	*/
	virtual void SetShown(Handle handle, bool shown) = 0;

	/**
	@brief	\~English	Get status that a particle of effect specified is paused.
	\~Japanese	指定したエフェクトのパーティクルが一時停止されているか取得する。

	@param	handle	\~English	Particle's handle
			\~Japanese	パーティクルのハンドル
	*/
	virtual bool GetPaused(Handle handle) = 0;

	/**
		@brief	\~English	Pause or resume a particle of effect specified.
		\~Japanese	指定したエフェクトのパーティクルを一時停止、もしくは再開する。

		@param	handle	[in]	インスタンスのハンドル
		@param	paused	[in]	更新するか?
	*/
	virtual void SetPaused(Handle handle, bool paused) = 0;

	/**
			@brief	\~English	Pause or resume all particle of effects.
			\~Japanese	全てのエフェクトのパーティクルを一時停止、もしくは再開する。
			@param	paused \~English	Pause or resume
			\~Japanese	一時停止、もしくは再開
	*/
	virtual void SetPausedToAllEffects(bool paused) = 0;

	/**
		@brief
		\~English	Get a layer index
		\~Japanese	レイヤーのインデックスを取得する
		@note
		\~English For example, if effect's layer is 1 and CameraCullingMask's first bit is 1, this effect is shown.
		\~Japanese 例えば、エフェクトのレイヤーが0でカリングマスクの最初のビットが1のときエフェクトは表示される。
	*/
	virtual int GetLayer(Handle handle) = 0;

	/**
		@brief
		\~English	Set a layer index
		\~Japanese	レイヤーのインデックスを設定する
	*/
	virtual void SetLayer(Handle handle, int32_t layer) = 0;

	/**
		@brief
		\~English	Get a bitmask to specify a group
		\~Japanese	グループを指定するためのビットマスクを取得する。
	*/
	virtual int64_t GetGroupMask(Handle handle) const = 0;

	/**
		@brief
		\~English	Set a bitmask to specify a group
		\~Japanese	グループを指定するためのビットマスクを設定する。
	*/
	virtual void SetGroupMask(Handle handle, int64_t groupmask) = 0;

	/**
	@brief
	\~English	Get a playing speed of particle of effect.
	\~Japanese	エフェクトのパーティクルの再生スピードを取得する。
	@param	handle
	\~English	Particle's handle
	\~Japanese	パーティクルのハンドル
	@return
	\~English	Speed
	\~Japanese	スピード
	*/
	virtual float GetSpeed(Handle handle) const = 0;

	/**
		@brief	エフェクトのインスタンスを再生スピードを設定する。
		@param	handle	[in]	インスタンスのハンドル
		@param	speed	[in]	スピード
	*/
	virtual void SetSpeed(Handle handle, float speed) = 0;

	/**
		@brief
		\~English	Specify a rate of scale in relation to manager's time  by a group.
		\~Japanese	グループごとにマネージャーに対する時間の拡大率を設定する。
	*/
	virtual void SetTimeScaleByGroup(int64_t groupmask, float timeScale) = 0;

	/**
		@brief
		\~English	Specify a rate of scale in relation to manager's time  by a handle.
		\~Japanese	ハンドルごとにマネージャーに対する時間の拡大率を設定する。
	*/
	virtual void SetTimeScaleByHandle(Handle handle, float timeScale) = 0;

	/**
		@brief	エフェクトがDrawで描画されるか設定する。
				autoDrawがfalseの場合、DrawHandleで描画する必要がある。
		@param	autoDraw	[in]	自動描画フラグ
	*/
	virtual void SetAutoDrawing(Handle handle, bool autoDraw) = 0;

	/**
		@brief
		\~English	Specify a user pointer for custom renderer and custom sound player
		\~Japanese	ハンドルごとにカスタムレンダラーやカスタムサウンド向けにユーザーポインタを設定する。
	*/
	virtual void SetUserData(Handle handle, void* userData) = 0;

	/**
		@brief	今までのPlay等の処理をUpdate実行時に適用するようにする。
	*/
	virtual void Flip() = 0;

	/**
		@brief
		\~English	Update all effects.
		\~Japanese	全てのエフェクトの更新処理を行う。
		@param	deltaFrame
		\~English	passed time (1 is 1/60 seconds)
		\~Japanese	更新するフレーム数(60fps基準)
	*/
	virtual void Update(float deltaFrame = 1.0f) = 0;

	/**
		@brief
		\~English	Update all effects.
		\~Japanese	全てのエフェクトの更新処理を行う。
		@param	parameter
		\~English	A parameter for updating effects
		\~Japanese	エフェクトを更新するためのパラメーター
	*/
	virtual void Update(const UpdateParameter& parameter) = 0;

	/**
		@brief
		\~English	Start to update effects.
		\~Japanese	更新処理を開始する。
		@note
		\~English	It is not required if Update is called.
		\~Japanese	Updateを実行する際は、実行する必要はない。
	*/
	virtual void BeginUpdate() = 0;

	/**
		@brief
		\~English	Stop to update effects.
		\~Japanese	更新処理を終了する。
		@note
		\~English	It is not required if Update is called.
		\~Japanese	Updateを実行する際は、実行する必要はない。
	*/
	virtual void EndUpdate() = 0;

	/**
		@brief
		\~English	Update an effect by a handle.
		\~Japanese	ハンドル単位の更新を行う。
		@param	handle
		\~English	a handle.
		\~Japanese	ハンドル
		@param	deltaFrame
		\~English	passed time (1 is 1/60 seconds)
		\~Japanese	更新するフレーム数(60fps基準)
		@note
		\~English
		You need to call BeginUpdate before starting update and EndUpdate after stopping update.
		\~Japanese
		更新する前にBeginUpdate、更新し終わった後にEndUpdateを実行する必要がある。
	*/
	virtual void UpdateHandle(Handle handle, float deltaFrame = 1.0f) = 0;

	/**
		@brief	
		\~English	Update an effect to move to the specified frame
		\~Japanese	指定した時間に移動するために更新する
		\~English	a handle.
		\~Japanese	ハンドル
		@param	frame
		\~English	frame time (1 is 1/60 seconds)
		\~Japanese	フレーム時間(60fps基準)
		@note
		\~English	This function is slow.
		\~Japanese	この関数は遅い。
	*/
	virtual void UpdateHandleToMoveToFrame(Handle handle, float frame) = 0;

	/**
	@brief
	\~English	Draw particles.
	\~Japanese	描画処理を行う。
	*/
	virtual void Draw(const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
	@brief
	\~English	Draw particles in the back of priority 0.
	\~Japanese	背面の描画処理を行う。
	*/
	virtual void DrawBack(const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
	@brief
	\~English	Draw particles in the front of priority 0.
	\~Japanese	前面の描画処理を行う。
	*/
	virtual void DrawFront(const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
	@brief
	\~English	Draw particles with a handle.
	\~Japanese	ハンドル単位の描画処理を行う。
	*/
	virtual void DrawHandle(Handle handle, const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
	@brief
	\~English	Draw particles in the back of priority 0.
	\~Japanese	背面のハンドル単位の描画処理を行う。
	*/
	virtual void DrawHandleBack(Handle handle, const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
	@brief
	\~English	Draw particles in the front of priority 0.
	\~Japanese	前面のハンドル単位の描画処理を行う。
	*/
	virtual void DrawHandleFront(Handle handle, const Manager::DrawParameter& drawParameter = Manager::DrawParameter()) = 0;

	/**
		@brief	再生する。
		@param	effect	[in]	エフェクト
		@param	x	[in]	X座標
		@param	y	[in]	Y座標
		@param	z	[in]	Z座標
		@return	エフェクトのインスタンスのハンドル
	*/
	virtual Handle Play(const EffectRef& effect, float x, float y, float z) = 0;

	/**
		@brief
		\~English	Play an effect.
		\~Japanese	エフェクトを再生する。
		@param	effect
		\~English	Played effect
		\~Japanese	再生されるエフェクト
		@param	position
		\~English	Initial position
		\~Japanese	初期位置
		@param	startFrame
		\~English	A time to play from middle
		\~Japanese	途中から再生するための時間
	*/
	virtual Handle Play(const EffectRef& effect, const Vector3D& position, int32_t startFrame = 0) = 0;

	/**
		@brief
		\~English	Get a camera's culling mask to show all effects
		\~Japanese	全てのエフェクトを表示するためのカメラのカリングマスクを取得する。
	*/
	virtual int GetCameraCullingMaskToShowAllEffects() = 0;

	/**
		@brief	Update処理時間を取得。
	*/
	virtual int GetUpdateTime() const = 0;

	/**
		@brief	Draw処理時間を取得。
	*/
	virtual int GetDrawTime() const = 0;

	/**
		@brief
		\~English	Gets the number of remaining allocated instances.
		\~Japanese	残りの確保したインスタンス数を取得する。
	*/
	virtual int32_t GetRestInstancesCount() const = 0;

	/**
		@brief	エフェクトをカリングし描画負荷を減らすための空間を生成する。
		@param	xsize	X方向幅
		@param	ysize	Y方向幅
		@param	zsize	Z方向幅
		@param	layerCount	層数(大きいほどカリングの効率は上がるがメモリも大量に使用する)
	*/
	virtual void CreateCullingWorld(float xsize, float ysize, float zsize, int32_t layerCount) = 0;

	/**
		@brief	カリングを行い、カリングされたオブジェクトのみを描画するようにする。
		@param	cameraProjMat	カメラプロジェクション行列
		@param	isOpenGL		OpenGLによる描画か?
	*/
	virtual void CalcCulling(const Matrix44& cameraProjMat, bool isOpenGL) = 0;

	/**
		@brief	現在存在するエフェクトのハンドルからカリングの空間を配置しなおす。
	*/
	virtual void RessignCulling() = 0;

	/**
		@brief
		\~English	Lock rendering events
		\~Japanese	レンダリングのイベントをロックする。
		@note
		\~English	I recommend to read internal codes.
		\~Japanese	内部コードを読むことを勧めます。
	*/
	virtual void LockRendering() = 0;

	/**
		@brief
		\~English	Unlock rendering events
		\~Japanese	レンダリングのイベントをアンロックする。
		@note
		\~English	I recommend to read internal codes.
		\~Japanese	内部コードを読むことを勧めます。
	*/
	virtual void UnlockRendering() = 0;

	virtual ManagerImplemented* GetImplemented() = 0;
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_MANAGER_H__
