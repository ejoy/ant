#ifndef BULLET2_COLLISION_SDK_H
#define BULLET2_COLLISION_SDK_H

#include "CollisionSdkInterface.h"

class Bullet2CollisionSdk : public CollisionSdkInterface
{
	struct Bullet2CollisionSdkInternalData* m_internalData;

public:
	Bullet2CollisionSdk();
	virtual ~Bullet2CollisionSdk();
	// use create/delete when application start and close.
	virtual plCollisionWorldHandle createCollisionWorld(int maxNumObjsCapacity, int maxNumShapesCapacity, int maxNumPairsCapacity);
	virtual void deleteCollisionWorld(plCollisionWorldHandle worldHandle);
		void _deleteCollisionWorldObjects(plCollisionWorldHandle worldHandle);

	// clean world's objects and reuse ,when user change levelmap 
	// or user remove entity from world,and reuse it 
	virtual void resetCollisionWorld(plCollisionWorldHandle worldHandle);

	//{@	shape
	virtual plCollisionShapeHandle createBoxShape(plCollisionWorldHandle world,plVector3 size);
	virtual plCollisionShapeHandle createSphereShape(plCollisionWorldHandle worldHandle, plReal radius);

	virtual plCollisionShapeHandle createPlaneShape(plCollisionWorldHandle worldHandle,
													plReal planeNormalX,
													plReal planeNormalY,
													plReal planeNormalZ,
													plReal planeConstant);

	virtual plCollisionShapeHandle createCapsuleShape(plCollisionWorldHandle worldHandle,
													plReal radius,
													plReal height,
													int capsuleAxis);

	virtual plCollisionShapeHandle createCylinderShape(plCollisionWorldHandle worldHandle,
													plReal radius,plReal height,int upAxis);


	virtual plCollisionShapeHandle createTerrainShape(plCollisionWorldHandle worldHandle,
		int width, int height,
		const void *heightData, int phyDataType,		
		plReal heightScale, plReal minHeight, plReal maxHeight,
		int upAxis,	bool filpQuadEdges);

	virtual plCollisionShapeHandle createCompoundShape(plCollisionWorldHandle worldHandle);
	virtual plCollisionShapeHandle getCompoundChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, int childidx);

	virtual void addChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, plCollisionShapeHandle childShape, plVector3 childPos, plQuaternion childOrn);
	// add for setposition dynamic change
	virtual void setShapeScale(plCollisionWorldHandle worldHandle, plCollisionObjectHandle objectHandle,plCollisionShapeHandle shapeHandle,plVector3 scale);
	virtual void setShapeScaleEx(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shapeHandle, plVector3 scale);

	virtual void deleteShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shape);
	//@}

	//{@	collision object

	//{{@	lifecycle	
	virtual void addCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object);
	virtual void removeCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object);

	virtual plCollisionObjectHandle createCollisionObject(plCollisionWorldHandle worldHandle, void* userPointer, int userIndex, plCollisionShapeHandle cshape,
														  plVector3 startPosition, plQuaternion startOrientation);
	virtual void deleteCollisionObject(plCollisionWorldHandle worldHandle,plCollisionObjectHandle bodyHandle);

	virtual plCollisionShapeHandle getCollisionObjectShape(plCollisionWorldHandle worldHandle, plCollisionObjectHandle object);
	//@}}

	//{{@	transform
	virtual void setCollisionObjectTransform(plCollisionWorldHandle world, plCollisionObjectHandle body,
		plVector3 position, plQuaternion orientation);
	//addition protocol for simplie use transform 
	virtual void setCollisionObjectPosition(plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
		plVector3 position);
	virtual void setCollisionObjectRotation(plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
		plQuaternion orientation);

	//@}}
	//@}

	//{@	scene query
	
	virtual int collide(plCollisionWorldHandle world, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
						lwContactPoint* pointsOut, int pointCapacity);
	//add raycast 
	virtual bool raycast(plCollisionWorldHandle worldHandle, plVector3 rayFrom, plVector3 rayTo,
		ClosestRayResult &result);

	virtual void collideWorld(plCollisionWorldHandle world,
		plNearCallback filter, void* userData);
	//@}


	//{@	debug relate	
	virtual void createDebugDrawer(plCollisionWorldHandle world);
	virtual void deleteDebugDrawer(plCollisionWorldHandle world);

	virtual void drawline( plCollisionWorldHandle worldHandle, plVector3 rayFrom,plVector3 rayTo,unsigned int color);
	//@} 


	//static function
public:
	static plCollisionSdkHandle createBullet2SdkHandle();
};

#endif  //BULLET2_COLLISION_SDK_H
