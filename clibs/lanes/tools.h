/*
* TOOLS.H
*/
#ifndef TOOLS_H
#define TOOLS_H

#include "lauxlib.h"
#include "threading.h"
#include "deep.h"
    // MUTEX_T

#include <assert.h>

#include "macros_and_utils.h"

struct s_Universe;

// ################################################################################################

// this is pointed to by full userdata proxies, and allocated with malloc() to survive any lua_State lifetime
struct DEEP_PRELUDE
{
	volatile int refcount;
	void* deep;
	// when stored in a keeper state, the full userdata doesn't have a metatable, so we need direct access to the idfunc
	luaG_IdFunction idfunc;
};

// ################################################################################################

#define LUAG_FUNC( func_name ) static int LG_##func_name( lua_State* L)

#define luaG_optunsigned(L,i,d) ((uint_t) luaL_optinteger(L,i,d))
#define luaG_tounsigned(L,i) ((uint_t) lua_tointeger(L,i))

void luaG_dump( lua_State* L );

lua_State* luaG_newstate( struct s_Universe* U, lua_State* _from, char const* libs);
void luaG_copy_one_time_settings( struct s_Universe* U, lua_State* L, lua_State* L2);

// ################################################################################################

enum eLookupMode
{
	eLM_LaneBody, // send the lane body directly from the source to the destination lane
	eLM_ToKeeper, // send a function from a lane to a keeper state
	eLM_FromKeeper // send a function from a keeper state to a lane
};

char const* push_deep_proxy( struct s_Universe* U, lua_State* L, struct DEEP_PRELUDE* prelude, enum eLookupMode mode_);
void free_deep_prelude( lua_State* L, struct DEEP_PRELUDE* prelude_);

int luaG_inter_copy_package( struct s_Universe* U, lua_State* L, lua_State* L2, int package_idx_, enum eLookupMode mode_);

int luaG_inter_copy( struct s_Universe* U, lua_State* L, lua_State* L2, uint_t n, enum eLookupMode mode_);
int luaG_inter_move( struct s_Universe* U, lua_State* L, lua_State* L2, uint_t n, enum eLookupMode mode_);

int luaG_nameof( lua_State* L);
int luaG_new_require( lua_State* L);

void populate_func_lookup_table( lua_State* L, int _i, char const* _name);
void serialize_require( struct s_Universe* U, lua_State *L);
void initialize_on_state_create( struct s_Universe* U, lua_State* L);
void call_on_state_create( struct s_Universe* U, lua_State* L, lua_State* from_, enum eLookupMode mode_);

// ################################################################################################

extern char const* const CONFIG_REGKEY;
extern char const* const LOOKUP_REGKEY;

#endif // TOOLS_H
