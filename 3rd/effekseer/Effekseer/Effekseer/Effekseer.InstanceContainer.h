
#ifndef __EFFEKSEER_INSTANCECONTAINER_H__
#define __EFFEKSEER_INSTANCECONTAINER_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.IntrusiveList.h"
#include "SIMD/Mat43f.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

/**
	@brief
	@note

*/
class InstanceContainer : public IntrusiveList<InstanceContainer>::Node
{
	friend class ManagerImplemented;

private:
	// マネージャ
	ManagerImplemented* m_pManager;

	// パラメーター
	EffectNodeImplemented* m_pEffectNode;

	// グローバル
	InstanceGlobal* m_pGlobal;

	// 子のコンテナ
	IntrusiveList<InstanceContainer> m_Children;

	// グループの連結リストの先頭
	InstanceGroup* m_headGroups;

	// グループの連結リストの最後
	InstanceGroup* m_tailGroups;

	// コンストラクタ
	InstanceContainer(ManagerImplemented* pManager, EffectNode* pEffectNode, InstanceGlobal* pGlobal);

	// デストラクタ
	virtual ~InstanceContainer();

	// 無効なグループの破棄
	void RemoveInvalidGroups();

public:
	/**
		@brief	グループの作成
	*/
	InstanceGroup* CreateInstanceGroup();

	/**
		@brief	グループの先頭取得
	*/
	InstanceGroup* GetFirstGroup() const;

	void Update(bool recursive, bool shown);

	void SetBaseMatrix(bool recursive, const SIMD::Mat43f& mat);

	void RemoveForcibly(bool recursive);

	void Draw(bool recursive);

	void KillAllInstances(bool recursive);

	InstanceGlobal* GetRootInstance();

	void AddChild(InstanceContainer* pContainter);

	InstanceContainer* GetChild(int index);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_INSTANCECONTAINER_H__
