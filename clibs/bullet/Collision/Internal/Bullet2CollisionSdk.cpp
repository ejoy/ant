#include "Bullet2CollisionSdk.h"
#include "btBulletCollisionCommon.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"

//#define  _DEBUG_OUTPUT_ 
struct Bullet2CollisionSdkInternalData
{
	btCollisionConfiguration* m_collisionConfig;
	btCollisionDispatcher* m_dispatcher;
	btBroadphaseInterface* m_aabbBroadphase;
	btCollisionWorld* m_collisionWorld;

	Bullet2CollisionSdkInternalData()
		: m_collisionConfig(0),
		  m_dispatcher(0),
		  m_aabbBroadphase(0),
		  m_collisionWorld(0)
	{
	}
};

Bullet2CollisionSdk::Bullet2CollisionSdk()
{
	m_internalData = new Bullet2CollisionSdkInternalData;
}

Bullet2CollisionSdk::~Bullet2CollisionSdk()
{
	delete m_internalData;
	m_internalData = 0;
}

plCollisionWorldHandle Bullet2CollisionSdk::createCollisionWorld(int /*maxNumObjsCapacity*/, int /*maxNumShapesCapacity*/, int /*maxNumPairsCapacity*/)
{
	m_internalData->m_collisionConfig = new btDefaultCollisionConfiguration;

	m_internalData->m_dispatcher = new btCollisionDispatcher(m_internalData->m_collisionConfig);
	m_internalData->m_aabbBroadphase = new btDbvtBroadphase();
	m_internalData->m_collisionWorld = new btCollisionWorld(m_internalData->m_dispatcher,
															m_internalData->m_aabbBroadphase,
															m_internalData->m_collisionConfig);
	return (plCollisionWorldHandle)m_internalData->m_collisionWorld;
}

void Bullet2CollisionSdk::deleteCollisionWorld(plCollisionWorldHandle worldHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btAssert(m_internalData->m_collisionWorld == world);

	if (m_internalData->m_collisionWorld == world)
	{
		delete m_internalData->m_collisionWorld;
		m_internalData->m_collisionWorld = 0;
		delete m_internalData->m_aabbBroadphase;
		m_internalData->m_aabbBroadphase = 0;
		delete m_internalData->m_dispatcher;
		m_internalData->m_dispatcher = 0;
		delete m_internalData->m_collisionConfig;
		m_internalData->m_collisionConfig = 0;
	}
}
// addition cube shape 
plCollisionShapeHandle Bullet2CollisionSdk::createCubeShape(plCollisionWorldHandle world,plVector3 size)
{
	btBoxShape *boxShape = new btBoxShape( btVector3(size[0],size[1],size[2]) );
	return (plCollisionShapeHandle) boxShape;
}

plCollisionShapeHandle Bullet2CollisionSdk::createSphereShape(plCollisionWorldHandle /*worldHandle*/, plReal radius)
{
	btSphereShape* sphereShape = new btSphereShape(radius);
	return (plCollisionShapeHandle)sphereShape;
}

plCollisionShapeHandle Bullet2CollisionSdk::createPlaneShape(plCollisionWorldHandle worldHandle,
															 plReal planeNormalX,
															 plReal planeNormalY,
															 plReal planeNormalZ,
															 plReal planeConstant)
{
	btStaticPlaneShape* planeShape = new btStaticPlaneShape( btVector3(planeNormalX, planeNormalY, planeNormalZ), planeConstant);
	return (plCollisionShapeHandle)planeShape;
}
// do grid scale setting 
plCollisionShapeHandle Bullet2CollisionSdk::createTerrainShape(plCollisionWorldHandle worldHandle,
													int width,int height, const void *heightData, plReal gridSize,
													plReal heightScale,plReal minHeight,plReal maxHeight,int upAxis,
													int phyDataType,
													bool filpQuadEdges)
{
	btHeightfieldTerrainShape *terrainShape = new btHeightfieldTerrainShape( width,height,heightData, 
															                 (btScalar)heightScale,  (btScalar)minHeight,  (btScalar)maxHeight,upAxis,
																			 (PHY_ScalarType)phyDataType, filpQuadEdges );
	return (plCollisionShapeHandle)terrainShape;
}									


plCollisionShapeHandle Bullet2CollisionSdk::createCapsuleShape(plCollisionWorldHandle worldHandle,
															   plReal radius,
															   plReal height,
															   int capsuleAxis)
{
	btCapsuleShape* capsule = 0;

	switch (capsuleAxis)
	{
		case 0: 	{
			capsule = new btCapsuleShapeX(radius, height);
			break;
		}
		case 1:		{
			capsule = new btCapsuleShape(radius, height);
			break;
		}
		case 2:		{
			capsule = new btCapsuleShapeZ(radius, height);
			break;
		}
		default:	{
			btAssert(0);
		}
	}
	return (plCollisionShapeHandle)capsule;
}

plCollisionShapeHandle Bullet2CollisionSdk::createCylinderShape(plCollisionWorldHandle worldHandle,
																plReal radius,plReal height,int upAxis) 
{
	btCylinderShape* cylinder = 0;
	switch(upAxis) 
	{
		case 0: {
			cylinder = new btCylinderShapeX( btVector3(height,radius,radius) );
		}
		case 1: {
			cylinder = new btCylinderShape( btVector3(radius, height, radius) );
		}
		case 2: {
			cylinder = new btCylinderShapeZ( btVector3(radius, radius, height) );
		}
		default: {
			btAssert(0);
		}
	}
	return (plCollisionShapeHandle) cylinder;
}

plCollisionShapeHandle Bullet2CollisionSdk::createCompoundShape(plCollisionWorldHandle worldHandle)
{
	return (plCollisionShapeHandle) new btCompoundShape();
}
void Bullet2CollisionSdk::addChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShapeHandle, plCollisionShapeHandle childShapeHandle, plVector3 childPos, plQuaternion childOrn)
{
	btCompoundShape* compound = (btCompoundShape*)compoundShapeHandle;
	btCollisionShape* childShape = (btCollisionShape*)childShapeHandle;
	btTransform localTrans;
	localTrans.setOrigin(btVector3(childPos[0], childPos[1], childPos[2]));
	localTrans.setRotation(btQuaternion(childOrn[0], childOrn[1], childOrn[2], childOrn[3]));
	compound->addChildShape(localTrans, childShape);
}


void Bullet2CollisionSdk::deleteShape(plCollisionWorldHandle /*worldHandle*/, plCollisionShapeHandle shapeHandle)
{
	btCollisionShape* shape = (btCollisionShape*)shapeHandle;
	delete shape;
}

void Bullet2CollisionSdk::addCollisionObject(plCollisionWorldHandle worldHandle, plCollisionObjectHandle objectHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btCollisionObject* colObj = (btCollisionObject*)objectHandle;
	btAssert(world && colObj);
	if (world == m_internalData->m_collisionWorld && colObj)
	{
		world->addCollisionObject(colObj);
	}
}
void Bullet2CollisionSdk::removeCollisionObject(plCollisionWorldHandle worldHandle, plCollisionObjectHandle objectHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btCollisionObject* colObj = (btCollisionObject*)objectHandle;
	btAssert(world && colObj);
	if (world == m_internalData->m_collisionWorld && colObj)
	{
		world->removeCollisionObject(colObj);
	}
}

plCollisionObjectHandle Bullet2CollisionSdk::createCollisionObject(plCollisionWorldHandle worldHandle, void* userPointer, int userIndex, plCollisionShapeHandle shapeHandle,
																   plVector3 startPosition, plQuaternion startOrientation)

{
	btCollisionShape* colShape = (btCollisionShape*)shapeHandle;
	btAssert(colShape);
	if (colShape)
	{
		btCollisionObject* colObj = new btCollisionObject;
		colObj->setUserIndex(userIndex);
		colObj->setUserPointer(userPointer);
		colObj->setCollisionShape(colShape);
		btTransform tr;
		tr.setOrigin(btVector3(startPosition[0], startPosition[1], startPosition[2]));
		tr.setRotation(btQuaternion(startOrientation[0], startOrientation[1], startOrientation[2], startOrientation[3]));
		colObj->setWorldTransform(tr);
		return (plCollisionObjectHandle)colObj;
	}
	return 0;
}

void Bullet2CollisionSdk::deleteCollisionObject(plCollisionObjectHandle bodyHandle)
{
	btCollisionObject* colObj = (btCollisionObject*)bodyHandle;
	delete colObj;
}
void Bullet2CollisionSdk::setCollisionObjectTransform(plCollisionWorldHandle /*worldHandle*/, plCollisionObjectHandle bodyHandle,
													  plVector3 position, plQuaternion orientation)
{
	btCollisionObject* colObj = (btCollisionObject*)bodyHandle;
	btTransform tr;
	tr.setOrigin(btVector3(position[0], position[1], position[2]));
	tr.setRotation(btQuaternion(orientation[0], orientation[1], orientation[2], orientation[3]));
#ifdef _DEBUG_OUTPUT_
	printf("setCollisionTransform: = \n");
	printf("pos = {%0.2f,%0.2f,%0.2f}\n",position[0], position[1], position[2]);
	printf("rot = {%0.2f,%0.2f,%0.2f,%0.2f}\n",orientation[0], orientation[1], orientation[2], orientation[3]);
#endif 	
	colObj->setWorldTransform(tr);
}

// addition protocol for transform 
void Bullet2CollisionSdk::setCollisionObjectPosition( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plVector3 position )
{
	btCollisionObject *colObj = (btCollisionObject*) bodyHandle;
	btTransform &tr = colObj->getWorldTransform();
	tr.setOrigin( btVector3( position[0],position[1],position[2]) );
	colObj->setWorldTransform(tr);
#ifdef _DEBUG_OUTPUT_				 
	printf("set object pos = (%0.2f,%0.2f,%0.2f)\n",position[0],position[1],position[2]);
#endif 
}

void Bullet2CollisionSdk::setCollisionObjectRotation( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plQuaternion orientation )
{
	btCollisionObject *colObj = (btCollisionObject*) bodyHandle;
	btTransform &tr = colObj->getWorldTransform();
	tr.setRotation( btQuaternion(orientation[0],orientation[1],orientation[2],orientation[3]) );
	colObj->setWorldTransform(tr);
}

void Bullet2CollisionSdk::setCollisionObjectRotationEuler( plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												plReal yaw, plReal pitch, plReal roll)
{
	btCollisionObject *colObj = (btCollisionObject*) objHandle;
	btTransform &tr = colObj->getWorldTransform();
	tr.setRotation( btQuaternion(yaw,pitch,roll ));
	colObj->setWorldTransform(tr);
	printf("yaw = %.2f, pitch = %.2f,roll = %.2f\n",yaw,pitch,roll);
}												   
																		 
void Bullet2CollisionSdk::setCollisionObjectRotationAxisAngle( plCollisionWorldHandle worldHandle, plCollisionObjectHandle objHandle,
												plVector3 axis, plReal angle)
{
	btCollisionObject *colObj = (btCollisionObject*) objHandle;
	btTransform &tr = colObj->getWorldTransform();
	tr.setRotation( btQuaternion( btVector3(axis[0],axis[1],axis[2]),(btScalar) angle) );
	colObj->setWorldTransform(tr);
	printf(" axis  = { %.2f,%.2f,%2.f}, angle = %.2f \n", axis[0], axis[1], axis[2], angle);
}												




struct Bullet2ContactResultCallback : public btCollisionWorld::ContactResultCallback
{
	int m_numContacts;
	lwContactPoint* m_pointsOut;
	int m_pointCapacity;

	Bullet2ContactResultCallback(lwContactPoint* pointsOut, int pointCapacity) : m_numContacts(0),
																				 m_pointsOut(pointsOut),
																				 m_pointCapacity(pointCapacity)
	{
	}
	virtual btScalar addSingleResult(btManifoldPoint& cp, const btCollisionObjectWrapper* colObj0Wrap, int partId0, int index0, const btCollisionObjectWrapper* colObj1Wrap, int partId1, int index1)
	{
		if (m_numContacts < m_pointCapacity)
		{
			lwContactPoint& ptOut = m_pointsOut[m_numContacts];
			ptOut.m_distance = cp.m_distance1;
			ptOut.m_normalOnB[0] = cp.m_normalWorldOnB.getX();
			ptOut.m_normalOnB[1] = cp.m_normalWorldOnB.getY();
			ptOut.m_normalOnB[2] = cp.m_normalWorldOnB.getZ();
			ptOut.m_ptOnAWorld[0] = cp.m_positionWorldOnA[0];
			ptOut.m_ptOnAWorld[1] = cp.m_positionWorldOnA[1];
			ptOut.m_ptOnAWorld[2] = cp.m_positionWorldOnA[2];
			ptOut.m_ptOnBWorld[0] = cp.m_positionWorldOnB[0];
			ptOut.m_ptOnBWorld[1] = cp.m_positionWorldOnB[1];
			ptOut.m_ptOnBWorld[2] = cp.m_positionWorldOnB[2];
			m_numContacts++;
		}

		return 1.f;
	}
};

int Bullet2CollisionSdk::collide(plCollisionWorldHandle worldHandle, plCollisionObjectHandle colA, plCollisionObjectHandle colB,
								 lwContactPoint* pointsOut, int pointCapacity)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btCollisionObject* colObjA = (btCollisionObject*)colA;
	btCollisionObject* colObjB = (btCollisionObject*)colB;
	btAssert(world && colObjA && colObjB);
	if (world == m_internalData->m_collisionWorld && colObjA && colObjB)
	{
		Bullet2ContactResultCallback cb(pointsOut, pointCapacity);
		world->contactPairTest(colObjA, colObjB, cb);
		return cb.m_numContacts;
	}
	return 0;
}
 
// add new export function 
#define  UNUSED(x) (void)(x)
bool Bullet2CollisionSdk::raycast( plCollisionWorldHandle worldHandle, plVector3 rayFrom,plVector3 rayTo, ClosestRayResult &result)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;

	if (world == m_internalData->m_collisionWorld ) {
		btVector3 btRayFrom(rayFrom[0],rayFrom[1],rayFrom[2]);
		btVector3 btRayTo(rayTo[0],rayTo[1],rayTo[2]);
		btCollisionWorld::ClosestRayResultCallback cb( btRayFrom, btRayTo);
		world->rayTest( btRayFrom,btRayTo, cb );

		if(cb.hasHit()) {
			UNUSED( cb.m_hitPointWorld );
			UNUSED( cb.m_hitNormalWorld );
			UNUSED( cb.m_closestHitFraction );
			UNUSED( cb.m_collisionObject );

			UNUSED( cb.m_collisionFilterGroup );
			UNUSED( cb.m_collisionFilterMask );
			UNUSED( cb.m_flags );

			result.m_hitPointWorld[0] = cb.m_hitPointWorld.getX();
			result.m_hitPointWorld[1] = cb.m_hitPointWorld.getY();
			result.m_hitPointWorld[2] = cb.m_hitPointWorld.getZ();

			result.m_hitNormalWorld[0] = cb.m_hitNormalWorld.getX();
			result.m_hitNormalWorld[1] = cb.m_hitNormalWorld.getY();
			result.m_hitNormalWorld[2] = cb.m_hitNormalWorld.getZ();

			result.m_hitFraction = cb.m_closestHitFraction;
			result.m_hitObjId = cb.m_collisionObject->getUserIndex();
			result.m_filterGroup = cb.m_collisionFilterGroup;
			result.m_filterMask  = cb.m_collisionFilterMask;
			result.m_flags = cb.m_flags;

			// convert result from bullet to interface 
			return true;
		} 
#ifdef _DEBUG_OUTPUT_
		printf("raycast from(%.02f,%.02f,%.02f) to(%.02f,%.02f,%.02f)---> \n",
				rayFrom[0],rayFrom[1],rayFrom[2],
				rayTo[0],rayTo[1],rayTo[2]);
#endif 				
	}		
	return false;
}

// ugly ,it's a trap ,not complete wrapper 
static plNearCallback gTmpFilter;
static int gNearCallbackCount = 0;
static plCollisionSdkHandle gCollisionSdk = 0;
static plCollisionWorldHandle gCollisionWorldHandle = 0;

static void* gUserData = 0;

// ugly, finally global variables must need,it's a not complete wrap
// Bullet2NearCallback use callback gTmpFilter which include global status  variables 
// Bullet2NearCallback 这个是系统层的回调,这个包装避免不了用户回调 使用 gTmpFilter 的变量全局性的需求
// 而这个状态属于 collision 行为的，是否可以使用 userdata 来规避全局变量，其合理性还需要进一步使用分析?
void Bullet2NearCallback(btBroadphasePair& collisionPair, btCollisionDispatcher& dispatcher, const btDispatcherInfo& dispatchInfo)
{
	btCollisionObject* colObj0 = (btCollisionObject*)collisionPair.m_pProxy0->m_clientObject;
	btCollisionObject* colObj1 = (btCollisionObject*)collisionPair.m_pProxy1->m_clientObject;
	plCollisionObjectHandle obA = (plCollisionObjectHandle)colObj0;
	plCollisionObjectHandle obB = (plCollisionObjectHandle)colObj1;
	if (gTmpFilter)
	{
#ifdef _DEBUG_OUTPUT_		
		printf("User Callback Calculate....\n" );
#endif 		
		gTmpFilter(gCollisionSdk, gCollisionWorldHandle, gUserData, obA, obB);
		gNearCallbackCount++;
	}
}

void Bullet2CollisionSdk::collideWorld(plCollisionWorldHandle worldHandle,
									   plNearCallback filter, void* userData)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	//chain the near-callback
	gTmpFilter = filter;
	gNearCallbackCount = 0;
	gUserData = userData;
	gCollisionSdk = (plCollisionSdkHandle)this;
	gCollisionWorldHandle = worldHandle;
	m_internalData->m_dispatcher->setNearCallback(Bullet2NearCallback);
	world->performDiscreteCollisionDetection();
	gTmpFilter = 0;
#ifdef _DEBUG_OUTPUT_	
	printf("do world collision, performDiscreteCollisionDetection.../-\\-/-\\...\n");
#endif 	
}


plCollisionSdkHandle Bullet2CollisionSdk::createBullet2SdkHandle()
{
	return (plCollisionSdkHandle) new Bullet2CollisionSdk;
}
