#include <assert.h>
#include <lua.hpp>
#include <stdio.h>
#include "fmod.h"
#include "fmod_studio.h"
#include "fmod_errors.h"

#include "fastio.h"

static void
ERRCHECK_fn(lua_State *L, FMOD_RESULT result, const char* file, int line) {
	if (result != FMOD_OK) {
		luaL_error(L, "audio %s(%d): FMOD error %d - %s", file, line, result, FMOD_ErrorString(result));
	}
}

#define ERRCHECK(L, _result) ERRCHECK_fn(L, _result, __FILE__, __LINE__)

struct audio {
	FMOD_STUDIO_SYSTEM * system;
};

static inline struct audio *
get_audio(lua_State *L) {
	return (struct audio *)luaL_checkudata(L, 1, "AUDIO_FMOD");
}

static int
laudio_shutdown(lua_State *L) {
	struct audio *a = get_audio(L);
	if (a->system == NULL)
		return 0;
	ERRCHECK(L, FMOD_Studio_System_Release(a->system));
	a->system = NULL;
	return 0;
}

static int
laudio_load_bank(lua_State *L) {
	struct audio *a = get_audio(L);
	auto mem = getmemory(L, 2);
	FMOD_STUDIO_BANK *bank = NULL;
	ERRCHECK(L, FMOD_Studio_System_LoadBankMemory(a->system, mem.data(), (int)mem.size(), FMOD_STUDIO_LOAD_MEMORY, FMOD_STUDIO_LOAD_BANK_NORMAL, &bank));
	char name[1024];
	int retrieved;
	if (lua_istable(L, 3)) {
		// events
		int count;
		ERRCHECK(L, FMOD_Studio_Bank_GetEventCount(bank, &count));
		FMOD_STUDIO_EVENTDESCRIPTION ** eventlist;
		FMOD_STUDIO_EVENTDESCRIPTION * tmp[1024];
		if (count > 1024) {
			eventlist = (FMOD_STUDIO_EVENTDESCRIPTION **)lua_newuserdatauv(L, sizeof(*eventlist) * count, 0);
		} else {
			eventlist = tmp;
		}
		ERRCHECK(L, FMOD_Studio_Bank_GetEventList(bank, eventlist, count, &count));
		int i;
		for (i=0; i<count; i++) {
			ERRCHECK(L, FMOD_Studio_EventDescription_GetPath(eventlist[i], name, sizeof(name), &retrieved));
			lua_pushlstring(L, name, retrieved-1);
			lua_pushlightuserdata(L, eventlist[i]);
			lua_settable(L, 3);
		}
	}
	ERRCHECK(L, FMOD_Studio_Bank_GetPath(bank, name, sizeof(name), &retrieved));
	lua_pushlstring(L, name, retrieved-1);
	return 1;
}

static int
laudio_unload_bank(lua_State *L) {
	struct audio *a = get_audio(L);
	const char *filename = luaL_checkstring(L, 2);
	FMOD_STUDIO_BANK *bank = NULL;
	ERRCHECK(L, FMOD_Studio_System_GetBank(a->system, filename, &bank));
	ERRCHECK(L, FMOD_Studio_Bank_Unload(bank));
	return 0;
}

static int
laudio_unload_all(lua_State *L) {
	struct audio *a = get_audio(L);
	ERRCHECK(L, FMOD_Studio_System_UnloadAll(a->system));
	return 0;
}

static int
laudio_update(lua_State *L) {
	struct audio *a = get_audio(L);
	ERRCHECK(L, FMOD_Studio_System_Update(a->system));
	return 0;
}

static int
laudio_event_get(lua_State *L) {
	struct audio *a = get_audio(L);
	FMOD_STUDIO_EVENTDESCRIPTION *event = NULL;
	ERRCHECK(L, FMOD_Studio_System_GetEvent(a->system, luaL_checkstring(L, 2), &event));
	lua_pushlightuserdata(L, event);
	return 1;
}

static int
laudio_event_play(lua_State *L) {
	FMOD_STUDIO_EVENTDESCRIPTION* event = (FMOD_STUDIO_EVENTDESCRIPTION*)lua_touserdata(L, 1);
	if (event == NULL)
		return luaL_error(L, "Invalid event");
	FMOD_STUDIO_EVENTINSTANCE *inst = NULL;
	ERRCHECK(L, FMOD_Studio_EventDescription_CreateInstance(event, &inst));
	ERRCHECK(L, FMOD_Studio_EventInstance_Start(inst));
	ERRCHECK(L, FMOD_Studio_EventInstance_Release(inst));
	return 0;
}

struct background_sound {
	FMOD_STUDIO_EVENTINSTANCE *inst;
	struct audio *sys;
};

static inline struct background_sound *
get_background(lua_State *L) {
	return (struct background_sound *)luaL_checkudata(L, 1, "AUDIO_BACKGROUND");
}

static int
lbackground_play(lua_State *L) {
	struct background_sound *b = get_background(L);
	if (b->sys->system == NULL)
		return 0;
	if (b->inst) {
		ERRCHECK(L, FMOD_Studio_EventInstance_Release(b->inst));
		ERRCHECK(L, FMOD_Studio_EventInstance_Stop(b->inst, FMOD_STUDIO_STOP_IMMEDIATE));
		b->inst = NULL;
	}
	FMOD_STUDIO_EVENTDESCRIPTION *event = (FMOD_STUDIO_EVENTDESCRIPTION *)lua_touserdata(L, 2);
	if (event == NULL)
		return luaL_error(L, "Invalid event");
	ERRCHECK(L, FMOD_Studio_EventDescription_CreateInstance(event, &b->inst));
	ERRCHECK(L, FMOD_Studio_EventInstance_Start(b->inst));
	return 0;
}

static int
lbackground_stop(lua_State *L) {
	struct background_sound *b = get_background(L);
	if (b->sys->system == NULL || b->inst == NULL )
		return 0;
	int fadeout = lua_toboolean(L, 2);
	ERRCHECK(L, FMOD_Studio_EventInstance_Release(b->inst));
	ERRCHECK(L, FMOD_Studio_EventInstance_Stop(b->inst, fadeout ? FMOD_STUDIO_STOP_ALLOWFADEOUT : FMOD_STUDIO_STOP_IMMEDIATE));
	b->inst = NULL;
	return 0;
}

static int
laudio_background(lua_State *L) {
	struct audio *a = get_audio(L);
	struct background_sound *b = (struct background_sound *)lua_newuserdatauv(L, sizeof(*b), 1);
	lua_pushvalue(L, 1);
	lua_setiuservalue(L, -2, 1);
	b->inst = NULL;
	b->sys = a;
	if (luaL_newmetatable(L, "AUDIO_BACKGROUND")) {
		luaL_Reg l[] = {
			{ "__gc", lbackground_stop },
			{ "__index", NULL },
			{ "play", lbackground_play },
			{ "stop", lbackground_stop },
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
laudio_init(lua_State *L) {
	int maxchannel = (int)luaL_optinteger(L, 1, 1024);
	struct audio * a = (struct audio *)lua_newuserdatauv(L, sizeof(*a), 0);
	ERRCHECK(L, FMOD_Studio_System_Create(&a->system, FMOD_VERSION));
	FMOD_SYSTEM * sys = NULL;
	ERRCHECK(L, FMOD_Studio_System_GetCoreSystem(a->system, &sys));
	ERRCHECK(L, FMOD_System_SetSoftwareFormat(sys, 0, FMOD_SPEAKERMODE_5POINT1, 0));
	ERRCHECK(L, FMOD_Studio_System_Initialize(a->system, maxchannel, FMOD_STUDIO_INIT_SYNCHRONOUS_UPDATE, FMOD_INIT_THREAD_UNSAFE, NULL));
	if (luaL_newmetatable(L, "AUDIO_FMOD")) {
		luaL_Reg l[] = {
			{ "__gc", laudio_shutdown },
			{ "__index", NULL },
			{ "shutdown", laudio_shutdown },
			{ "load_bank", laudio_load_bank },
			{ "unload_bank", laudio_unload_bank },
			{ "unload_all", laudio_unload_all },
			{ "update", laudio_update },
			{ "event_get",  laudio_event_get },
			{ "background", laudio_background },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

extern "C" int
luaopen_fmod(lua_State * L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", laudio_init },
		{ "play", laudio_event_play },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}