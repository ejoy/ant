/*
 * MACROS_AND_UTILS.H
 */
#ifndef MACROS_AND_UTILS_H
#define MACROS_AND_UTILS_H

#include "lua.h"

 // M$ compiler doesn't support 'inline' keyword in C files...
#if defined( _MSC_VER)
#define inline __inline
#endif

 // For some reason, LuaJIT 64bits doesn't support lua_newstate()
#if defined(LUA_JITLIBNAME) && (defined(__x86_64__) || defined(_M_X64))
 //#pragma message( "LuaJIT 64 bits detected: don't propagate allocf")
#define PROPAGATE_ALLOCF 0
#else // LuaJIT x64
 //#pragma message( "PUC-Lua detected: propagate allocf")
#define PROPAGATE_ALLOCF 1
#endif // LuaJIT x64
#if PROPAGATE_ALLOCF
#define PROPAGATE_ALLOCF_PREP( L) void* allocUD; lua_Alloc allocF = lua_getallocf( L, &allocUD)
#define PROPAGATE_ALLOCF_ALLOC() lua_newstate( allocF, allocUD)
#else // PROPAGATE_ALLOCF
#define PROPAGATE_ALLOCF_PREP( L)
#define PROPAGATE_ALLOCF_ALLOC() luaL_newstate()
#endif // PROPAGATE_ALLOCF

#define USE_DEBUG_SPEW 0
#if USE_DEBUG_SPEW
extern char const* debugspew_indent;
#define INDENT_BEGIN "%.*s "
#define INDENT_END , (U ? U->debugspew_indent_depth : 0), debugspew_indent
#define DEBUGSPEW_CODE(_code) _code
#else // USE_DEBUG_SPEW
#define DEBUGSPEW_CODE(_code)
#endif // USE_DEBUG_SPEW

#ifdef NDEBUG

#define _ASSERT_L(lua,c)  /*nothing*/
#define STACK_CHECK(L)    /*nothing*/
#define STACK_MID(L,c)    /*nothing*/
#define STACK_END(L,c)    /*nothing*/
#define STACK_DUMP(L)    /*nothing*/

#else // NDEBUG

#define _ASSERT_L( L, cond_) if( (cond_) == 0) { (void) luaL_error( L, "ASSERT failed: %s:%d '%s'", __FILE__, __LINE__, #cond_);}

#define STACK_CHECK(L)     { int const _oldtop_##L = lua_gettop( L)
#define STACK_MID(L,change) \
	do \
	{ \
		int a = lua_gettop( L) - _oldtop_##L; \
		int b = (change); \
		if( a != b) \
			luaL_error( L, "STACK ASSERT failed (%d not %d): %s:%d", a, b, __FILE__, __LINE__ ); \
	} while( 0)
#define STACK_END(L,change)  STACK_MID(L,change); }

#define STACK_DUMP( L)    luaG_dump( L)

#endif // NDEBUG

#define ASSERT_L(c) _ASSERT_L(L,c)

#define STACK_GROW( L, n) do { if (!lua_checkstack(L,(int)(n))) luaL_error( L, "Cannot grow stack!" ); } while( 0)

#endif // MACROS_AND_UTILS_H
