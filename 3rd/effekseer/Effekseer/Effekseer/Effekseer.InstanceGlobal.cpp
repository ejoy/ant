

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.InstanceGlobal.h"
#include "Utils/Effekseer.CustomAllocator.h"
#include <assert.h>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

void* InstanceGlobal::operator new(size_t size)
{
	assert(sizeof(InstanceGlobal) == size);
	return GetMallocFunc()(static_cast<uint32_t>(size));
}

void InstanceGlobal::operator delete(void* p)
{
	GetFreeFunc()(p, sizeof(InstanceGlobal));
}

InstanceGlobal::InstanceGlobal()
	: m_instanceCount(0)
	, m_updatedFrame(0)
	, m_rootContainer(nullptr)
{
	dynamicInputParameters.fill(0);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
InstanceGlobal::~InstanceGlobal()
{
}

float InstanceGlobal::GetNextDeltaFrame() const
{
	return nextDeltaFrame_;
}

void InstanceGlobal::BeginDeltaFrame(float frame)
{
	nextDeltaFrame_ = frame;
}

void InstanceGlobal::EndDeltaFrame()
{
	m_updatedFrame += nextDeltaFrame_;
	nextDeltaFrame_ = 0.0f;
}

std::array<float, 4> InstanceGlobal::GetDynamicEquationResult(int32_t index)
{
	assert(0 <= index && index < dynamicEqResults.size());
	return dynamicEqResults[index];
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGlobal::IncInstanceCount()
{
	m_instanceCount++;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGlobal::DecInstanceCount()
{
	m_instanceCount--;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
int InstanceGlobal::GetInstanceCount()
{
	return m_instanceCount;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
float InstanceGlobal::GetUpdatedFrame()
{
	return m_updatedFrame;
}

void InstanceGlobal::ResetUpdatedFrame()
{
	m_updatedFrame = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
InstanceContainer* InstanceGlobal::GetRootContainer() const
{
	return m_rootContainer;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGlobal::SetRootContainer(InstanceContainer* container)
{
	m_rootContainer = container;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
const SIMD::Vec3f& InstanceGlobal::GetTargetLocation() const
{
	return m_targetLocation;
}

void InstanceGlobal::SetTargetLocation(const Vector3D& location)
{
	m_targetLocation = location;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------