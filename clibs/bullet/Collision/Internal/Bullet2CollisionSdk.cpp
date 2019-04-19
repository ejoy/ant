
#include "Bullet2CollisionSdk.h"
#include "btBulletCollisionCommon.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"
#include "BulletDebugDraw.h"

#define  _DEBUG_OUTPUT_ 
struct Bullet2CollisionSdkInternalData
{
	btCollisionConfiguration* m_collisionConfig;
	btCollisionDispatcher* m_dispatcher;
	btBroadphaseInterface* m_aabbBroadphase;
	btCollisionWorld* m_collisionWorld;

	MyDebugDrawer* m_debugDrawer; 

	Bullet2CollisionSdkInternalData()
		: m_collisionConfig(0),
		  m_dispatcher(0),
		  m_aabbBroadphase(0),
		  m_collisionWorld(0),
		  m_debugDrawer(0)
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

// clean world's objects and reuse 
void Bullet2CollisionSdk::resetCollisionWorld(plCollisionWorldHandle worldHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	if (m_internalData->m_collisionWorld == world)
	{
		_deleteCollisionWorldObjects(worldHandle);
	}
}

void Bullet2CollisionSdk::deleteCollisionWorld(plCollisionWorldHandle worldHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btAssert(m_internalData->m_collisionWorld == world);

	if (m_internalData->m_collisionWorld == world)
	{
		_deleteCollisionWorldObjects(worldHandle);
		delete m_internalData->m_collisionWorld;
		m_internalData->m_collisionWorld = 0;
		delete m_internalData->m_aabbBroadphase;
		m_internalData->m_aabbBroadphase = 0;
		delete m_internalData->m_dispatcher;
		m_internalData->m_dispatcher = 0;
		delete m_internalData->m_collisionConfig;
		m_internalData->m_collisionConfig = 0;

		if(m_internalData->m_debugDrawer) {
			printf("delete debugDrawer = %p\n",m_internalData->m_debugDrawer);
			delete m_internalData->m_debugDrawer;
			m_internalData->m_debugDrawer = 0;
		}
	} else {
		printf("m_internalData->m_collisionWorld(%p) != world(%p)",m_internalData->m_collisionWorld,world);
	}
}

void Bullet2CollisionSdk::_deleteCollisionWorldObjects(plCollisionWorldHandle worldHandle) 
{
		btCollisionWorld* world = (btCollisionWorld*)worldHandle;
		btCollisionObjectArray& objects = world->getCollisionObjectArray();
		for(int i =0 ;i<world->getNumCollisionObjects();i++ ) 
		{
			btCollisionObject* collisionObject = objects[i];
			deleteCollisionObject( worldHandle, (plCollisionObjectHandle) collisionObject );
		}
		objects.clear();
}

// create Debug Drawer 
void Bullet2CollisionSdk::createDebugDrawer(plCollisionWorldHandle worldHandle)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btAssert(m_internalData->m_collisionWorld == world);
	if(m_internalData->m_collisionWorld == world) {
		if(m_internalData->m_debugDrawer) {
			delete m_internalData->m_debugDrawer;
			m_internalData->m_debugDrawer = 0;
		}
		m_internalData->m_debugDrawer = new MyDebugDrawer();    // 或者创建时直接填写绘制回调
		world->setDebugDrawer( m_internalData->m_debugDrawer );
		m_internalData->m_debugDrawer->setDebugMode(            // default view status
			btIDebugDraw::DBG_DrawWireframe 
			//+ btIDebugDraw::DBG_DrawAabb
			//+ btIDebugDraw::DBG_DrawContactPoints 
		);
	}
}

// delete Debug Drawer 
void Bullet2CollisionSdk::deleteDebugDrawer( plCollisionWorldHandle worldHandle)
{	
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btAssert(m_internalData->m_collisionWorld == world);
	if(m_internalData->m_collisionWorld == world) {
		if(m_internalData->m_debugDrawer) {
			delete m_internalData->m_debugDrawer;
			m_internalData->m_debugDrawer = 0;
		}
		world->setDebugDrawer( nullptr );
	}
}
// addition cube shape 
plCollisionShapeHandle Bullet2CollisionSdk::createBoxShape(plCollisionWorldHandle world,plVector3 size)
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

class HeightfieldTerrainShape:public btHeightfieldTerrainShape
{
public:
	HeightfieldTerrainShape(int heightStickWidth, int heightStickLength,
							  const void* heightfieldData, btScalar heightScale,
							  btScalar minHeight, btScalar maxHeight,
							  int upAxis, PHY_ScalarType heightDataType,
							  bool flipQuadEdges):
							  btHeightfieldTerrainShape( heightStickWidth, heightStickLength,
							  heightfieldData, heightScale,
							  minHeight, maxHeight,
							  upAxis, heightDataType,
							  flipQuadEdges)
	{ 	}

	void getVertex(int x,int y,btVector3 &vertex) {
		btHeightfieldTerrainShape::getVertex(x,y,vertex);
	}
	btScalar getRawHeight(int x,int y) {
		return btHeightfieldTerrainShape::getRawHeightFieldValue(x,y);
	}
};

void printTerrainShape(int w,int h,HeightfieldTerrainShape *shape) {
	FILE *out = fopen("terrain.txt","w+");
	if(out) {
		float min_height = 99999,max_height = -99999;
		float vmin_height = 99999,vmax_height = -99999;
		for(int y=0; y<h; y++) {
			for( int x=0; x<w; x++) {
				float height = shape->getRawHeight(x,y);
				fprintf(out,"%06.2f ",height );
				if( height <min_height ) min_height = height;
				if( height >max_height ) max_height = height;
			}
			fprintf(out,"\r");
			for( int x=0; x<h; x++) {
				btVector3 v ;
				shape->getVertex(x,y,v);
				float vh = v.getY();
				fprintf(out,"%06.2f ",vh );
				if( vh <vmin_height ) vmin_height = vh;
				if( vh >vmax_height ) vmax_height = vh;
			}
			fprintf(out,"\r");
		}
		fclose(out);
		printf("terrainShape raw min_height =%.2f,max_height =%.2f \n\n",min_height,max_height);
		printf("terrainShape v min_height =%.2f,max_height =%.2f \n\n",vmin_height,vmax_height);
	}
}
// do grid scale setting 
plCollisionShapeHandle Bullet2CollisionSdk::createTerrainShape(plCollisionWorldHandle worldHandle,
	int width, int height,
	const void *heightData, int phyDataType,	
	plReal heightScale, plReal minHeight, plReal maxHeight,
	int upAxis,
	bool filpQuadEdges)
{
	return (plCollisionShapeHandle)
		new btHeightfieldTerrainShape( width, height,
			heightData, 
			(btScalar)heightScale,  
			(btScalar)minHeight,  
			(btScalar)maxHeight,upAxis,
			(PHY_ScalarType)phyDataType, filpQuadEdges );	
	
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
			break;
		}
		case 1: {
			cylinder = new btCylinderShape( btVector3(radius, height, radius) );
			break;
		}
		case 2: {
			cylinder = new btCylinderShapeZ( btVector3(radius, radius, height) );
			break;
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

plCollisionShapeHandle Bullet2CollisionSdk::getCompoundChildShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle compoundShapeHandle, int childidx) {
	btCompoundShape *compoundShape = (btCompoundShape*)compoundShapeHandle;
	btAssert(compoundShape->isCompound());

	btAssert(0 <= childidx && childidx < compoundShape->getNumChildShapes());
	return (plCollisionShapeHandle)compoundShape->getChildShape(childidx);
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
// object equal shape
void Bullet2CollisionSdk::setShapeScale(plCollisionWorldHandle worldHandle,plCollisionObjectHandle objectHandle, plCollisionShapeHandle shapeHandle, plVector3 scale)
{
	btCollisionShape* shape = (btCollisionShape*)shapeHandle;
	shape->setLocalScaling(btVector3(scale[0],scale[1],scale[2]));
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	btCollisionObject* colObj = (btCollisionObject*)objectHandle;
	world->updateSingleAabb(colObj);
}


void Bullet2CollisionSdk::setShapeScaleEx(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shapeHandle, plVector3 scale) 
{
	btCollisionShape* shape = (btCollisionShape*)shapeHandle;
	shape->setLocalScaling(btVector3(scale[0], scale[1], scale[2]));
}

void Bullet2CollisionSdk::deleteShape(plCollisionWorldHandle worldHandle, plCollisionShapeHandle shapeHandle)
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
		if(colShape->getShapeType() == TERRAIN_SHAPE_PROXYTYPE ) {
			int flags = colObj->getCollisionFlags();
			flags |= btCollisionObject::CF_DISABLE_VISUALIZE_OBJECT;
			colObj->setCollisionFlags(flags);
		}
		return (plCollisionObjectHandle)colObj;
	}
	return 0;
}

void Bullet2CollisionSdk::deleteCollisionObject(plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle)
{
	btCollisionWorld *world = (btCollisionWorld *) worldHandle; 
	btCollisionObject* colObj = (btCollisionObject*)bodyHandle;	
    if( colObj->getWorldArrayIndex() != -1) {		
		world->removeCollisionObject(colObj);
	}
	btCollisionShape* shape = colObj->getCollisionShape();
	if(shape) {
		deleteShape(worldHandle, (plCollisionShapeHandle) shape );
		colObj->setCollisionShape(0);
	}
	delete colObj;	
}


plCollisionShapeHandle Bullet2CollisionSdk::getCollisionObjectShape(plCollisionWorldHandle worldHandle, plCollisionObjectHandle objectHandle) {
	btCollisionObject *obj = (btCollisionObject*)objectHandle;
	return (plCollisionShapeHandle)obj->getCollisionShape();
}

void Bullet2CollisionSdk::setCollisionObjectTransform(plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
													  plVector3 position, plQuaternion orientation)
{
	btCollisionObject* colObj = (btCollisionObject*)bodyHandle;
	btTransform tr;
	tr.setOrigin(btVector3(position[0], position[1], position[2]));
	tr.setRotation(btQuaternion(orientation[0], orientation[1], orientation[2], orientation[3]));
	colObj->setWorldTransform(tr);
	btCollisionWorld *world = (btCollisionWorld *) worldHandle; 
	world->updateSingleAabb(colObj);
#ifdef _DEBUG_OUTPUT_
	printf("setCollisionTransform: = \n");
	printf("pos = {%0.2f,%0.2f,%0.2f}\n",position[0], position[1], position[2]);
	printf("rot = {%0.2f,%0.2f,%0.2f,%0.2f}\n",orientation[0], orientation[1], orientation[2], orientation[3]);
#endif 	
}

// addition protocol for transform 
void Bullet2CollisionSdk::setCollisionObjectPosition( plCollisionWorldHandle worldHandle, plCollisionObjectHandle bodyHandle,
												 plVector3 position )
{
	btCollisionObject *colObj = (btCollisionObject*) bodyHandle;
	btTransform &tr = colObj->getWorldTransform();
	tr.setOrigin( btVector3( position[0],position[1],position[2]) );
	colObj->setWorldTransform(tr);
	btCollisionWorld *world = (btCollisionWorld *) worldHandle; 
	world->updateSingleAabb(colObj);
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
	btCollisionWorld *world = (btCollisionWorld *) worldHandle; 
	world->updateSingleAabb(colObj);
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

struct ClosestRayResultCallback: btCollisionWorld::ClosestRayResultCallback {
	ClosestRayResultCallback(const btVector3& rayFromWorld, const btVector3& rayToWorld)
			: btCollisionWorld::ClosestRayResultCallback( rayFromWorld,rayToWorld )
	{
		m_closestHitFraction = 10.0f;
	}

	virtual btScalar addSingleResult( btCollisionWorld::LocalRayResult& rayResult, bool normalInWorldSpace)
	{
		//caller already does the filter on the m_closestHitFraction		
		if(rayResult.m_hitFraction >= m_closestHitFraction)
			printf("****** error fraction ******");
		m_closestHitFraction = rayResult.m_hitFraction;
		m_collisionObject = rayResult.m_collisionObject;
		if (normalInWorldSpace)
		{
			m_hitNormalWorld = rayResult.m_hitNormalLocal;
		}
		else
		{
			///need to transform normal into worldspace
			m_hitNormalWorld = m_collisionObject->getWorldTransform().getBasis() * rayResult.m_hitNormalLocal;
		}
		m_hitPointWorld.setInterpolate3(m_rayFromWorld, m_rayToWorld, rayResult.m_hitFraction);
		return rayResult.m_hitFraction;
	}
};

void Bullet2CollisionSdk::drawline( plCollisionWorldHandle worldHandle, plVector3 rayFrom,plVector3 rayTo,unsigned int color) 
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;
	if (world == m_internalData->m_collisionWorld ) {
		if(world->getDebugDrawer()) {
			btVector3 btRayFrom(rayFrom[0],rayFrom[1],rayFrom[2]);
			btVector3 btRayTo(rayTo[0],rayTo[1],rayTo[2]);

			float scale = 1/255.0f;
			btVector3 btColor( ((color>>24)&0xFF)*scale, ((color>>16)&0xFF)*scale,((color>>8)&0xFF)*scale);
			world->getDebugDrawer()->drawLine(btRayFrom,btRayTo, btColor);
		}
	}
}
 
// add new export function 
#define  UNUSED(x) (void)(x)
bool Bullet2CollisionSdk::raycast( plCollisionWorldHandle worldHandle, plVector3 rayFrom,plVector3 rayTo, ClosestRayResult &result)
{
	btCollisionWorld* world = (btCollisionWorld*)worldHandle;

	if (world == m_internalData->m_collisionWorld ) {
		btVector3 btRayFrom(rayFrom[0],rayFrom[1],rayFrom[2]);
		btVector3 btRayTo(rayTo[0],rayTo[1],rayTo[2]);

		// if(world->getDebugDrawer())
		// 	world->getDebugDrawer()->drawLine(btRayFrom,btRayTo,btVector3(1,0,0));
		//btCollisionWorld::ClosestRayResultCallback cb( btRayFrom, btRayTo);
		ClosestRayResultCallback cb( btRayFrom, btRayTo);
		world->rayTest( btRayFrom,btRayTo, cb );

		if(cb.hasHit()) {
			// printf("m_hitFraction = %08.4f\n",cb.m_closestHitFraction);
			// printf("m_userIndex = %d \n", cb.m_collisionObject->getUserIndex());

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

			if(world->getDebugDrawer()) {
				btVector3 pt(result.m_hitPointWorld[0],result.m_hitPointWorld[1],result.m_hitPointWorld[2]);
				btVector3 nt(result.m_hitNormalWorld[0],result.m_hitNormalWorld[1],result.m_hitNormalWorld[2]);
				nt += pt;
				world->getDebugDrawer()->drawLine(pt,nt,btVector3(0.85f,0.6f,0.6f));
				world->getDebugDrawer()->drawLine(pt,nt+btVector3(0,0,-1),btVector3(0.6f,0.85f,0.6f));
				world->getDebugDrawer()->drawLine(pt,nt+btVector3(1,0,0),btVector3(0.6f,0.6f,0.85f));
			}
			// convert result from bullet to interface 
			return true;
		} 
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
// 服务于世界中所有物体的碰撞点检测，实用性极少。
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
