/*
 * DEEP.C                         Copyright (c) 2017, Benoit Germain
 *
 * Deep userdata support, separate in its own source file to help integration
 * without enforcing a Lanes dependency
 */

/*
===============================================================================

Copyright (C) 2002-10 Asko Kauppi <akauppi@gmail.com>
              2011-17 Benoit Germain <bnt.germain@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

===============================================================================
*/

#include "compat.h"
#include "tools.h"
#include "universe.h"
#include "deep.h"

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#if !defined(__APPLE__)
#include <malloc.h>
#endif

/*-- Metatable copying --*/

/*
 * 'reg[ REG_MT_KNOWN ]'= {
 *      [ table ]= id_uint,
 *          ...
 *      [ id_uint ]= table,
 *          ...
 * }
 */

/*
* Does what the original 'push_registry_subtable' function did, but adds an optional mode argument to it
*/
void push_registry_subtable_mode( lua_State* L, void* key_, const char* mode_)
{
	STACK_GROW( L, 3);
	STACK_CHECK( L);

	lua_pushlightuserdata( L, key_);                      // key
	lua_rawget( L, LUA_REGISTRYINDEX);                    // {}|nil

	if( lua_isnil( L, -1))
	{
		lua_pop( L, 1);                                     //
		lua_newtable( L);                                   // {}
		lua_pushlightuserdata( L, key_);                    // {} key
		lua_pushvalue( L, -2);                              // {} key {}

		// _R[key_] = {}
		lua_rawset( L, LUA_REGISTRYINDEX);                  // {}

		// Set its metatable if requested
		if( mode_)
		{
			lua_newtable( L);                                 // {} mt
			lua_pushliteral( L, "__mode");                    // {} mt "__mode"
			lua_pushstring( L, mode_);                        // {} mt "__mode" mode
			lua_rawset( L, -3);                               // {} mt
			lua_setmetatable( L, -2);                         // {}
		}
	}
	STACK_END( L, 1);
	ASSERT_L( lua_istable( L, -1));
}


/*
* Push a registry subtable (keyed by unique 'key_') onto the stack.
* If the subtable does not exist, it is created and chained.
*/
void push_registry_subtable( lua_State* L, void* key_)
{
	push_registry_subtable_mode( L, key_, NULL);
}


/*---=== Deep userdata ===---*/

void luaG_pushdeepversion( lua_State* L) { (void) lua_pushliteral( L, "ab8743e5-84f8-485d-9c39-008e84656188");}



/* The deep portion must be allocated separately of any Lua state's; it's
* lifespan may be longer than that of the creating state.
*/
#define DEEP_MALLOC malloc
#define DEEP_FREE   free

/* 
* 'registry[REGKEY]' is a two-way lookup table for 'idfunc's and those type's
* metatables:
*
*   metatable   ->  idfunc
*   idfunc      ->  metatable
*/
// crc64/we of string "DEEP_LOOKUP_KEY" generated at https://www.nitrxgen.net/hashgen/
#define DEEP_LOOKUP_KEY ((void*)0x9fb9b4f3f633d83d)


/*
 * The deep proxy cache is a weak valued table listing all deep UD proxies indexed by the deep UD that they are proxying
 * crc64/we of string "DEEP_PROXY_CACHE_KEY" generated at https://www.nitrxgen.net/hashgen/
*/
#define DEEP_PROXY_CACHE_KEY ((void*)0x05773d6fc26be106)

/*
* Sets up [-1]<->[-2] two-way lookups, and ensures the lookup table exists.
* Pops the both values off the stack.
*/
static void set_deep_lookup( lua_State* L)
{
	STACK_GROW( L, 3);
	STACK_CHECK( L);                                         // a b
	push_registry_subtable( L, DEEP_LOOKUP_KEY);             // a b {}
	STACK_MID( L, 1);
	lua_insert( L, -3);                                      // {} a b
	lua_pushvalue( L, -1);                                   // {} a b b
	lua_pushvalue( L,-3);                                    // {} a b b a
	lua_rawset( L, -5);                                      // {} a b
	lua_rawset( L, -3);                                      // {}
	lua_pop( L, 1);                                          //
	STACK_END( L, -2);
}

/*
* Pops the key (metatable or idfunc) off the stack, and replaces with the
* deep lookup value (idfunc/metatable/nil).
*/
static void get_deep_lookup( lua_State* L)
{
	STACK_GROW( L, 1);
	STACK_CHECK( L);                                         // a
	lua_pushlightuserdata( L, DEEP_LOOKUP_KEY);              // a DLK
	lua_rawget( L, LUA_REGISTRYINDEX);                       // a {}

	if( !lua_isnil( L, -1))
	{
		lua_insert( L, -2);                                    // {} a
		lua_rawget( L, -2);                                    // {} b
	}
	lua_remove( L, -2);                                      // a|b
	STACK_END( L, 0);
}

/*
* Return the registered ID function for 'index' (deep userdata proxy),
* or NULL if 'index' is not a deep userdata proxy.
*/
static inline luaG_IdFunction get_idfunc( lua_State* L, int index, enum eLookupMode mode_)
{
	// when looking inside a keeper, we are 100% sure the object is a deep userdata
	if( mode_ == eLM_FromKeeper)
	{
		struct DEEP_PRELUDE** proxy = (struct DEEP_PRELUDE**) lua_touserdata( L, index);
		// we can (and must) cast and fetch the internally stored idfunc
		return (*proxy)->idfunc;
	}
	else
	{
		// essentially we are making sure that the metatable of the object we want to copy is stored in our metatable/idfunc database
		// it is the only way to ensure that the userdata is indeed a deep userdata!
		// of course, we could just trust the caller, but we won't
		luaG_IdFunction ret;
		STACK_GROW( L, 1);
		STACK_CHECK( L);

		if( !lua_getmetatable( L, index))       // deep ... metatable?
		{
			return NULL;    // no metatable: can't be a deep userdata object!
		}

		// replace metatable with the idfunc pointer, if it is actually a deep userdata
		get_deep_lookup( L);                    // deep ... idfunc|nil

		ret = (luaG_IdFunction) lua_touserdata( L, -1); // NULL if not a userdata
		lua_pop( L, 1);
		STACK_END( L, 0);
		return ret;
	}
}


void free_deep_prelude( lua_State* L, struct DEEP_PRELUDE* prelude_)
{
	// Call 'idfunc( "delete", deep_ptr )' to make deep cleanup
	lua_pushlightuserdata( L, prelude_->deep);
	ASSERT_L( prelude_->idfunc);
	prelude_->idfunc( L, eDO_delete);
	DEEP_FREE( (void*) prelude_);
}


/*
 * void= mt.__gc( proxy_ud )
 *
 * End of life for a proxy object; reduce the deep reference count and clean it up if reaches 0.
 *
 */
static int deep_userdata_gc( lua_State* L)
{
	struct DEEP_PRELUDE** proxy = (struct DEEP_PRELUDE**) lua_touserdata( L, 1);
	struct DEEP_PRELUDE* p = *proxy;
	struct s_Universe* U = universe_get( L);
	int v;

	// can work without a universe if creating a deep userdata from some external C module when Lanes isn't loaded
	// in that case, we are not multithreaded and locking isn't necessary anyway
	if( U) MUTEX_LOCK( &U->deep_lock);
	v = -- (p->refcount);
	if (U) MUTEX_UNLOCK( &U->deep_lock);

	if( v == 0)
	{
		// retrieve wrapped __gc
		lua_pushvalue( L, lua_upvalueindex( 1));                            // self __gc?
		if( !lua_isnil( L, -1))
		{
			lua_insert( L, -2);                                               // __gc self
			lua_call( L, 1, 0);                                               //
		}
		// 'idfunc' expects a clean stack to work on
		lua_settop( L, 0);
		free_deep_prelude( L, p);

		// top was set to 0, then userdata was pushed. "delete" might want to pop the userdata (we don't care), but should not push anything!
		if ( lua_gettop( L) > 1)
		{
			luaL_error( L, "Bad idfunc(eDO_delete): should not push anything");
		}
	}
	*proxy = NULL;  // make sure we don't use it any more, just in case
	return 0;
}


/*
 * Push a proxy userdata on the stack.
 * returns NULL if ok, else some error string related to bad idfunc behavior or module require problem
 * (error cannot happen with mode_ == eLM_ToKeeper)
 *
 * Initializes necessary structures if it's the first time 'idfunc' is being
 * used in this Lua state (metatable, registring it). Otherwise, increments the
 * reference count.
 */
char const* push_deep_proxy( struct s_Universe* U, lua_State* L, struct DEEP_PRELUDE* prelude, enum eLookupMode mode_)
{
	struct DEEP_PRELUDE** proxy;

	// Check if a proxy already exists
	push_registry_subtable_mode( L, DEEP_PROXY_CACHE_KEY, "v");                                        // DPC
	lua_pushlightuserdata( L, prelude->deep);                                                          // DPC deep
	lua_rawget( L, -2);                                                                                // DPC proxy
	if ( !lua_isnil( L, -1))
	{
		lua_remove( L, -2);                                                                              // proxy
		return NULL;
	}
	else
	{
		lua_pop( L, 1);                                                                                  // DPC
	}

	// can work without a universe if creating a deep userdata from some external C module when Lanes isn't loaded
	// in that case, we are not multithreaded and locking isn't necessary anyway
	if( U) MUTEX_LOCK( &U->deep_lock);
	++ (prelude->refcount);  // one more proxy pointing to this deep data
	if( U) MUTEX_UNLOCK( &U->deep_lock);

	STACK_GROW( L, 7);
	STACK_CHECK( L);

	proxy = lua_newuserdata( L, sizeof(struct DEEP_PRELUDE*));                                         // DPC proxy
	ASSERT_L( proxy);
	*proxy = prelude;

	// Get/create metatable for 'idfunc' (in this state)
	lua_pushlightuserdata( L, prelude->idfunc);                                                        // DPC proxy idfunc
	get_deep_lookup( L);                                                                               // DPC proxy metatable?

	if( lua_isnil( L, -1)) // // No metatable yet.
	{
		char const* modname;
		int oldtop = lua_gettop( L);                                                                     // DPC proxy nil
		lua_pop( L, 1);                                                                                  // DPC proxy
		// 1 - make one and register it
		if( mode_ != eLM_ToKeeper)
		{
			(void) prelude->idfunc( L, eDO_metatable);                                                     // DPC proxy metatable deepversion
			if( lua_gettop( L) - oldtop != 1 || !lua_istable( L, -2) || !lua_isstring( L, -1))
			{
				lua_settop( L, oldtop);                                                                      // DPC proxy X
				lua_pop( L, 3);                                                                              //
				return "Bad idfunc(eOP_metatable): unexpected pushed value";
			}
			luaG_pushdeepversion( L);                                                                      // DPC proxy metatable deepversion deepversion
			if( !lua501_equal( L, -1, -2))
			{
				lua_pop( L, 5);                                                                              //
				return "Bad idfunc(eOP_metatable): mismatched deep version";
			}
			lua_pop( L, 2);                                                                                // DPC proxy metatable
			// if the metatable contains a __gc, we will call it from our own
			lua_getfield( L, -1, "__gc");                                                                  // DPC proxy metatable __gc
		}
		else
		{
			// keepers need a minimal metatable that only contains our own __gc
			lua_newtable( L);                                                                              // DPC proxy metatable
			lua_pushnil( L);                                                                               // DPC proxy metatable nil
		}
		if (lua_isnil(L, -1))
		{
			// Add our own '__gc' method
			lua_pop( L, 1);                                                                                // DPC proxy metatable
			lua_pushcfunction( L, deep_userdata_gc);                                                       // DPC proxy metatable deep_userdata_gc
		}
		else
		{
			// Add our own '__gc' method wrapping the original
			lua_pushcclosure( L, deep_userdata_gc, 1);                                                     // DPC proxy metatable deep_userdata_gc
		}
		lua_setfield( L, -2, "__gc");                                                                    // DPC proxy metatable

		// Memorize for later rounds
		lua_pushvalue( L, -1);                                                                           // DPC proxy metatable metatable
		lua_pushlightuserdata( L, prelude->idfunc);                                                      // DPC proxy metatable metatable idfunc
		set_deep_lookup( L);                                                                             // DPC proxy metatable

		// 2 - cause the target state to require the module that exported the idfunc
		// this is needed because we must make sure the shared library is still loaded as long as we hold a pointer on the idfunc
		{
			int oldtop = lua_gettop( L);
			modname = (char const*) prelude->idfunc( L, eDO_module);                                       // DPC proxy metatable
			// make sure the function pushed nothing on the stack!
			if( lua_gettop( L) - oldtop != 0)
			{
				lua_pop( L, 3);                                                                              //
				return "Bad idfunc(eOP_module): should not push anything";
			}
		}
		if( NULL != modname) // we actually got a module name
		{
			// somehow, L.registry._LOADED can exist without having registered the 'package' library.
			lua_getglobal( L, "require");                                                                  // DPC proxy metatable require()
			// check that the module is already loaded (or being loaded, we are happy either way)
			if( lua_isfunction( L, -1))
			{
				lua_pushstring( L, modname);                                                                 // DPC proxy metatable require() "module"
				lua_getfield( L, LUA_REGISTRYINDEX, "_LOADED");                                              // DPC proxy metatable require() "module" _R._LOADED
				if( lua_istable( L, -1))
				{
					bool_t alreadyloaded;
					lua_pushvalue( L, -2);                                                                     // DPC proxy metatable require() "module" _R._LOADED "module"
					lua_rawget( L, -2);                                                                        // DPC proxy metatable require() "module" _R._LOADED module
					alreadyloaded = lua_toboolean( L, -1);
					if( !alreadyloaded) // not loaded
					{
						int require_result;
						lua_pop( L, 2);                                                                          // DPC proxy metatable require() "module"
						// require "modname"
						require_result = lua_pcall( L, 1, 0, 0);                                                 // DPC proxy metatable error?
						if( require_result != LUA_OK)
						{
							// failed, return the error message
							lua_pushfstring( L, "error while requiring '%s' identified by idfunc(eOP_module): ", modname);
							lua_insert( L, -2);                                                                    // DPC proxy metatable prefix error
							lua_concat( L, 2);                                                                     // DPC proxy metatable error
							return lua_tostring( L, -1);
						}
					}
					else // already loaded, we are happy
					{
						lua_pop( L, 4);                                                                          // DPC proxy metatable
					}
				}
				else // no L.registry._LOADED; can this ever happen?
				{
					lua_pop( L, 6);                                                                            //
					return "unexpected error while requiring a module identified by idfunc(eOP_module)";
				}
			}
			else // a module name, but no require() function :-(
			{
				lua_pop( L, 4);                                                                              //
				return "lanes receiving deep userdata should register the 'package' library";
			}
		}
	}
	STACK_MID( L, 2);                                                                                  // DPC proxy metatable
	ASSERT_L( lua_isuserdata( L, -2));
	ASSERT_L( lua_istable( L, -1));
	lua_setmetatable( L, -2);                                                                          // DPC proxy

	// If we're here, we obviously had to create a new proxy, so cache it.
	lua_pushlightuserdata( L, (*proxy)->deep);                                                         // DPC proxy deep
	lua_pushvalue( L, -2);                                                                             // DPC proxy deep proxy
	lua_rawset( L, -4);                                                                                // DPC proxy
	lua_remove( L, -2);                                                                                // proxy
	ASSERT_L( lua_isuserdata( L, -1));
	STACK_END( L, 0);
	return NULL;
}

/*
* Create a deep userdata
*
*   proxy_ud= deep_userdata( idfunc [, ...] )
*
* Creates a deep userdata entry of the type defined by 'idfunc'.
* Other parameters are passed on to the 'idfunc' "new" invocation.
*
* 'idfunc' must fulfill the following features:
*
*   lightuserdata = idfunc( eDO_new [, ...] )      -- creates a new deep data instance
*   void = idfunc( eDO_delete, lightuserdata )     -- releases a deep data instance
*   tbl = idfunc( eDO_metatable )                  -- gives metatable for userdata proxies
*
* Reference counting and true userdata proxying are taken care of for the
* actual data type.
*
* Types using the deep userdata system (and only those!) can be passed between
* separate Lua states via 'luaG_inter_move()'.
*
* Returns:  'proxy' userdata for accessing the deep data via 'luaG_todeep()'
*/
int luaG_newdeepuserdata( lua_State* L, luaG_IdFunction idfunc)
{
	char const* errmsg;
	struct DEEP_PRELUDE* prelude = DEEP_MALLOC( sizeof(struct DEEP_PRELUDE));
	if( prelude == NULL)
	{
		return luaL_error( L, "couldn't not allocate deep prelude: out of memory");
	}

	prelude->refcount = 0; // 'push_deep_proxy' will lift it to 1
	prelude->idfunc = idfunc;

	STACK_GROW( L, 1);
	STACK_CHECK( L);
	{
		int oldtop = lua_gettop( L);
		prelude->deep = idfunc( L, eDO_new);
		if( prelude->deep == NULL)
		{
			luaL_error( L, "idfunc(eDO_new) failed to create deep userdata (out of memory)");
		}

		if( lua_gettop( L) - oldtop != 0)
		{
			luaL_error( L, "Bad idfunc(eDO_new): should not push anything on the stack");
		}
	}
	errmsg = push_deep_proxy( universe_get( L), L, prelude, eLM_LaneBody);  // proxy
	if( errmsg != NULL)
	{
		luaL_error( L, errmsg);
	}
	STACK_END( L, 1);
	return 1;
}


/*
* Access deep userdata through a proxy.
*
* Reference count is not changed, and access to the deep userdata is not
* serialized. It is the module's responsibility to prevent conflicting usage.
*/
void* luaG_todeep( lua_State* L, luaG_IdFunction idfunc, int index)
{
	struct DEEP_PRELUDE** proxy;

	STACK_CHECK( L);
	// ensure it is actually a deep userdata
	if( get_idfunc( L, index, eLM_LaneBody) != idfunc)
	{
		return NULL;    // no metatable, or wrong kind
	}

	proxy = (struct DEEP_PRELUDE**) lua_touserdata( L, index);
	STACK_END( L, 0);

	return (*proxy)->deep;
}


/*
 * Copy deep userdata between two separate Lua states (from L to L2)
 *
 * Returns:
 *   the id function of the copied value, or NULL for non-deep userdata
 *   (not copied)
 */
luaG_IdFunction copydeep( struct s_Universe* U, lua_State* L, lua_State* L2, int index, enum eLookupMode mode_)
{
	char const* errmsg;
	luaG_IdFunction idfunc = get_idfunc( L, index, mode_);
	if( idfunc == NULL)
	{
		return NULL;   // not a deep userdata
	}

	errmsg = push_deep_proxy( U, L2, *(struct DEEP_PRELUDE**) lua_touserdata( L, index), mode_);
	if( errmsg != NULL)
	{
		// raise the error in the proper state (not the keeper)
		lua_State* errL = (mode_ == eLM_FromKeeper) ? L2 : L;
		luaL_error( errL, errmsg);
	}
	return idfunc;
}
