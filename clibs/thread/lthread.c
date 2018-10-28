// A simple thread lib for lua

#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "simplequeue.h"
#include "simplelock.h"
#include "simplethread.h"
#include "lseri.h"

#define MAX_CHANNEL 32
#define ERRLOG_QUEUE "errlog"

#if _MSC_VER > 0
#define strdup _strdup
#endif

struct channel {
	const char * name;
	struct simple_queue *queue;
	struct thread_event trigger;
	int lock;	// empty lock
	int blocked;
};

struct boxchannel {
	struct channel *c;
};

struct channel g_channel[MAX_CHANNEL];
LUAMOD_API int luaopen_thread(lua_State *L);

static struct channel *
new_channel_(const char * name) {
	int i;
	for (i=0;i<MAX_CHANNEL;i++) {
		if (g_channel[i].name == NULL) {
			break;
		}
	}
	struct simple_queue * q = (struct simple_queue *)malloc(sizeof(*q));
	simple_queue_init(q);
	struct channel *c = &g_channel[i];
	if (atom_cas_pointer(&c->queue, NULL, q)) {
		thread_event_create(&c->trigger);
		c->blocked = 0;
		spin_lock_init(c);
		// name should be set at last
		atom_sync();
		c->name = strdup(name);
		return c;
	} else {
		simple_queue_destroy(q);
		free(q);
		return NULL;
	}
}

static struct channel *
new_channel(const char * name) {
	for (;;) {
		if (g_channel[MAX_CHANNEL-1].name != NULL) {
			return NULL;
		}
		struct channel *c = new_channel_(name);
		if (c)
			return c;
	}
}

static struct channel *
query_channel(const char *name) {
	int i;
	for (i=0;i<MAX_CHANNEL;i++) {
		if (g_channel[i].name == NULL) {
			return NULL;
		}
		if (strcmp(g_channel[i].name, name)==0) {
			return &g_channel[i];
		}
	}
	return NULL;
}

static int
lnewchannel(lua_State *L) {
	const char * name = luaL_checkstring(L, 1);
	struct channel * c = new_channel(name);
	if (c == NULL)
		return luaL_error(L, "Can't create channel %s", name);
	struct channel * q = query_channel(name);
	if (q != c)
		return luaL_error(L, "Duplicate channel %s", name);
	return 0;
}

static void
push_channel(struct channel *c, struct simple_queue_slot *slot) {
	simple_queue_push(c->queue, slot);
	spin_lock(c);
	// trigger iif blocked > 0
	if (c->blocked > 0) {
		thread_event_trigger(&c->trigger);
		--c->blocked;
	}
	spin_unlock(c);
}

static int
lpush(lua_State *L) {
	struct boxchannel * bc = luaL_checkudata(L, 1, "THREAD_CHANNEL");
	struct channel *c = bc->c;
	void * buffer = seri_pack(L, 1);
	struct simple_queue_slot slot = { buffer };
	push_channel(c, &slot);
	return 0;
}

static int
lblockedpop(lua_State *L) {
	struct boxchannel * bc = luaL_checkudata(L, 1, "THREAD_CHANNEL");
	struct channel *c = bc->c;
	struct simple_queue_slot slot;
	if (simple_queue_pop(c->queue, &slot)) {
		// queue is empty
		spin_lock(c);
		if (simple_queue_pop(c->queue, &slot)) {
			// double check queue is empty
			int blocked = ++c->blocked;
			// queue is empty and blocked should be 1 here.
			spin_unlock(c);
			if (blocked > 1) {
				return luaL_error(L, "Blocked pop from %s in multithread", c->name);
			}
			thread_event_wait(&c->trigger);
			if (simple_queue_pop(c->queue, &slot)) {
				return luaL_error(L, "Queue %s should not be empty", c->name);
			}
		} else {
			spin_unlock(c);
		}
	}
	int n = seri_unpack(L, slot.data);
	return n;
}

static int
lpop(lua_State *L) {
	struct boxchannel * c = luaL_checkudata(L, 1, "THREAD_CHANNEL");
	struct simple_queue_slot slot;
	if (simple_queue_pop(c->c->queue, &slot)) {
		// queue is empty
		return 0;
	} else {
		lua_pushboolean(L, 1);
		int n = seri_unpack(L, slot.data);
		return n+1;
	}
}

static int
lquerychannel(lua_State *L) {
	const char * name = luaL_checkstring(L, 1);
	struct channel * c = query_channel(name);
	if (c == NULL)
		return luaL_error(L, "Can't create channel %s", name);

	struct boxchannel *bc = lua_newuserdata(L, sizeof(*bc));
	bc->c = c;
	if (luaL_newmetatable(L, "THREAD_CHANNEL")) {
		luaL_Reg l[] = {
			{ "push", lpush },
			{ "pop", lpop },
			{ "bpop", lblockedpop },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lsleep(lua_State *L) {
	lua_Number sec = luaL_checknumber(L, 1);
	int msec = (int)(sec * 1000);
	thread_sleep(msec);
	return 0;
}

struct thread_args {
	char * source;
	size_t sz;
	lua_CFunction param;
};

static void
thread_args_free(struct thread_args *args) {
	free(args->source);
	free(args);
}

static int luaopen_thread_worker(lua_State *L);

static int
thread_luamain(lua_State *L) {
	luaL_openlibs(L);
	luaL_requiref(L, "thread", luaopen_thread_worker, 0);
	void *ud = lua_touserdata(L, 1);
	struct thread_args *args = (struct thread_args *)ud;
	if (luaL_loadbuffer(L, args->source, args->sz, "=threadinit") != LUA_OK) {
		return lua_error(L);
	}
	lua_CFunction f = args->param;
	thread_args_free(args);
	if (f == NULL) {
		lua_call(L, 0, 0);
	} else {
		lua_pushcfunction(L, f);
		lua_call(L, 1, 0);
	}
	return 0;
}

static void *
thread_main(void *ud) {
	lua_State *L = luaL_newstate();
	lua_pushcfunction(L, thread_luamain);
	lua_pushlightuserdata(L, ud);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		// NOTICE: may memory leak when error (ud may not be free)
		struct channel * errlog = query_channel(ERRLOG_QUEUE);
		if (errlog) {
			size_t sz;
			const char * str = lua_tolstring(L, -1, &sz);
			void * errmsg = seri_packstring(str, (int)sz);
			struct simple_queue_slot slot = { errmsg };
			push_channel(errlog, &slot);
		} else {
			printf("thread error : %s", lua_tostring(L, -1));
		}
	}
	lua_close(L);
	return NULL;
}

/*
	string source code
	cfunction param
 */
static int
lthread(lua_State *L) {
	size_t sz;
	const char * source = luaL_checklstring(L, 1, &sz);
	lua_CFunction f;
	if (lua_isnoneornil(L, 2)) {
		f = NULL;
	} else {
		if (!lua_iscfunction(L,2) || lua_getupvalue(L,2,1) != NULL) {
			return luaL_error(L, "2nd param should be a C function without upvalue");
		}
		f = lua_tocfunction(L, 2);
	}
	struct thread_args * args = (struct thread_args *)malloc(sizeof(*args));
	args->source = (char *)malloc(sz);
	memcpy(args->source, source, sz);
	args->sz = sz;
	args->param = f;
	struct thread th = { thread_main, args };
	if (thread_create(&th)) {
		thread_args_free(args);
		return luaL_error(L, "Create thread failed");
	}
	return 0;
}

static int
luaopen_thread_worker(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "sleep", lsleep },
		{ "thread", lthread },
		{ "newchannel", lnewchannel },
		{ "channel", lquerychannel },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);
	return 1;
}

LUAMOD_API int
luaopen_thread(lua_State *L) {
	lua_pushcfunction(L, lnewchannel);
	lua_pushstring(L, "errlog");
	lua_call(L, 1, 0);
	return luaopen_thread_worker(L);
}