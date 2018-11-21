#ifndef WINDOWS_COMPAT_H
#define WINDOWS_COMPAT_H

#include <winsock2.h>
#include <windows.h>
#if _WIN32_WINNT < 0x0502
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0502
#endif


#include <ws2tcpip.h>
#include <stdint.h>
#include <lua.h>
#include <lauxlib.h>

#define SO_NOSIGPIPE 0		// ignore it, don't support

#ifndef WIN_COMPAT_IMPL

#define getsockopt win_getsockopt
#define setsockopt win_setsockopt
#define close closesocket
#define select win_select
#ifdef errno
#undef errno
#endif
#define errno wsa_errno()
#ifdef strerror
#undef strerror
#endif
#define strerror(e) wsa_strerror(e)


#ifndef EAGAIN
#define EAGAIN 11
#endif

#ifndef EWOULDBLOCK
#define EWOULDBLOCK 140
#endif

#endif

int win_getsockopt(SOCKET sockfd, int level, int optname, void *optval, socklen_t *optlen);
int win_setsockopt(SOCKET sockfd, int level, int optname, const void *optval, socklen_t optlen);
int wsa_errno();
const char* wsa_strerror(int errcode);
int win_select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval * const timeout);

// only support fcntl(fd, F_SETFL, O_NONBLOCK)
#define F_SETFL 0
#define O_NONBLOCK 0
int fcntl(SOCKET fd, int cmd, int value);
const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);

typedef u_short sa_family_t;

// Windows doesn't support AF_UNIX, this structure is only for avoiding compile error
#define UNIX_PATH_MAX    108

struct sockaddr_un {
   sa_family_t sun_family;	/* AF_UNIX */
   char sun_path[UNIX_PATH_MAX];	/* pathname */
};

void init_socketlib(lua_State *L);

#endif
