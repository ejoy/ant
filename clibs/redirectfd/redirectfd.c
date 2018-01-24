#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)

#include <windows.h>
#include <io.h>

struct thread_args {
	HANDLE readpipe;
	SOCKET sock;
};

struct pipe_ud {
	HANDLE oldstdout;
	HANDLE thread;
};

static DWORD WINAPI
redirect_thread(LPVOID lpParam) {
	struct thread_args *ta = (struct thread_args *)lpParam;
	HANDLE rp = ta->readpipe;
	SOCKET fd = ta->sock;
	free(ta);

	char tmp[1024];
	DWORD sz;

	while (ReadFile(rp, tmp, sizeof(tmp), &sz, NULL)) {
		send(fd, tmp, sz, 0);
	}
	CloseHandle(rp);
	closesocket(fd);
	return 0;
}

static int
lclosepipe(lua_State *L) {
	struct pipe_ud *closepipe = (struct pipe_ud *)lua_touserdata(L, 1);
	if (closepipe) {
		HANDLE oso = closepipe->oldstdout;
		if (oso != NULL) {
			// restore stdout
			int fd = _open_osfhandle((intptr_t)closepipe->oldstdout, 0);
			_dup2(fd, STDOUT_FILENO);
			_close(fd);
			SetStdHandle(STD_OUTPUT_HANDLE, closepipe->oldstdout);
			closepipe->oldstdout = NULL;
		}
		WaitForSingleObject(closepipe->thread, INFINITE);
		CloseHandle(closepipe->thread);
	}
	return 0;
}

static void
redirect(lua_State *L, int fd) {
	HANDLE rp, wp;

	BOOL succ = CreatePipe(&rp, &wp, NULL, 0);
	if (!succ) {
		close(fd);
		luaL_error(L, "CreatePipe failed");
	}

	struct thread_args * ta = malloc(sizeof(*ta));
	ta->readpipe = rp;
	ta->sock = fd;
	// thread don't need large stack
	HANDLE thread = CreateThread(NULL, 4096, redirect_thread, (LPVOID)ta, 0, NULL);

	int wpfd = _open_osfhandle((intptr_t)wp, 0);
	if (_dup2(wpfd, STDOUT_FILENO) != 0) {
		close(fd);
		luaL_error(L, "dup2() failed");
	}
	_close(wpfd);
	struct pipe_ud * closepipe = (struct pipe_ud *)lua_newuserdata(L, sizeof(*closepipe));
	closepipe->oldstdout = NULL;
	closepipe->thread = thread;
	lua_createtable(L, 0, 1);
	lua_pushcfunction(L, lclosepipe);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	lua_setfield(L, LUA_REGISTRYINDEX, "STDOUT_PIPE");
	closepipe->oldstdout = GetStdHandle(STD_OUTPUT_HANDLE);
	SetStdHandle(STD_OUTPUT_HANDLE, wp);
}


#else

static void
redirect(lua_State *L, SOCKET fd) {
	int r =dup2(fd, STDOUT_FILENO);
	close(fd);
	if (r != 0) {
		luaL_error(L, "dup2() failed");
	}
}

#endif

static int
linit(lua_State *L) {
	int sock = luaL_checkinteger(L, 1);
	redirect(L, sock);
	return 0;
}

LUAMOD_API int
luaopen_redirectfd(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init" , linit },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
