
#pragma once

#include "Culling3D.h"

namespace Culling3D
{
class ReferenceObject : public IReference
{
private:
	int32_t m_reference;

public:
	ReferenceObject();

	virtual ~ReferenceObject();

	virtual int32_t AddRef();

	virtual int32_t GetRef();

	virtual int32_t Release();
};
} // namespace Culling3D
