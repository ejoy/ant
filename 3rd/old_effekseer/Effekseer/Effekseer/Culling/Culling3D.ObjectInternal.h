
#pragma once

#include "Culling3D.ReferenceObject.h"
#include "Culling3D.h"

namespace Culling3D
{
class ObjectInternal : public Object, public ReferenceObject
{
public:
	struct Status
	{
		Vector3DF Position;

		union
		{
			struct
			{
				float Radius;
			} Sphere;

			struct
			{
				float X;
				float Y;
				float Z;
			} Cuboid;
		} Data;

		float radius;
		eObjectShapeType Type;

		void CalcRadius()
		{
			radius = 0.0f;
			if (Type == OBJECT_SHAPE_TYPE_NONE)
				radius = 0.0f;
			if (Type == OBJECT_SHAPE_TYPE_SPHERE)
				radius = Data.Sphere.Radius;
			if (Type == OBJECT_SHAPE_TYPE_CUBOID)
				radius = sqrtf(Data.Cuboid.X * Data.Cuboid.X + Data.Cuboid.Y * Data.Cuboid.Y + Data.Cuboid.Z * Data.Cuboid.Z) / 2.0f;
		}

		float GetRadius()
		{
			return radius;
		}
	};

private:
	void* userData;
	World* world;

	Status currentStatus;
	Status nextStatus;

public:
	ObjectInternal();
	virtual ~ObjectInternal();

	Vector3DF GetPosition() override;
	void SetPosition(Vector3DF pos) override;

	void ChangeIntoAll() override;

	void ChangeIntoSphere(float radius) override;

	void ChangeIntoCuboid(Vector3DF size) override;

	void* GetUserData() override;
	void SetUserData(void* userData_) override;

	void SetWorld(World* world_);

	Status GetCurrentStatus()
	{
		return currentStatus;
	}
	Status GetNextStatus()
	{
		return nextStatus;
	}

	int32_t ObjectIndex;

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
