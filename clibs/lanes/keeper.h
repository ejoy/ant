#if !defined( __keeper_h__)
#define __keeper_h__ 1

struct s_Keeper
{
	MUTEX_T keeper_cs;
	lua_State* L;
	//int count;
};

struct s_Keepers
{
	int nb_keepers;
	struct s_Keeper keeper_array[1];
};

void init_keepers( struct s_Universe* U, lua_State* L);
void close_keepers( struct s_Universe* U, lua_State* L);

struct s_Keeper* keeper_acquire( struct s_Keepers* keepers_, ptrdiff_t magic_);
#define KEEPER_MAGIC_SHIFT 3
void keeper_release( struct s_Keeper* K);
void keeper_toggle_nil_sentinels( lua_State* L, int val_i_, enum eLookupMode const mode_);
int keeper_push_linda_storage( struct s_Universe* U, lua_State* L, void* ptr_, ptrdiff_t magic_);

#define NIL_SENTINEL ((void*)keeper_toggle_nil_sentinels)

typedef lua_CFunction keeper_api_t;
#define KEEPER_API( _op) keepercall_ ## _op
#define PUSH_KEEPER_FUNC lua_pushcfunction
// lua_Cfunctions to run inside a keeper state (formerly implemented in Lua)
int keepercall_clear( lua_State* L);
int keepercall_send( lua_State* L);
int keepercall_receive( lua_State* L);
int keepercall_receive_batched( lua_State* L);
int keepercall_limit( lua_State* L);
int keepercall_get( lua_State* L);
int keepercall_set( lua_State* L);
int keepercall_count( lua_State* L);

int keeper_call( struct s_Universe* U, lua_State* K, keeper_api_t _func, lua_State* L, void* linda, uint_t starting_index);

#endif // __keeper_h__