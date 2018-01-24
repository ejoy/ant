/* ares_aresolve.c
 *
 * provide asynchronous dns lookup support. This is a companion lib to
 * lsocket, but can also be used without it.
 *
 * Gunnar Zötl <gz@tset.de>, 2013-2015
 * Released under the terms of the MIT license. See file LICENSE for details.
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include "gai_async.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "lua.h"
#include "lauxlib.h"

#if LUA_VERSION_NUM == 501
#define luaL_newlib(L,funcs) lua_newtable(L); luaL_register(L, NULL, funcs)
#define luaL_setfuncs(L,funcs,x) luaL_register(L, NULL, funcs)
#endif

#define ARESOLVER "socket_aresolver"
#define TOSTRING_BUFSIZ 64
#define LSOCKET_INET "inet"
#define LSOCKET_INET6 "inet6"

/* structure for asynch resolver userdata */
typedef struct _aresolver {
	struct gai_request *rq;
} aResolver;

/* ares_checkaResolver
 *
 * Checks whether the item at the index on the lua stack is a userdata of
 * the type ARESOLVER. If so, returns its block address, else
 * throw an error.
 *
 * Arguments:
 * 	L	Lua State
 *	index	stack index where the userdata is expected
 */
static aResolver* ares_checkaResolver(lua_State *L, int index)
{
	aResolver *ares = (aResolver*) luaL_checkudata(L, index, ARESOLVER);
	return ares;
}

/* ares_pushaResolver
 *
 * create a new, empty aResolver userdata, attach its metatable
 * and push it to the stack.
 *
 * Arguments:
 *	L	Lua state
 * 
 * Lua Returns:
 * 	+1	aResolver userdata
 */
static aResolver* ares_pushaResolver(lua_State *L)
{
	aResolver *ares = (aResolver*) lua_newuserdata(L, sizeof(aResolver));
	luaL_getmetatable(L, ARESOLVER);
	lua_setmetatable(L, -2);
	return ares;
}

/*** Housekeeping metamethods ***/

/* ares__gc
 *
 * __gc metamethod for the ares userdata.
 * cancels request if 
 *
 * Arguments:
 *	L	Lua State
 *
 * Lua Stack:
 *	1	aResolver userdata
 */
static int ares__gc(lua_State *L)
{
	aResolver *ares = (aResolver*) lua_touserdata(L, 1);
	void *dummy;
	gai_cancel(ares->rq);
	gai_finalize(ares->rq, (struct addrinfo **) &dummy);
	ares->rq = NULL;

	return 0;
}

/* ares__toString
 *
 * __tostring metamethod for the lsock userdata.
 * Returns a string representation of the aResolver
 *
 * Arguments:
 *	L	Lua State
 *
 * Lua Stack:
 *	1	aResolver userdata
 * 
 * Lua Returns:
 * 	+1	string representation of aResolver userdata
 */
static int ares__toString(lua_State *L)
{
	aResolver *ares = ares_checkaResolver(L, 1);
	lua_pushfstring(L, "%s: %p", ARESOLVER, ares);
	return 1;
}

/* metamethods for the ares userdata
 */
static const luaL_Reg ares_meta[] = {
	{"__gc", ares__gc},
	{"__tostring", ares__toString},
	{0, 0}
};

/*** global helper functions ***/

/* ares_error
 * 
 * pushes nil and an error message onto the lua stack and returns 2
 * 
 * Arguments:
 * 	L	lua State
 * 	msg	error message
 *
 * Returns:
 * 	2 (number of items put on the lua stack)
 */
static int ares_error(lua_State *L, const char *msg)
{
	lua_pushnil(L);
	lua_pushstring(L, msg);
	return 2;
}

/*** aresolver methods ***/

/* ares_poll
 * 
 * checks the status of an asynchronous getaddrinfo request
 * 
 * Arguments:
 * 	L	Lua State
 * 
 * Lua Stack:
 * 	1	the aResolver userdata
 * 
 * Lua Returns:
 * 	+1	true, if the request is complete, false otherwise. nil + error
 *		message if an error occurred.
 */
static int ares_poll(lua_State *L)
{
	aResolver *ares = ares_checkaResolver(L, 1);
	if (!ares->rq)
		return ares_error(L, "invalid request object, has already been finalized.");
	int res = gai_poll(ares->rq);
	if (res >= 0)
		lua_pushboolean(L, res);
	else
		return ares_error(L, strerror(errno));
	return 1;
}

/* ares_cancel
 * 
 * cancels an asynchronous getaddrinfo request
 * 
 * Arguments:
 * 	L	Lua State
 * 
 * Lua Stack:
 * 	1	the aResolver userdata
 * 
 * Lua Returns:
 * 	+1	true, if the cancel request was sent, nil + error message if an
 *		error occurred.
 */
static int ares_cancel(lua_State *L)
{
	aResolver *ares = ares_checkaResolver(L, 1);
	if (!ares->rq)
		return ares_error(L, "invalid request object, has already been finalized.");
	int res = gai_cancel(ares->rq);
	if (res == 0)
		lua_pushboolean(L, 1);
	else
		return ares_error(L, strerror(errno));
	return 1;
}

/* ares_finalize
 * 
 * finalizes an asynchronous getaddrinfo request
 * 
 * Arguments:
 * 	L	Lua State
 * 
 * Lua Stack:
 * 	1	the aResolver userdata
 * 
 * Lua Returns:
 * 	+1	a table of resolved addresses if the request succceeded, nil +
 * 		error message if an error occurred.
 */
static int ares_finalize(lua_State *L)
{
	aResolver *ares = ares_checkaResolver(L, 1);
	struct addrinfo *info;
	char buf[TOSTRING_BUFSIZ];
	if (!ares->rq)
		return ares_error(L, "invalid request object, has already been finalized.");
	int err = gai_finalize(ares->rq, &info);

    if (err != 0) {
		if (info) freeaddrinfo(info);
		return ares_error(L, gai_strerror(err));
	}

	int i = 1;
	lua_newtable(L);
	while (info) {
		if (info->ai_family == AF_INET || info->ai_family == AF_INET6) {
			lua_newtable(L);
			lua_pushliteral(L, "family");
			lua_pushstring(L, info->ai_family == AF_INET ? LSOCKET_INET : LSOCKET_INET6);
			lua_rawset(L, -3);
			lua_pushliteral(L, "addr");
			struct sockaddr *sa = info->ai_addr;
			if (sa->sa_family == AF_INET)
				lua_pushstring(L, inet_ntop(sa->sa_family, (const void*) &((struct sockaddr_in*)sa)->sin_addr, buf, TOSTRING_BUFSIZ));
			else
				lua_pushstring(L, inet_ntop(sa->sa_family, (const void*) &((struct sockaddr_in6*)sa)->sin6_addr, buf, TOSTRING_BUFSIZ));
			lua_rawset(L, -3);
			lua_rawseti(L, -2, i++);
			info = info->ai_next;
		}
		/* silently ignore unknown address families */
	}
	
	freeaddrinfo(info);
	ares->rq = NULL;
	return 1;
}

/* aresolver method list
 */
static const struct luaL_Reg ares_methods [] ={
	{"poll", ares_poll},
	{"cancel", ares_cancel},
	{"finalize", ares_finalize},
	
	{NULL, NULL}
};

/*** constructor (returned when the lib is require()d) ***/

/* _needsnolookup
 * 
 * helper function: checks if the address consists only of chars that
 * make up a valid ip(v4 or v6) address, and thus needs no nslookup.
 * 
 * Arguments:
 * 	addr	address to check
 * 
 * Returns:
 * 	1 if the address consists only of chars that make up a valid ip(v4
 * 	or v6) address, 0 otherwise.
 * 
 * Note: this does not check whether the address is a valid ip address,
 * just whether it consists of chars that make up one.
 */
static int _needsnolookup(const char *addr)
{
	int len = strlen(addr);
	int pfx = strspn(addr, "0123456789.");
	if (pfx != len) {
		pfx = strspn(addr, "0123456789abcdefABCDEF:");
		/* last 2 words may be in dot notation */
		if (addr[pfx] == '.') {
			int lpfx = strrchr(addr, ':') - addr;
			if (lpfx == 0 || lpfx > pfx) return 0;
			pfx = lpfx + 1 + strspn(addr + lpfx + 1, "0123456789.");
		}
	}
	return pfx == len;
}

/* ares_aresolver
 * 
 * starts an asynchronous getaddrinfo request
 * 
 * Arguments:
 * 	L	Lua State
 * 
 * Lua Stack:
 * 	1	the name to resolve
 * 
 * Lua Returns:
 * 	+1	true, if the cancel request was sent, nil + error message if an
 *		error occurred.
 */
static int ares_aresolver(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	aResolver *ares = ares_pushaResolver(L);
	struct addrinfo hint;

	memset(&hint, 0, sizeof(hint));
	hint.ai_family = AF_UNSPEC;
	/* reduce the number of duplicate hits, this makes no difference for
	 * the actual dns resolving.
	 */
	hint.ai_protocol = IPPROTO_TCP;
	hint.ai_socktype = SOCK_STREAM;
	if (_needsnolookup(name))
		hint.ai_flags = AI_NUMERICHOST;

	ares->rq = gai_start(name, 0, &hint);
    if (ares->rq == NULL)
		return ares_error(L, strerror(errno));
	return 1;
}

/* luaopen_async_resolve
 * 
 * open and initialize this library
 */
int luaopen_async_resolver(lua_State *L)
{
	/* add aResolver userdata metatable */
	luaL_newmetatable(L, ARESOLVER);
	luaL_setfuncs(L, ares_meta, 0);
	/* methods */
	lua_pushliteral(L, "__index");
	luaL_newlib(L, ares_methods);
	lua_rawset(L, -3);
	/* type */
	lua_pushliteral(L, "__type");
	lua_pushstring(L, ARESOLVER);
	lua_rawset(L, -3);
	/* cleanup */
	lua_pop(L, 1);

	/* return resolver function instead of a table */
	lua_pushcfunction(L, ares_aresolver);
	return 1;
}
