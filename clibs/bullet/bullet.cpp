#define LUA_LIB
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

// extern "C" {
// //#include <bgfx/c99/bgfx.h>
// //#include <bgfx/c99/platform.h>
// }

// #include <bgfx/bgfx.h>
// #include <bx/allocator.h>
#include <stdio.h>
#include <math.h>


//Big/Small Endian
#ifdef __MAC__
#elif  __IOS__
#elif  __WIN64
#endif

#include "btBulletDynamicsCommon.h"
#include "Collision/CollisionSdkC_Api.h"

#ifdef __cplusplus
extern "C" {
#endif

#define __DEBUG_OUTPUT_ 1

//	源文件维护方法：
//	1. 接口并未稳定，升级可能变化
//	2. 接口提供的功能并不充分，需要扩充
//	3. 考虑避免更新带来的覆盖，修改扩充对照保留
//	则将几个sdkinterface 拷贝到lbullet新目录下，
//	作为独立分支扩充维护,便利些，避免工程受到较大影响。
//	或者可以考虑只使用 bullet2 sdk 即可，时间和复杂度可以大幅度降低。

//  考察物理引擎的内存对方管理，物理引擎较重度的管理和维护自己的对象空间，
//  同时参考 bullet 本身的例子实现
//  认为接口采用 Lua 系统库 File I/O 的 lightuserdata 方式管理比较合适，
//	这需要Lua Physics API 配对使用，稍微改变 lua 的自动 gc 习惯。

//  使用 SdkC API, 是为了后面 sdk2->sdk3 可以无缝升级.

/*
// create and return bullet environment
sdkhandle
worldhandle
shapehandle
objecthandle
*/

// quaterion 的使用需要设计几种更简单的接口
// 1. use euler 
// 2. axis, angle


static int 
linit_physics( lua_State *L) {
	//todo: bullet sdk create(select between 2 and 3 )
	plCollisionSdkHandle sdk_handle = plCreateBullet2CollisionSdk();
	lua_pushlightuserdata(L,sdk_handle);
	#ifdef __DEBUG_OUTPUT_
	printf("alloc physic sdk %d\n", sdk_handle->unused );	
	#endif  
	return 1;
}

//sdk,world handle 
static int
lexit_physics( lua_State *L) {
	//todo: recyle sdk memory 
	int argc = lua_gettop(L);
	if( argc == 1) {
		if( lua_isuserdata(L,1) ) {
			plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
			plDeleteCollisionSdk( sdk_handle );
			#ifdef __DEBUG_OUTPUT_
			printf("free physic sdk %d\n", sdk_handle->unused );						
			#endif 
		} else {
			luaL_error(L,"error: exit_physics first argument sdk_handle must be userdata.\n");
		}
	}else {
		luaL_error(L,"error: exit_physics expects argument sdkhandle, exit_physics(sdk_handle).\n");
	}
	return 0;
}

//in: sdk handle
//out: world handle
static int 
lcreate_world( lua_State *L )  {
	if(!lua_isuserdata(L,1) ) {
		luaL_error(L,"error: create_world first argument sdk_handle must be userdata.\n");		
		return 0;
	}

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	// maxNumObjectsCapacity,maxNumShapesCapacity,maxNumPairsCapacity ,sdk2 not need
	plCollisionWorldHandle world_handle = plCreateCollisionWorld( sdk_handle,0,0,0);
	lua_pushlightuserdata(L, world_handle );	

	#ifdef __DEBUG_OUTPUT_
	printf("create world %d\n",world_handle->unused);
	#endif

    return 1;
}
static int 
ldestroy_world( lua_State *L ) {
	if(!lua_isuserdata(L,1) ) {
		luaL_error(L,"error: destroy_world first argument sdk_handle must be userdata.\n");		
		return 0;
	}
	if(!lua_isuserdata(L,2) ) {
		luaL_error(L,"error: destroy_world second argument world_handle must be userdata.\n");		
		return 0;
	}

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);
	plDeleteCollisionWorld(sdk_handle,world_handle);

#ifdef __DEBUG_OUTPUT_
	printf("destroy world %d(%d)\n",world_handle->unused,sdk_handle->unused );
#endif 

    return 0;
}

int check_sdk_world_handle(lua_State *L,int sdk_idx,int world_idx,const char *fname) {
	if(!lua_isuserdata(L, sdk_idx)) {
		luaL_error(L,"error: %s argument %d must be sdk handle.\n",fname,sdk_idx);
		return 0;
	}
	if(!lua_isuserdata(L, world_idx)) {
		luaL_error(L,"error: %s argument %d must be world handle.\n",fname,world_idx);
		return 0;
	}
	return 1;
}

// utils 
// table array {0,0,0}
btVector3 getVector3( lua_State *L,int table)
{
	btVector3 pos(0,0,0);
	int tsize = lua_rawlen(L,table);
	if(tsize) {
		lua_rawgeti(L,table,1);
		pos[0] = lua_tonumber(L,-1);
		lua_pop(L,1);

		lua_rawgeti(L,table,2);
		pos[1] = lua_tonumber(L,-1);
		lua_pop(L,1);

		lua_rawgeti(L,table,3);
		pos[2] = lua_tonumber(L,-1);
		lua_pop(L,1);
	}
	return pos;
}
// table array {0,0,0,1}
btQuaternion getQuaternion( lua_State *L,int table) 
{
	btQuaternion quat(0,0,0,1);
	int tsize = lua_rawlen(L,table);
	if(tsize) {
		lua_rawgeti(L,table,1);
		quat[0] = lua_tonumber(L,-1);
		lua_pop(L,1);

		lua_rawgeti(L,table,2);
		quat[1] = lua_tonumber(L,-1);
		lua_pop(L,1);

		lua_rawgeti(L,table,3);
		quat[2] = lua_tonumber(L,-1);
		lua_pop(L,1);

		lua_rawgeti(L,table,4);
		quat[3] = lua_tonumber(L,-1);
		lua_pop(L,1);
	}
	return quat;
}


// --- shape ---
//sdk,worl,size = {x,y,z} or x,y,z
static int 
lcreate_cubeShape( lua_State *L) {
	if( !check_sdk_world_handle(L,1,2,"create_cubeShape"))
		return 0;
	btVector3  halfSize(1,1,1);
	if( lua_istable(L,3) ) {
		halfSize = getVector3(L,3);
	} else {
		halfSize[0] = lua_tonumber(L,3);
		halfSize[1] = lua_tonumber(L,4);
		halfSize[2] = lua_tonumber(L,5);
	}

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);

	plCollisionShapeHandle shape = plCreateCubeShape(sdk_handle,world_handle,halfSize);
	lua_pushlightuserdata( L,shape );
#ifdef __DEBUG_OUTPUT_
	printf("create cube shape(%d),size(%0.2f,%0.2f,%0.2f). \n",shape->unused,
								halfSize[0],halfSize[1],halfSize[2]);
#endif 	
	return 1;
}

//sdk,world,radius
static int 
lcreate_sphereShape( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc == 3) {
		if( !check_sdk_world_handle(L,1,2,"create_sphereShape") ) {
			return 0;
		}
		plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
		plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);
		btScalar radius = lua_tonumber(L,3);

		plCollisionShapeHandle shape = plCreateSphereShape( sdk_handle,world_handle,radius);
		lua_pushlightuserdata(L,shape);

#ifdef __DEBUG_OUTPUT_
		printf("create sphere shape(%d) radius(%.f) \n",shape->unused,radius);
#endif 
		return 1;
	} else {
		luaL_error(L,"error: invalid number of argument, expects create_sphereShape(sdkhandle,worldhandle,radius)" );
	}
	return 0;
}

//sdk,world, {x,y,z,d} or x,y,z,d
static int 
lcreate_planeShape( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc < 3 ) {
		luaL_error(L,"error: create_planeShape must not less than 3 arguments. \n \
					  create_planeShape(sdk_handle,world_handle,{x,y,z,d}).\n \
					  or create_planeShape(sdk_handle,world_handle,x,y,z,d).\n " );
		return 0;
	}

	if( !check_sdk_world_handle(L,1,2,"create_planeShape") ) {
			return 0;
	}

	btVector4 plane(0,0,0,1);
	if( lua_istable(L,3) ) {
	
	} else {
		plane[0] = lua_tonumber(L,3);
		plane[1] = lua_tonumber(L,4);
		plane[2] = lua_tonumber(L,5);
		plane[3] = lua_tonumber(L,6);
	}

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);
	plCollisionShapeHandle shape = plCreatePlaneShape(sdk_handle,world_handle, plane[0],plane[1],plane[2],plane[3] );
	lua_pushlightuserdata(L,shape);

#ifdef __DEBUG_OUTPUT_
	printf("create plane shape(%d) plane(%f,%f,%f,%f) \n",shape->unused, plane[0],plane[1],plane[2],plane[3] );
#endif 
	return 1;
}


// sdk,world,radius,height,capsuleAxis
static int 
lcreate_capsuleShape( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc < 4 ) {
		luaL_error(L,"error: invalid number of arguments,expects create_capsuleShape(sdk,world,radius,height,axis=1 ).\n ");
		return 0;
	}
	if( !check_sdk_world_handle(L,1,2,"create_capsuleShape") )
		return 0;

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);

	int      axis   = 1;
	btScalar radius = lua_tonumber(L,3);
	btScalar height = lua_tonumber(L,4);
	if( argc == 5 )
	  axis = lua_tonumber(L,5);
	if( axis<0 || axis >2 )
	  axis = 1;

	plCollisionShapeHandle shape = plCreateCapsuleShape(sdk_handle,world_handle, radius, height, axis );
	lua_pushlightuserdata(L,shape);
#ifdef __DEBUG_OUTPUT_
	printf("create capsule shape(%d),r=%0.2f,h=%0.2f,axis=%d.\n",shape->unused,radius,height,axis);
#endif 
	return 1;
}

static int 
lcreate_cylinderShape( lua_State *L) {
	return 1;
}

static int 
lcreate_compoundShape( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc < 2 ) {
		luaL_error(L,"error: invalid number of arguments,expects create_compoundShape(sdk,world).\n ");
		return 0;
	}
	if( !check_sdk_world_handle(L,1,2,"create_CompoundShape") )
		return 0;

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);
	plCollisionShapeHandle shape = plCreateCompoundShape(sdk_handle,world_handle);
	lua_pushlightuserdata(L,shape);
#ifdef __DEBUG_OUTPUT_
	printf("create compound shape(%d).\n",shape->unused);
#endif 
	return 1;
}



// sdk,world,compound,shape,pos,quat
static int 
ladd_shapeToCompound( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc != 6 ) {
		luaL_error( L,"error: invalid arguments, add_shapeToCompound(sdk,world,compound,shape,pos,qrot). \n " ); 
		return 0;		
	}

	if( !check_sdk_world_handle(L,1,2,"add_shapeToCompound") )
		return 0;

 	if( !lua_isuserdata(L,3) ) {
		 luaL_error(L,"error: argument 3 compound must be handle.\n");
		 return 0;
	}
	if( !lua_isuserdata(L,4) ) {
		luaL_error(L,"error: argument 4 shape must be handle.\n ");
		return 0;
	}

	plCollisionSdkHandle  sdk_handle = (plCollisionSdkHandle) lua_touserdata(L, 1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L, 2);
	plCollisionShapeHandle compound  = (plCollisionShapeHandle) lua_touserdata(L,3);
	plCollisionShapeHandle shape = (plCollisionShapeHandle) lua_touserdata(L,4);

	btVector3 pos = getVector3(L,5);
	btQuaternion rot = getQuaternion(L,6);

	plAddChildShape( sdk_handle,world_handle,compound,shape,pos,rot);
#ifdef __DEBUG_OUTPUT_
	printf("add shapde(%d) to compound(%d).\n",shape->unused,compound->unused);
	printf("pos = (%f,%f,%f).\n",pos[0],pos[1],pos[2]);
	printf("quat = (%f,%f,%f,%f).\n",rot[0],rot[1],rot[2],rot[3]);
#endif 
	return 0;
}

//sdk,world,shape
static int 
ldelete_shape( lua_State *L) {
	if( !check_sdk_world_handle(L,1,2,"delete_shape") )
		return 0;
	
	if( !lua_isuserdata(L,3) ) {
		luaL_error(L,"error: delete_shape argument 3 must be shape handle.\n");
		return 0;
	}

	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionShapeHandle shape = (plCollisionShapeHandle) lua_touserdata(L,3);
#ifdef __DEBUG_OUTPUT_
	printf("delete shape(%d) from world(%d).\n",shape->unused,world_handle->unused);
#endif 
	plDeleteShape( sdk_handle,world_handle, shape);

	return 0;
}


static int 
ladd_shapeToWorld( lua_State *L) {
	return 1;
}

static int 
ldelete_shapeFromWorld( lua_State *L) {
	return 1;
}


// --- object ---
// sdk,world,shape handle,pos,rotation,user index, user pointer
// link entity id and shape handle
static int 
lcreate_collisionObject( lua_State *L) {
	int argc = lua_gettop(L);
	if( argc <6 ) {
		luaL_error(L,"error: expects not less than 6 arguments like create_collisionObject(sdk,world,shape,pos,rotation, id,void *).\n");
		return 0;
	}
	if( !check_sdk_world_handle(L,1,2,"create_collisionObject") )
		return 0;
	if( !lua_isuserdata(L,3) ) {
		luaL_error(L,"error: delete_shape argument 3 must be shape handle.\n");
		return 0;
	}

	plCollisionSdkHandle   sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionShapeHandle shape = (plCollisionShapeHandle) lua_touserdata(L,3);

	btVector3 	 pos = getVector3(L,4);
	btQuaternion rot = getQuaternion(L,5);
	void *user_data  = nullptr;
	int user_id = lua_tointeger(L,6);

	if( argc == 7 && !lua_isnil(L,7) ) {
		// extension mothod,it's an addition not need
		// get lua object ? how ?  
		// lua_ref 
	}

	plCollisionObjectHandle object = (plCollisionObjectHandle) 
	plCreateCollisionObject(sdk_handle,world_handle,user_data,user_id,shape,pos,rot);
	lua_pushlightuserdata( L, object );
#ifdef __DEBUG_OUTPUT_
	printf("create collision object(%d) from shape(%d),\n \
	    pos(%0.2f,%0.2f,%0.2f), rot(%0.2f,%0.2f,%0.2f,%0.2f).\n",
						object->unused,shape->unused,
						pos[0], pos[1], pos[2],
						rot[0], rot[1], rot[2], rot[3]);
#endif 						
	return 1;
}

static int 
ldelete_collisionObject( lua_State *L) {
	if( !check_sdk_world_handle(L,1,2,"delete_collisionObject") )
		return 0;
	if( !lua_isuserdata(L,3) ) {
		luaL_error(L,"error: delete_collisionObject argument 3 must be object handle.\n");
		return 0;
	}

	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle object = (plCollisionObjectHandle) lua_touserdata(L,3);
#ifdef __DEBUG_OUTPUT_
	printf("delete object(%d) from world(%d).\n",object->unused, world_handle->unused);
#endif 
	plDeleteCollisionObject( sdk_handle,world_handle, object );

	return 0;
}

//sdk,world,object,pos,rot
static int
lset_collisionObjectTransform( lua_State *L )
{
	if( !check_sdk_world_handle(L,1,2,"set_collisionObjectTransform"))
		return 0;
	if( !lua_isuserdata(L,3)) {
		luaL_error(L,"error: set_collisionObjectTransform argument 3 must be object handle.\n");
		return 0;
	}
	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle object = (plCollisionObjectHandle) lua_touserdata(L,3);

   	btVector3 pos = getVector3(L,4);
	btQuaternion rot = getQuaternion(L,5);

#ifdef __DEBUG_OUTPUT_
	printf("set collision object...\n");
#endif 

	plSetCollisionObjectTransform(sdk_handle,world_handle,object,pos,rot);	

#ifdef __DEBUG_OUTPUT_
	printf("move  object(%d) to:\n",object->unused);
	printf("pos = (%f,%f,%f).\n",pos[0],pos[1],pos[2]);
	printf("rot = (%f,%f,%f,%f).\n",rot[0],rot[1],rot[2],rot[3]);
#endif 

	return 0;
}
//sdk,world,object,pos
static int
lset_collisionObjectPos( lua_State *L )
{
	if( !check_sdk_world_handle(L,1,2,"set_collisionObjectPos"))
		return 0;
	if( !lua_isuserdata(L,3)) {
		luaL_error(L,"error: set_collisionObjectPos argument 3 must be object handle.\n");
		return 0;
	}
	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle object = (plCollisionObjectHandle) lua_touserdata(L,3);

   	btVector3 pos = getVector3(L,4);
	plSetCollisionObjectPosition( sdk_handle, world_handle, object, pos);
	return 0;
}
//sdk,world,object,rot
static int
lset_collisionObjectRot( lua_State *L)
{
	if( !check_sdk_world_handle(L,1,2,"lset_collisionObjectRot"))
		return 0;
	if( !lua_isuserdata(L,3)) {
		luaL_error(L,"error: lset_collisionObjectRot argument 3 must be object handle.\n");
		return 0;
	}
	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle object = (plCollisionObjectHandle) lua_touserdata(L,3);

   	btQuaternion rot = getQuaternion(L,4);
	plSetCollisionObjectRotation( sdk_handle, world_handle, object, rot);

	return 0;
}

static int 
ladd_collisionObject( lua_State *L ) 
{
	if( !check_sdk_world_handle(L,1,2,"add_collisionObject") )
		return 0;
	if( !lua_isuserdata(L,3) ) {
		luaL_error(L,"error: add_collisionObject argument 3 must be object handle.\n");
		return 0;
	}

	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle object = (plCollisionObjectHandle) lua_touserdata(L,3);
#ifdef __DEBUG_OUTPUT_
	printf("add object(%d) to world(%d).\n",object->unused, world_handle->unused);
#endif 
	plAddCollisionObject( sdk_handle,world_handle, object );

	return 0;
}


// = 40k contact points 
#define  POINT_CAPACITY  1000
const int POINTS = 100;

#define SET_FIELD_VALUE(L,key,value) \
	lua_pushnumber(L,value); \
	lua_setfield(L,-2,key);

void return_contact_points( lua_State *L, int numPoints,lwContactPoint *ctPoints )
{
	lua_newtable(L);
	for(int i = 0;i<numPoints;i++ ) {
		lua_pushinteger(L,i+1);
		lua_newtable(L);

		lua_pushstring(L,"ptOnAWorld");   
		lua_newtable(L); {
			SET_FIELD_VALUE(L,"x",ctPoints[i].m_ptOnAWorld[0] );
			SET_FIELD_VALUE(L,"y",ctPoints[i].m_ptOnAWorld[1] );
			SET_FIELD_VALUE(L,"z",ctPoints[i].m_ptOnAWorld[2] );
		}
		lua_settable(L,-3);

		lua_pushstring(L,"ptOnBWorld");
		lua_newtable(L); {
			SET_FIELD_VALUE(L,"x",ctPoints[i].m_ptOnBWorld[0] );
			SET_FIELD_VALUE(L,"y",ctPoints[i].m_ptOnBWorld[1] );
			SET_FIELD_VALUE(L,"z",ctPoints[i].m_ptOnBWorld[2] );
		}
		lua_settable(L,-3);

		lua_pushstring(L,"normalOnB");
		lua_newtable(L); {
			SET_FIELD_VALUE(L,"x",ctPoints[i].m_normalOnB[0] );
			SET_FIELD_VALUE(L,"y",ctPoints[i].m_normalOnB[1] );
			SET_FIELD_VALUE(L,"z",ctPoints[i].m_normalOnB[2] );
		}
		lua_settable(L,-3);

		SET_FIELD_VALUE(L,"distance",ctPoints[i].m_distance );

		lua_settable(L,-3);
	}
}

// --- query and collision action ---
// sdk,world, objA handle,objB handle ( pointsOut, ) 
// return numContactPoints,ContactPoints Array 
static int 
lcollide( lua_State *L) {

	int 		   numContactPoints = 0;
	lwContactPoint ctPoints[ POINT_CAPACITY ];

	if( !check_sdk_world_handle(L,1,2,"collide") )
		return 0;
	if( !lua_isuserdata(L,3) ) {
		luaL_error(L,"error: collide argument 3 must be object handle.\n");
		return 0;
	}
	if( !lua_isuserdata(L,4) ) {
		luaL_error(L,"error: collide argument 4 must be object handle.\n");
		return 0;
	}

	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);
	plCollisionObjectHandle objectA = (plCollisionObjectHandle) lua_touserdata(L,3);
	plCollisionObjectHandle objectB = (plCollisionObjectHandle) lua_touserdata(L,4);

	numContactPoints = plCollide( sdk_handle, world_handle, objectA, objectB, ctPoints ,POINT_CAPACITY );

	if( numContactPoints > 0 ) {
		// collect contact points ,return as table array
		// numContactPoints, table = { lwContactPoint1,lwContactPoint2,... }
#ifdef __DEBUG_OUTPUT_		
		printf("Collide find  %d contact points.\n",numContactPoints );
#endif
		lua_pushnumber(L,numContactPoints);
		return_contact_points(L,numContactPoints,ctPoints);
		return 2;
	} else {
#ifdef __DEBUG_OUTPUT_				
		printf("Collide can not find any contact point.\n");
#endif 		
	}
	lua_pushnumber(L,0);
	lua_pushnil(L);
	return 2;
}


// Need callback function. 
// this callback use for world objects collide, and return all result. special function
// bullet sdk warp callback using global function，
// attempt to avoid global status variables,but bullet system callback limit, 最后一层仍旧是全局函数 :(
// 需要时，考虑指针使之和sdk，world 关联，支持多 vm 
// 出了结果数据外，bullet 这部分对外实现，还有隐藏的全局变量,因此... 
int totalPoints  = 0;
int numCallbacks = 0;
lwContactPoint ctPoints[ POINT_CAPACITY ];
void checkCollide_Callback( plCollisionSdkHandle sdk, plCollisionWorldHandle world, void* userData, plCollisionObjectHandle objectA, plCollisionObjectHandle objectB)
{
	numCallbacks ++;
	int remainingCapacity = POINT_CAPACITY - totalPoints;
#ifdef __DEBUG_OUTPUT_	
	printf("do collision turn remaining capacity %d\n", remainingCapacity );
#endif	
	if(remainingCapacity> 0) {
		lwContactPoint *pointPtr = &ctPoints[ totalPoints ];
		int numPoints = plCollide(sdk,world,objectA,objectB,pointPtr,remainingCapacity);
		btAssert( numPoints <= remainingCapacity );
		totalPoints += numPoints;
#ifdef __DEBUG_OUTPUT_		
		printf("do collision turn %d\n",numCallbacks);
#endif 
	}
}

// sdk,world,objA,objB,user id or void *userdata,check counter
// return totalPoints, contactPoints table 
static int 
lworldCollide( lua_State *L) 
{
	// check totalPoints value, make result table
	if( !check_sdk_world_handle(L,1,2,"worldCollide"))	
		return 0;
	
	totalPoints = 0;
	numCallbacks = 0;
	void *userPtr = nullptr;

	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);

	plWorldCollide( sdk_handle,world_handle, checkCollide_Callback,userPtr);

	if(totalPoints>0) 
	{
		// do result table construct
#ifdef __DEBUG_OUTPUT_		
		printf("world collide find %d contack points.\n",totalPoints);
#endif		
		lua_pushnumber(L, totalPoints );
		return_contact_points(L, totalPoints, ctPoints );
		return 2;
	} else {
#ifdef __DEBUG_OUTPUT_		
		printf("can not find contact points, totalPoints(%d).\n",totalPoints );
#endif 		
	}
	// not contact points
	lua_pushnumber(L,0);
	lua_pushnil(L);
	return 2;
}


void return_rayhit_info( lua_State *L, ClosestRayResult &result )
{
	lua_newtable(L);
	SET_FIELD_VALUE(L,"hitObjId",result.m_hitObjId);
	SET_FIELD_VALUE(L,"hitFraction",result.m_hitFraction);
	SET_FIELD_VALUE(L,"filterGroup",result.m_filterGroup);
	SET_FIELD_VALUE(L,"filterMask",result.m_filterMask);
	SET_FIELD_VALUE(L,"flags",result.m_flags);


	lua_pushstring(L,"hitPointWorld");   // hitpoint table name
	lua_newtable(L); {
		SET_FIELD_VALUE(L,"x",result.m_hitPointWorld[0]);
		SET_FIELD_VALUE(L,"y",result.m_hitPointWorld[1]);
		SET_FIELD_VALUE(L,"z",result.m_hitPointWorld[2]);
	}
	lua_settable(L,-3);

	lua_pushstring(L,"hitNormalWorld");   // hitpoint table name
	lua_newtable(L); {
		SET_FIELD_VALUE(L,"x",result.m_hitNormalWorld[0]);
		SET_FIELD_VALUE(L,"y",result.m_hitNormalWorld[1]);
		SET_FIELD_VALUE(L,"z",result.m_hitNormalWorld[2]);
	}
	lua_settable(L,-3);
}

//---------- raycast ------------------------
static int 
lraycast( lua_State *L ) {
	if( !check_sdk_world_handle(L,1,2,"raycast") )
		return 0;
	plCollisionSdkHandle sdk_handle = (plCollisionSdkHandle) lua_touserdata(L,1);
	plCollisionWorldHandle world_handle = (plCollisionWorldHandle) lua_touserdata(L,2);

   	btVector3 rayFrom = getVector3(L,3);
	btVector3 rayTo = getVector3(L,4);

	ClosestRayResult result;
	memset(&result,0x0,sizeof(result));
	if( plRaycast(sdk_handle,world_handle,rayFrom,rayTo,result ) ) {
		// check result and return to lua
#ifdef __DEBUG_OUTPUT_		
		(void)(result);  
		printf("raycast hit object.\n");
#endif 
		// ishit, hitInfo 
		lua_pushboolean(L,1);
		return_rayhit_info(L,result);
		return 2;
	}
#ifdef __DEBUG_OUTPUT_	
	printf("raycast do not hit something.\n");	
#endif 
	// ishit, hitInfo 
	lua_pushboolean(L,0);
	lua_pushnil(L);
	return 2;
}

static int
lstep_simulator( lua_State *L) {
	return 1;
}

// export physics api framework ...
LUAMOD_API int
luaopen_lbullet(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init_physics",linit_physics},
		{ "exit_physics",lexit_physics},
		{ "create_world", lcreate_world},
		{ "destroy_world", ldestroy_world},
		{ "create_planeShape",lcreate_planeShape},
		{ "create_cubeShape",lcreate_cubeShape},
		{ "create_sphereShape",lcreate_sphereShape},
		{ "create_capsuleShape",lcreate_capsuleShape},
		{ "create_cylinderShape",lcreate_cylinderShape},
		{ "create_compoundShape",lcreate_compoundShape},
		{ "add_shapeToCompound",ladd_shapeToCompound},
		{ "delete_shape",ldelete_shape},
		{ "add_shapeToWorld",ladd_shapeToWorld},
		{ "delete_shapeFromWorld",ldelete_shapeFromWorld},
		{ "create_collisionObject",lcreate_collisionObject},
		{ "delete_collisionObject",ldelete_collisionObject},
		{ "set_collisionObjectTransform",lset_collisionObjectTransform},
		{ "set_collisionObjectTM",lset_collisionObjectTransform},
		{ "set_collisionObjectPos",lset_collisionObjectPos},
		{ "set_collisionObjectPosition",lset_collisionObjectPos},
		{ "set_collisionObjectRot",lset_collisionObjectRot},
		{ "set_collisionObjectRotation",lset_collisionObjectRot},
		{ "add_collisionObject",ladd_collisionObject},
		{ "collide",lcollide},
		{ "worldCollide",lworldCollide},
		{ "raycast",lraycast},
		{ "step_simulator",lstep_simulator},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}

#ifdef __cplusplus
}
#endif



