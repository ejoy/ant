
#include "Culling3D.ReferenceObject.h"

namespace Culling3D
{
ReferenceObject::ReferenceObject()
	: m_reference(1)
{
}

ReferenceObject::~ReferenceObject()
{
}

int32_t ReferenceObject::AddRef()
{
	m_reference++;
	return m_reference;
}

int32_t ReferenceObject::GetRef()
{
	return m_reference;
}

int32_t ReferenceObject::Release()
{
	assert(m_reference > 0);

	m_reference--;
	bool destroy = m_reference == 0;
	if (destroy)
	{
		delete this;
		return 0;
	}

	return m_reference;
}
} // namespace Culling3D