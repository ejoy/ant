
#ifndef __EFFEKSEER_INSTANCECHUNK_H__
#define __EFFEKSEER_INSTANCECHUNK_H__

#include "Effekseer.Base.h"
#include "Effekseer.Instance.h"
#include <array>

namespace Effekseer
{

/**
	@brief	a group of allocated instances
	@note
	instances are allocated as a group because of memory optimization
*/
class alignas(32) InstanceChunk
{
public:
	static const int32_t InstancesOfChunk = 16;

	InstanceChunk();

	~InstanceChunk();

	void UpdateInstances();

	void GenerateChildrenInRequired();

	void UpdateInstancesByInstanceGlobal(const InstanceGlobal* global);

	void GenerateChildrenInRequiredByInstanceGlobal(const InstanceGlobal* global);

	Instance* CreateInstance(ManagerImplemented* pManager, EffectNodeImplemented* pEffectNode, InstanceContainer* pContainer, InstanceGroup* pGroup);

	int32_t GetAliveCount() const
	{
		return aliveCount_;
	}

	bool IsInstanceCreatable() const
	{
		return aliveCount_ < InstancesOfChunk;
	}

private:
	std::array<uint8_t[sizeof(Instance)], InstancesOfChunk> instances_;

	//! flags whether are instances alive
	std::array<bool, InstancesOfChunk> instancesAlive_;

	//! the number of living instances
	int32_t aliveCount_ = 0;
};

} // namespace Effekseer

#endif // __EFFEKSEER_INSTANCECHUNK_H__
