
#include "Culling3D.Layer.h"
#include "Culling3D.ObjectInternal.h"

namespace Culling3D
{
Layer::Layer(int32_t gridXCount, int32_t gridYCount, int32_t gridZCount, float offsetX, float offsetY, float offsetZ, float gridSize)
{
	this->gridXCount = gridXCount;
	this->gridYCount = gridYCount;
	this->gridZCount = gridZCount;
	this->offsetX = offsetX;
	this->offsetY = offsetY;
	this->offsetZ = offsetZ;
	this->gridSize = gridSize;

	grids.resize(this->gridXCount * this->gridYCount * this->gridZCount);
}

Layer::~Layer()
{
}

bool Layer::AddObject(Object* o)
{
	assert(o != nullptr);

	ObjectInternal* o_ = (ObjectInternal*)o;

	float x = o_->GetNextStatus().Position.X + offsetX;
	float y = o_->GetNextStatus().Position.Y + offsetY;
	float z = o_->GetNextStatus().Position.Z + offsetZ;

	int32_t xind = (int32_t)(x / gridSize);
	int32_t yind = (int32_t)(y / gridSize);
	int32_t zind = (int32_t)(z / gridSize);

	int32_t ind = xind + yind * this->gridXCount + zind * this->gridXCount * this->gridYCount;

	if (xind < 0 || xind >= this->gridXCount || yind < 0 || yind >= this->gridYCount || zind < 0 || zind >= this->gridZCount)
		return false;

	if (ind < 0 || ind >= (int32_t)grids.size())
		return false;

	grids[ind].AddObject(o);

	return true;
}

bool Layer::RemoveObject(Object* o)
{
	assert(o != nullptr);

	ObjectInternal* o_ = (ObjectInternal*)o;

	float x = o_->GetCurrentStatus().Position.X + offsetX;
	float y = o_->GetCurrentStatus().Position.Y + offsetY;
	float z = o_->GetCurrentStatus().Position.Z + offsetZ;

	int32_t xind = (int32_t)(x / gridSize);
	int32_t yind = (int32_t)(y / gridSize);
	int32_t zind = (int32_t)(z / gridSize);

	int32_t ind = xind + yind * this->gridXCount + zind * this->gridXCount * this->gridYCount;

	if (xind < 0 || xind >= this->gridXCount || yind < 0 || yind >= this->gridYCount || zind < 0 || zind >= this->gridZCount)
		return false;

	if (ind < 0 || ind >= (int32_t)grids.size())
		return false;

	grids[ind].RemoveObject(o);

	return true;
}

void Layer::AddGrids(Vector3DF max_, Vector3DF min_, std::vector<Grid*>& grids_)
{
	int32_t maxX = (int32_t)((max_.X + offsetX) / gridSize) + 1;
	int32_t maxY = (int32_t)((max_.Y + offsetY) / gridSize) + 1;
	int32_t maxZ = (int32_t)((max_.Z + offsetZ) / gridSize) + 1;

	int32_t minX = (int32_t)((min_.X + offsetX) / gridSize) - 1;
	int32_t minY = (int32_t)((min_.Y + offsetY) / gridSize) - 1;
	int32_t minZ = (int32_t)((min_.Z + offsetZ) / gridSize) - 1;

	maxX = Clamp(maxX, gridXCount - 1, 0);
	maxY = Clamp(maxY, gridYCount - 1, 0);
	maxZ = Clamp(maxZ, gridZCount - 1, 0);

	minX = Clamp(minX, gridXCount - 1, 0);
	minY = Clamp(minY, gridYCount - 1, 0);
	minZ = Clamp(minZ, gridZCount - 1, 0);

	for (int32_t z = minZ; z <= maxZ; z++)
	{
		for (int32_t y = minY; y <= maxY; y++)
		{
			for (int32_t x = minX; x <= maxX; x++)
			{
				int32_t ind = x + y * this->gridXCount + z * this->gridXCount * this->gridYCount;

				if (!grids[ind].IsScanned)
				{
					grids_.push_back(&grids[ind]);
					grids[ind].IsScanned = true;
				}
			}
		}
	}
}
} // namespace Culling3D