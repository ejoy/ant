
#pragma once

#include "Culling3D.Grid.h"
#include "Culling3D.h"

#include <vector>

namespace Culling3D
{
class Layer
{
private:
	int32_t gridXCount;
	int32_t gridYCount;
	int32_t gridZCount;

	float offsetX;
	float offsetY;
	float offsetZ;

	float gridSize;
	std::vector<Grid> grids;

public:
	Layer(int32_t gridXCount, int32_t gridYCount, int32_t gridZCount, float offsetX, float offsetY, float offsetZ, float gridSize);
	virtual ~Layer();

	bool AddObject(Object* o);

	bool RemoveObject(Object* o);

	void AddGrids(Vector3DF max_, Vector3DF min_, std::vector<Grid*>& grids_);

	int32_t GetGridXCount()
	{
		return gridXCount;
	}
	int32_t GetGridYCount()
	{
		return gridYCount;
	}
	int32_t GetGridZCount()
	{
		return gridZCount;
	}

	float GetOffsetX()
	{
		return offsetX;
	}
	float GetOffsetY()
	{
		return offsetY;
	}
	float GetOffsetZ()
	{
		return offsetZ;
	}

	float GetGridSize()
	{
		return gridSize;
	}
	std::vector<Grid>& GetGrids()
	{
		return grids;
	}
};
} // namespace Culling3D