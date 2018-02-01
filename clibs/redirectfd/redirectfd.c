#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)

#include <windows.h>
#include <io.h>

#if defined(_MSC_VER)
#define fileno _fileno
#define close _close
#define STDOUT_FILENO fileno(stdout)
#define STDERR_FILENO fileno(stderr)
#endif

struct thread_args {
	HANDLE readpipe;
	SOCKET sock;
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

static FILE *
get_stdfile(lua_State *L, int stdfd) {
	if (stdfd == STDOUT_FILENO)
		return stdout;
	if (stdfd == STDERR_FILENO) 
		return stderr;

	luaL_error(L, "Invalid std fd %d", stdfd);

	//switch (stdfd) {
	//case STDOUT_FILENO:
	//	return stdout;
	//case STDERR_FILENO:
	//	return stderr;
	//default:
	//	luaL_error(L, "Invalid std fd %d", stdfd);
	//}
	return NULL;
}

static void
redirect(lua_State *L, int fd, int stdfd) {
	FILE * stdfile = get_stdfile(L, stdfd);
	if (_fileno(stdfile) != stdfd) {
		freopen(tmpnam(NULL), "w", stdfile);
		int fno = stdfd;
		stdfd = _fileno(stdfile);
		if (stdfd != fno) {
			_dup2(_dup(stdfd), fno);
		}
	}

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
	CreateThread(NULL, 4096, redirect_thread, (LPVOID)ta, 0, NULL);

	int wpfd = _open_osfhandle((intptr_t)wp, 0);
	if (_dup2(wpfd, stdfd) != 0) {
		close(fd);
		luaL_error(L, "dup2() failed");
	}
	_close(wpfd);
}

#else

static void
redirect(lua_State *L, SOCKET fd, int stdfd) {
	int r =dup2(fd, stdfd);
	close(fd);
	if (r != 0) {
		luaL_error(L, "dup2() failed");
	}
}

#endif

static int
linit(lua_State *L) {
	int sock = luaL_checkinteger(L, 1);
	int stdfd = luaL_optinteger(L, 2, STDOUT_FILENO);
	redirect(L, sock, stdfd);
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
