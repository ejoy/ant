
#pragma once

#include "Culling3D.h"

#include <vector>

namespace Culling3D
{
class Grid
{
private:
	std::vector<Object*> objects;

public:
	Grid();

	void AddObject(Object* o);

	void RemoveObject(Object* o);

	std::vector<Object*>& GetObjects()
	{
		return objects;
	}

	bool IsScanned;
};
} // namespace Culling3D