#ifndef __LANES_DEEP_H__
#define __LANES_DEEP_H__ 1

/*
 * public 'deep' API to be used by external modules if they want to implement Lanes-aware userdata
 * said modules will have to link against lanes (it is not really possible to separate the 'deep userdata' implementation from the rest of Lanes)
 */


#include "lua.h"

#if (defined PLATFORM_WIN32) || (defined PLATFORM_POCKETPC)
#define LANES_API __declspec(dllexport)
#else
#define LANES_API
#endif // (defined PLATFORM_WIN32) || (defined PLATFORM_POCKETPC)

enum eDeepOp
{
	eDO_new,
	eDO_delete,
	eDO_metatable,
	eDO_module,
};

typedef void* (*luaG_IdFunction)( lua_State* L, enum eDeepOp op_);

extern LANES_API int luaG_newdeepuserdata( lua_State* L, luaG_IdFunction idfunc);
extern LANES_API void* luaG_todeep( lua_State* L, luaG_IdFunction idfunc, int index);
extern LANES_API void luaG_pushdeepversion( lua_State* L);

#endif // __LANES_DEEP_H__
