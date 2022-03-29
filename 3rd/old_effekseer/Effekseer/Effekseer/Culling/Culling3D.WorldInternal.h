
#pragma once

#include "Culling3D.ReferenceObject.h"
#include "Culling3D.h"

#include "Culling3D.Grid.h"
#include "Culling3D.Layer.h"

#include <set>

namespace Culling3D
{
class WorldInternal : public World, public ReferenceObject
{
private:
	float xSize;
	float ySize;
	float zSize;

	float gridSize;
	float minGridSize;
	int32_t layerCount;

	std::vector<Layer*> layers;

	Grid outofLayers;
	Grid allLayers;

	std::vector<Object*> objs;

	std::vector<Grid*> grids;

	std::set<Object*> containedObjects;

public:
	WorldInternal(float xSize, float ySize, float zSize, int32_t layerCount);
	virtual ~WorldInternal();

	void AddObject(Object* o) override;
	void RemoveObject(Object* o) override;

	void AddObjectInternal(Object* o);
	void RemoveObjectInternal(Object* o);

	void CastRay(Vector3DF from, Vector3DF to) override;

	void Culling(const Matrix44& cameraProjMat, bool isOpenGL) override;

	bool Reassign() override;

	void Dump(const char* path, const Matrix44& cameraProjMat, bool isOpenGL) override;

	int32_t GetObjectCount() override
	{
		return (int32_t)objs.size();
	}
	Object* GetObject(int32_t index) override
	{
		return objs[index];
	}

	virtual int32_t GetRef() override
	{
		return ReferenceObject::GetRef();
	}
	virtual int32_t AddRef() override
	{
		return ReferenceObject::AddRef();
	}
	virtual int32_t Release() override
	{
		return ReferenceObject::Release();
	}
};
} // namespace Culling3D
