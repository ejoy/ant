/*
 * UNIVERSE.C                  Copyright (c) 2017, Benoit Germain
 */

/*
===============================================================================

Copyright (C) 2017 Benoit Germain <bnt.germain@gmail.com>

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
#include "macros_and_utils.h"
#include "universe.h"

// crc64/we of string "UNIVERSE_REGKEY" generated at https://www.nitrxgen.net/hashgen/
static void* const UNIVERSE_REGKEY = ((void*)0x9f877b2cf078f17f);

// ################################################################################################

struct s_Universe* universe_create( lua_State* L)
{
	struct s_Universe* U = (struct s_Universe*) lua_newuserdata( L, sizeof(struct s_Universe));    // universe
	memset( U, 0, sizeof( struct s_Universe));
	lua_pushlightuserdata( L, UNIVERSE_REGKEY);                                                    // universe UNIVERSE_REGKEY
	lua_pushvalue( L, -2);                                                                         // universe UNIVERSE_REGKEY universe
	lua_rawset( L, LUA_REGISTRYINDEX);                                                             // universe
	return U;
}

// ################################################################################################

void universe_store( lua_State* L, struct s_Universe* U)
{
	STACK_CHECK( L);
	lua_pushlightuserdata( L, UNIVERSE_REGKEY);
	lua_pushlightuserdata( L, U);
	lua_rawset( L, LUA_REGISTRYINDEX);
	STACK_END( L, 0);
}

// ################################################################################################

struct s_Universe* universe_get( lua_State* L)
{
	struct s_Universe* universe;
	STACK_GROW( L, 2);
	STACK_CHECK( L);
	lua_pushlightuserdata( L, UNIVERSE_REGKEY);
	lua_rawget( L, LUA_REGISTRYINDEX);
	universe = lua_touserdata( L, -1); // NULL if nil
	lua_pop( L, 1);
	STACK_END( L, 0);
	return universe;
}
