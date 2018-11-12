#ifndef BULLET2_COLLISION_SDK_H
#define BULLET2_COLLISION_SDK_H

#include "CollisionSdkInterface.h"

class Bullet2CollisionSdk : public CollisionSdkInterface
{
	struct Bullet2CollisionSdkInternalData* m_internalData;

public:
	Bullet2CollisionSdk();

	virtual ~Bullet2CollisionSdk();

	virtual plCollisionWorldHandle createCollisionWorld(int maxNumObjsCapacity, int maxNumShapesCapacity, int maxNumPairsCapacity);

	virtual void deleteCollisionWorld(plCollisionWorldHandle worldHandle);

	virtual plCollisionShapeHandle createCubeShape(plCollisionWorldHandle world,plVector3 size);
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
													int width,int height, const void *heightData,plReal gridSize,
													plReal heightScale,plReal minHeight,plReal maxHeight,int upAxis,
													int phyDataType,
													bool filpQuadEdges);													

	virtual plCollisionShapeHandle createCompoundShape(plCollisionWorldHandle worldHandle);
	virtual void addChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, plCollisionShapeHandle childShape, plVector3 childPos, plQuaternion childOrn);

	virtual void deleteShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shape);

	virtual void addCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object);
	virtual void removeCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object);

	virtual plCollisionObjectHandle createCollisionObject(plCollisionWorldHandle worldHandle, void* userPointer, int userIndex, plCollisionShapeHandle cshape,
														  plVector3 startPosition, plQuaternion startOrientation);
	virtual void deleteCollisionObject(plCollisionObjectHandle body);

	virtual void setCollisionObjectTransform(plCollisionWorldHandle world, plCollisionObjectHandle body,
											 plVector3 position, plQuaternion orientation);
	//addition protocol for simplie use transform 
	virtual void setCollisionObjectPosition( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plVector3 position );
	virtual void setCollisionObjectRotation( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plQuaternion orientation );

	// friendly function for setting quaternion
	virtual void setCollisionObjectRotationEuler( plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												plReal yaw, plReal pitch, plReal roll);
	virtual void setCollisionObjectRotationAxisAngle( plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												plVector3 axis, plReal angle);


	virtual int collide(plCollisionWorldHandle world, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
						lwContactPoint* pointsOut, int pointCapacity);

	//add raycast 
	virtual bool raycast( plCollisionWorldHandle worldHandle, plVector3 rayFrom, plVector3 rayTo,
								   ClosestRayResult &result);

	virtual void collideWorld(plCollisionWorldHandle world,
							  plNearCallback filter, void* userData);


	static plCollisionSdkHandle createBullet2SdkHandle();
};

#endif  //BULLET2_COLLISION_SDK_H
