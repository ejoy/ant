/*
* UNIVERSE.H
*/
#ifndef UNIVERSE_H
#define UNIVERSE_H

#include "lua.h"
#include "threading.h"
// MUTEX_T

// ################################################################################################

/*
* Do we want to activate full lane tracking feature? (EXPERIMENTAL)
*/
#define HAVE_LANE_TRACKING 1

// ################################################################################################

// everything regarding the a Lanes universe is stored in that global structure
// held as a full userdata in the master Lua state that required it for the first time
// don't forget to initialize all members in LG_configure()
struct s_Universe
{
	// for verbose errors
	bool_t verboseErrors;

	lua_CFunction on_state_create_func;

	struct s_Keepers* keepers;

	// Initialized by 'init_once_LOCKED()': the deep userdata Linda object
	// used for timers (each lane will get a proxy to this)
	volatile struct DEEP_PRELUDE* timer_deep;  // = NULL

#if HAVE_LANE_TRACKING
	MUTEX_T tracking_cs;
	struct s_lane* volatile tracking_first; // will change to TRACKING_END if we want to activate tracking
#endif // HAVE_LANE_TRACKING

	MUTEX_T selfdestruct_cs;

	// require() serialization
	MUTEX_T require_cs;

	// Lock for reference counter inc/dec locks (to be initialized by outside code) TODO: get rid of this and use atomics instead!
	MUTEX_T deep_lock;
	MUTEX_T mtid_lock;

	int last_mt_id;

#if USE_DEBUG_SPEW
	int debugspew_indent_depth;
#endif // USE_DEBUG_SPEW

	struct s_lane* volatile selfdestruct_first;
	// After a lane has removed itself from the chain, it still performs some processing.
	// The terminal desinit sequence should wait for all such processing to terminate before force-killing threads
	int volatile selfdestructing_count;
};

struct s_Universe* universe_get( lua_State* L);
struct s_Universe* universe_create( lua_State* L);
void universe_store( lua_State* L, struct s_Universe* U);

#endif // UNIVERSE_H
