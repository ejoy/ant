#include "CollisionSdkC_Api.h"
#include "Internal/CollisionSdkInterface.h"
#include "Internal/Bullet2CollisionSdk.h"
#include "Internal/RealTimeBullet3CollisionSdk.h"

#define DISABLE_REAL_TIME_BULLET3_COLLISION_SDK
/* Collision World */

plCollisionWorldHandle plCreateCollisionWorld(plCollisionSdkHandle collisionSdkHandle, int maxNumObjsCapacity, int maxNumShapesCapacity, int maxNumPairsCapacity)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCollisionWorld(maxNumObjsCapacity, maxNumShapesCapacity, maxNumPairsCapacity);
}

void plDeleteCollisionWorld(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	if (sdk && worldHandle)
	{
		sdk->deleteCollisionWorld(worldHandle);
	}
}

plCollisionSdkHandle plCreateBullet2CollisionSdk()
{
#ifndef DISABLE_BULLET2_COLLISION_SDK
	return Bullet2CollisionSdk::createBullet2SdkHandle();
#else
	return 0;
#endif  //DISABLE_BULLET2_COLLISION_SDK
}

plCollisionSdkHandle plCreateRealTimeBullet3CollisionSdk()
{
#ifndef DISABLE_REAL_TIME_BULLET3_COLLISION_SDK
	return RealTimeBullet3CollisionSdk::createRealTimeBullet3CollisionSdkHandle();
#else
	return 0;
#endif
}

void plDeleteCollisionSdk(plCollisionSdkHandle collisionSdkHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	delete sdk;
}

plCollisionShapeHandle plCreateCubeShape(plCollisionSdkHandle sdkHandle,plCollisionWorldHandle world,plVector3 size)
{
	CollisionSdkInterface *sdk = (CollisionSdkInterface*) sdkHandle;
	return sdk->createCubeShape(world,size);
}

plCollisionShapeHandle plCreateSphereShape(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plReal radius)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createSphereShape(worldHandle, radius);
}

plCollisionShapeHandle plCreatePlaneShape( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle,
										  plReal planeNormalX,
										  plReal planeNormalY,
										  plReal planeNormalZ,
										  plReal planeConstant)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createPlaneShape(worldHandle, planeNormalX, planeNormalY, planeNormalZ, planeConstant);
}

// phyDataType = 0:float,3:unshort,5:uchar 
plCollisionShapeHandle plCreateTerrainShape( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle,
													int width,int height, const void *heightData, plReal gridSize,
													plReal heightScale, plReal minHeight, plReal maxHeight, int upAxis,
													int phyDataType,
													bool filpQuadEdges)
{
	// do data convert! need more setting 
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createTerrainShape(worldHandle,width,height,heightData, gridSize, heightScale, minHeight,maxHeight,upAxis,
													phyDataType, filpQuadEdges ); 
}

plCollisionShapeHandle plCreateCapsuleShape( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plReal radius, plReal height, int capsuleAxis)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCapsuleShape(worldHandle, radius, height, capsuleAxis);
}

plCollisionShapeHandle plCreateCylinderShape( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plReal radius, plReal height, int upAxis )
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCylinderShape(worldHandle, radius ,height,upAxis);
}

plCollisionShapeHandle plCreateCompoundShape(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCompoundShape(worldHandle);
}
void plAddChildShape(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, plCollisionShapeHandle childShape, plVector3 childPos, plQuaternion childOrn)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->addChildShape(worldHandle, compoundShape, childShape, childPos, childOrn);
}

void plDeleteShape(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionShapeHandle shapeHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->deleteShape(worldHandle, shapeHandle);
}



plCollisionObjectHandle plCreateCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, void* userData, int userIndex, plCollisionShapeHandle cshape, plVector3 childPos, plQuaternion childOrn)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCollisionObject(worldHandle, userData, userIndex, cshape, childPos, childOrn);
}

void plDeleteCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle body)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->deleteCollisionObject(body);
}

void plSetCollisionObjectTransform(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle, plVector3 position, plQuaternion orientation)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->setCollisionObjectTransform(worldHandle, objHandle, position, orientation);
}
// addition protocol : use transform simply
void plSetCollisionObjectPosition( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle, plVector3 position)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->setCollisionObjectPosition(worldHandle, objHandle, position );
}
void plSetCollisionObjectRotation( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle, plQuaternion orientation)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->setCollisionObjectRotation( worldHandle, objHandle, orientation );
}

// user friendly interface
void plSetCollisionObjectRotationEuler( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												   plReal yaw, plReal pitch, plReal roll)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->setCollisionObjectRotationEuler( worldHandle, objHandle, yaw,pitch, roll );
}
																								 
void plSetCollisionObjectRotationAxisAngle( plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												   plVector3 axis,plReal angle )
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*) collisionSdkHandle;
	sdk->setCollisionObjectRotationAxisAngle( worldHandle, objHandle, axis, angle );
}												   

void plAddCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle world, plCollisionObjectHandle object)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->addCollisionObject(world, object);
}
void plRemoveCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle world, plCollisionObjectHandle object)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->removeCollisionObject(world, object);
}



/* Collision Queries */
int plCollide(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
			  lwContactPoint* pointsOut, int pointCapacity)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->collide(worldHandle, colA, colB, pointsOut, pointCapacity);
}

void plWorldCollide(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle world,
					plNearCallback filter, void* userData)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->collideWorld(world, filter, userData);
}

// add raycast 
bool plRaycast( plCollisionSdkHandle SdkHandle, plCollisionWorldHandle world, plVector3 rayFrom,plVector3 rayTo, ClosestRayResult &result)
{
	CollisionSdkInterface *sdk = (CollisionSdkInterface*) SdkHandle;
	return sdk->raycast(world,rayFrom,rayTo,result );
}

