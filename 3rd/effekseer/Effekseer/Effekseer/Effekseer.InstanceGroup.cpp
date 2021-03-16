#include "Effekseer.InstanceGroup.h"

#include "Effekseer.ManagerImplemented.h"

#include "Effekseer.Instance.h"
#include "Effekseer.InstanceContainer.h"
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
InstanceGroup::InstanceGroup(ManagerImplemented* manager, EffectNodeImplemented* effectNode, InstanceContainer* container, InstanceGlobal* global)
	: m_manager(manager)
	, m_effectNode(effectNode)
	, m_container(container)
	, m_global(global)
	, m_time(0)
	, IsReferencedFromInstance(true)
	, NextUsedByInstance(nullptr)
	, NextUsedByContainer(nullptr)
{
	parentMatrix_ = SIMD::Mat43f::Identity;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
InstanceGroup::~InstanceGroup()
{
	RemoveForcibly();
}

void InstanceGroup::NotfyEraseInstance()
{
	m_global->DecInstanceCount();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Instance* InstanceGroup::CreateInstance()
{
	Instance* instance = nullptr;

	instance = m_manager->CreateInstance(m_effectNode, m_container, this);

	if (instance)
	{
		m_instances.push_back(instance);
		m_global->IncInstanceCount();
	}
	return instance;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Instance* InstanceGroup::GetFirst()
{
	if (m_instances.size() > 0)
	{
		return m_instances.front();
	}
	return nullptr;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
int InstanceGroup::GetInstanceCount() const
{
	return (int32_t)m_instances.size();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGroup::Update(bool shown)
{
	for (auto it = m_instances.begin(); it != m_instances.end();)
	{
		auto instance = *it;

		if (instance->m_State != INSTANCE_STATE_ACTIVE)
		{
			it = m_instances.erase(it);
			NotfyEraseInstance();
		}
		else
		{
			it++;
		}
	}

	m_time++;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGroup::SetBaseMatrix(const SIMD::Mat43f& mat)
{
	for (auto instance : m_instances)
	{
		if (instance->m_State == INSTANCE_STATE_ACTIVE)
		{
			instance->m_GlobalMatrix43 *= mat;
			assert(instance->m_GlobalMatrix43.IsValid());
		}
	}
}

void InstanceGroup::SetParentMatrix(const SIMD::Mat43f& mat)
{
	TranslationParentBindType tType = m_effectNode->CommonValues.TranslationBindType;
	BindType rType = m_effectNode->CommonValues.RotationBindType;
	BindType sType = m_effectNode->CommonValues.ScalingBindType;

	auto rootGroup = m_global->GetRootContainer()->GetFirstGroup();

	if (tType == BindType::Always && rType == BindType::Always && sType == BindType::Always)
	{
		parentMatrix_ = mat;
	}
	else if (tType == BindType::NotBind_Root && rType == BindType::NotBind_Root && sType == BindType::NotBind_Root)
	{
		parentMatrix_ = rootGroup->GetParentMatrix();
	}
	else if ((tType == BindType::WhenCreating || tType == TranslationParentBindType::WhenCreating_FollowParent) && rType == BindType::WhenCreating && sType == BindType::WhenCreating)
	{
		// don't do anything
	}
	else
	{
		SIMD::Vec3f s, t;
		SIMD::Mat43f r;
		mat.GetSRT(s, r, t);

		if (tType == BindType::Always)
		{
			parentTranslation_ = t;
		}
		else if (tType == BindType::NotBind_Root)
		{
			parentTranslation_ = rootGroup->GetParentTranslation();
		}
		else if (tType == BindType::NotBind)
		{
			parentTranslation_ = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
		}
		else if (tType == TranslationParentBindType::NotBind_FollowParent)
		{
			parentTranslation_ = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
		}

		if (rType == BindType::Always)
		{
			parentRotation_ = r;
		}
		else if (rType == BindType::NotBind_Root)
		{
			parentRotation_ = rootGroup->GetParentRotation();
		}
		else if (rType == BindType::NotBind)
		{
			parentRotation_ = SIMD::Mat43f::Identity;
		}

		if (sType == BindType::Always)
		{
			parentScale_ = s;
		}
		else if (sType == BindType::NotBind_Root)
		{
			parentScale_ = rootGroup->GetParentScale();
		}
		else if (sType == BindType::NotBind)
		{
			parentScale_ = SIMD::Vec3f(1.0f, 1.0f, 1.0f);
		}
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGroup::RemoveForcibly()
{
	KillAllInstances();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void InstanceGroup::KillAllInstances()
{
	while (!m_instances.empty())
	{
		auto instance = m_instances.front();
		m_instances.pop_front();
		NotfyEraseInstance();

		if (instance->GetState() == INSTANCE_STATE_ACTIVE)
		{
			instance->Kill();
		}
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------