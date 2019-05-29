#include "CollisionSdkC_Api.h"
#include "Internal/CollisionSdkInterface.h"
#include "Internal/Bullet2CollisionSdk.h"
#include "Internal/RealTimeBullet3CollisionSdk.h"

#define DISABLE_REAL_TIME_BULLET3_COLLISION_SDK

/* Debug Drawer*/

void plCreateDebugDrawer(plCollisionSdkHandle sdkHandle,plCollisionWorldHandle worldHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)sdkHandle;
	return sdk->createDebugDrawer( worldHandle );
}
void plDeleteDebugDrawer(plCollisionSdkHandle sdkHandle,plCollisionWorldHandle worldHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)sdkHandle;
	if (sdk && worldHandle)
	{
		sdk->deleteCollisionWorld(worldHandle);
	}
}

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

void plResetCollisionWorld(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	if (sdk && worldHandle)
	{
		sdk->resetCollisionWorld(worldHandle);
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

plCollisionShapeHandle plCreateBoxShape(plCollisionSdkHandle sdkHandle,plCollisionWorldHandle world,plVector3 size)
{
	CollisionSdkInterface *sdk = (CollisionSdkInterface*) sdkHandle;
	return sdk->createBoxShape(world,size);
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
plCollisionShapeHandle plCreateTerrainShape(
	plCollisionSdkHandle sdkHandle, plCollisionWorldHandle worldHandle,
	int width, int height,
	const void *heightData, int phyDataType,	
	plReal heightScale, plReal minHeight, plReal maxHeight,
	int upAxis,
	bool filpQuadEdgess)
{
	// do data convert! need more setting 
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)sdkHandle;
	return sdk->createTerrainShape(worldHandle,
					width, height,
					heightData, phyDataType,
					heightScale, minHeight,maxHeight,
					upAxis,
					filpQuadEdgess);
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

void plSetShapeScale(plCollisionSdkHandle collisionSdkHandle,plCollisionWorldHandle worldHandle,plCollisionObjectHandle objectHandle, plCollisionShapeHandle shapeHandle,plVector3 scale)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->setShapeScale(worldHandle,objectHandle,shapeHandle,scale);
}

void plSetShapeScaleEx(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionShapeHandle shapeHandle, plVector3 scale)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
}

plCollisionObjectHandle plCreateCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, void* userData, int userIndex, plCollisionShapeHandle cshape, plVector3 childPos, plQuaternion childOrn)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	return sdk->createCollisionObject(worldHandle, userData, userIndex, cshape, childPos, childOrn);
}

void plDeleteCollisionObject(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle body)
{
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)collisionSdkHandle;
	sdk->deleteCollisionObject(worldHandle,body);
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



extern plCollisionShapeHandle 
plGetCollisionObjectShape(plCollisionSdkHandle sdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle) {
	CollisionSdkInterface* sdk = (CollisionSdkInterface*)sdkHandle;
	return sdk->getCollisionObjectShape(worldHandle, objHandle);
}

/* Collision Queries */
int plCollide(plCollisionSdkHandle collisionSdkHandle, plCollisionWorldHandle worldHandle, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
			  contact_point* pointsOut, int pointCapacity)
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

void plDrawline( plCollisionSdkHandle SdkHandle, plCollisionWorldHandle world, plVector3 rayFrom,plVector3 rayTo,unsigned int color)
{
	CollisionSdkInterface *sdk = (CollisionSdkInterface*) SdkHandle;
	sdk->drawline(world,rayFrom,rayTo,color);
	return;
}


