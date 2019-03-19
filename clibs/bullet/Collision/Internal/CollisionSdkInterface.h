#ifndef COLLISION_SDK_INTERFACE_H
#define COLLISION_SDK_INTERFACE_H

#include "../CollisionSdkC_Api.h"

class CollisionSdkInterface
{
public:
	virtual ~CollisionSdkInterface()
	{
	}

	virtual plCollisionWorldHandle createCollisionWorld(int maxNumObjsCapacity, int maxNumShapesCapacity, int maxNumPairsCapacity) = 0;

	virtual void deleteCollisionWorld(plCollisionWorldHandle worldHandle) = 0;

	virtual void resetCollisionWorld(plCollisionWorldHandle worldHandle) = 0;

	// addition staple box shape 
	virtual plCollisionShapeHandle createBoxShape(plCollisionWorldHandle world,plVector3 size) = 0;

	virtual plCollisionShapeHandle createSphereShape(plCollisionWorldHandle worldHandle, plReal radius) = 0;

	virtual plCollisionShapeHandle createPlaneShape(plCollisionWorldHandle worldHandle,
													plReal planeNormalX,
													plReal planeNormalY,
													plReal planeNormalZ,
													plReal planeConstant) = 0;
	virtual plCollisionShapeHandle createCapsuleShape(plCollisionWorldHandle worldHandle,
													  plReal radius,
													  plReal height,
													  int capsuleAxis) = 0;

	virtual plCollisionShapeHandle createCylinderShape(plCollisionWorldHandle worldHandle,
													   plReal radius,
													   plReal height,
													   int upAxis) = 0;

	virtual plCollisionShapeHandle createTerrainShape(plCollisionWorldHandle worldHandle,
													int width,int height, 
													const void *heightData, int phyDataType,
													plReal gridSize,
													plReal heightScale, plReal minHeight, plReal maxHeight,
													int upAxis,
													bool filpQuadEdges) = 0;													

	virtual plCollisionShapeHandle createCompoundShape(plCollisionWorldHandle worldHandle) = 0;
	virtual plCollisionShapeHandle getCompoundChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, int childidx) = 0;

	virtual void addChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShape, plCollisionShapeHandle childShape, plVector3 childPos, plQuaternion childOrn) = 0;

	virtual void deleteShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shape) = 0;
	virtual void setShapeScale(plCollisionWorldHandle worldHandle, plCollisionObjectHandle objectHandle, plCollisionShapeHandle shapeHandle,plVector3 scale) =0;

	virtual void addCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object) = 0;
	virtual void removeCollisionObject(plCollisionWorldHandle world, plCollisionObjectHandle object) = 0;

	virtual plCollisionObjectHandle createCollisionObject(plCollisionWorldHandle worldHandle, void* userPointer, int userIndex, plCollisionShapeHandle cshape,
														  plVector3 startPosition, plQuaternion startOrientation) = 0;
	virtual void deleteCollisionObject( plCollisionWorldHandle worldHandle, plCollisionObjectHandle body) = 0;
	virtual plCollisionShapeHandle getCollisionObjectShape(plCollisionWorldHandle worldHandle, plCollisionObjectHandle object) = 0;

	virtual void setCollisionObjectTransform(plCollisionWorldHandle world, plCollisionObjectHandle body,
											 plVector3 position, plQuaternion orientation) = 0;
	//  addition protocol:
	virtual void setCollisionObjectPosition( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plVector3 position ) = 0;
	virtual void setCollisionObjectRotation( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plQuaternion orientation ) = 0;
											 
	// collide between two objects
	virtual int collide(plCollisionWorldHandle world, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
						lwContactPoint* pointsOut, int pointCapacity) = 0;
    // world collide 
	virtual void collideWorld(plCollisionWorldHandle world,
							  plNearCallback filter, void* userData) = 0;

	//  addition protocol: raycast for accelerate collision detection
	virtual bool raycast( plCollisionWorldHandle world, plVector3 rayFrom,plVector3 rayTo,
						  ClosestRayResult &result ) = 0;

	//{@	debug	
	virtual void createDebugDrawer(plCollisionWorldHandle world) = 0;
	virtual void deleteDebugDrawer(plCollisionWorldHandle world) = 0;

	virtual void drawline( plCollisionWorldHandle world, plVector3 rayFrom,plVector3 rayTo,unsigned int color ) = 0;							  
	//@}

};

#endif  //COLLISION_SDK_INTERFACE_H
