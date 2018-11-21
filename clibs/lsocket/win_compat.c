#define WIN_COMPAT_IMPL
#include "win_compat.h"
#include "Iphlpapi.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static int
wsa_error_to_errno(int errcode) {
	switch (errcode) {
	//  10009 - File handle is not valid.
	case WSAEBADF:
		return EBADF;
	//  10013 - Permission denied.
	case WSAEACCES:
		return EACCES;
	//  10014 - Bad address.
	case WSAEFAULT:
		return EFAULT;
	//  10022 - Invalid argument.
	case WSAEINVAL:
		return EINVAL;
	//  10024 - Too many open files.
	case WSAEMFILE:
		return EMFILE;
	//  10035 - A non-blocking socket operation could not be completed immediately.
	case WSAEWOULDBLOCK:
		return EWOULDBLOCK;
	//  10036 - Operation now in progress.
	case WSAEINPROGRESS:
		return EAGAIN;
	//  10040 - Message too long.
	case WSAEMSGSIZE:
		return EMSGSIZE;
	//  10043 - Protocol not supported.
	case WSAEPROTONOSUPPORT:
		return EPROTONOSUPPORT;
	//  10047 - Address family not supported by protocol family.
	case WSAEAFNOSUPPORT:
		return EAFNOSUPPORT;
	//  10048 - Address already in use.
	case WSAEADDRINUSE:
		return EADDRINUSE;
	//  10049 - Cannot assign requested address.
	case WSAEADDRNOTAVAIL:
		return EADDRNOTAVAIL;
	//  10050 - Network is down.
	case WSAENETDOWN:
		return ENETDOWN;
	//  10051 - Network is unreachable.
	case WSAENETUNREACH:
		return ENETUNREACH;
	//  10052 - Network dropped connection on reset.
	case WSAENETRESET:
		return ENETRESET;
	//  10053 - Software caused connection abort.
	case WSAECONNABORTED:
		return ECONNABORTED;
	//  10054 - Connection reset by peer.
	case WSAECONNRESET:
		return ECONNRESET;
	//  10055 - No buffer space available.
	case WSAENOBUFS:
		return ENOBUFS;
	//  10057 - Socket is not connected.
	case WSAENOTCONN:
		return ENOTCONN;
	//  10060 - Connection timed out.
	case WSAETIMEDOUT:
		return ETIMEDOUT;
	//  10061 - Connection refused.
	case WSAECONNREFUSED:
		return ECONNREFUSED;
	//  10065 - No route to host.
	case WSAEHOSTUNREACH:
		return EHOSTUNREACH;
	default:
		//  Not reachable
		return 0;
	}
}

const char*
wsa_strerror(int errcode) {
	switch (errcode) {
	case ECONNREFUSED:
		return "Connection refused.";
	// TODO more errmsg
	default:
		return strerror(errcode);
	}
}

int 
win_getsockopt(SOCKET sockfd, int level, int optname, void *optval, socklen_t *optlen) {
	if (optname == SO_NOSIGPIPE) {
		// ignore
		return 0;
	}
	int size = (int)*optlen;
	int ret = getsockopt(sockfd, level, optname, (char *)optval, &size);
	if (ret == 0) {
		if (optname == SO_ERROR && optval) {
			*(int*)optval = wsa_error_to_errno(*(int*)optval);
		}
		*optlen = size;
		return 0;
	} else {
		return -1;
	}
}

int 
win_setsockopt(SOCKET sockfd, int level, int optname, const void *optval, socklen_t optlen) {
	if (optname == SO_NOSIGPIPE) {
		// ignore
		return 0;
	}
	int ret = setsockopt(sockfd, level, optname, (const char *)optval, (int)optlen);
	if (ret == 0) {
		return 0;
	} else {
		return -1;
	}
}

int
fcntl(SOCKET fd, int cmd, int value) {
	unsigned long on = 1;
	return ioctlsocket(fd, FIONBIO, &on);
}

#define NS_INT16SZ   2
#define NS_IN6ADDRSZ  16

static const char *
inet_ntop4(const unsigned char *src, char *dst, size_t size) {
	char tmp[sizeof "255.255.255.255"];
	size_t len = snprintf(tmp, sizeof(tmp), "%u.%u.%u.%u", src[0], src[1], src[2], src[3]);
	if (len >= size) {
		return NULL;
	}
	memcpy(dst, tmp, len + 1);

	return dst;
}

static const char *
inet_ntop6(const unsigned char *src, char *dst, size_t size) {
	char tmp[sizeof "ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255"], *tp;
	struct { int base, len; } best, cur;
	unsigned int words[NS_IN6ADDRSZ / NS_INT16SZ];
	int i, inc;

	memset(words, '\0', sizeof(words));
	for (i = 0; i < NS_IN6ADDRSZ; i++) {
		words[i / 2] |= (src[i] << ((1 - (i % 2)) << 3));
	}
	best.base = -1;
	best.len = 0;
	cur.base = -1;
	cur.len = 0;
	for (i = 0; i < (NS_IN6ADDRSZ / NS_INT16SZ); i++) {
		if (words[i] == 0) {
			if (cur.base == -1) {
				cur.base = i, cur.len = 1;
			} else {
				cur.len++;
			}
		} else if (cur.base != -1) {
			if (best.base == -1 || cur.len > best.len) {
				best = cur;
			}
			cur.base = -1;
		}
	}
	if (cur.base != -1) {
		if (best.base == -1 || cur.len > best.len)
			best = cur;
	}
	if (best.base != -1 && best.len < 2)
		best.base = -1;

	tp = tmp;
	for (i = 0; i < (NS_IN6ADDRSZ / NS_INT16SZ); i++) {
		if (best.base != -1 && i >= best.base &&
			i < (best.base + best.len)) {
				if (i == best.base)
					*tp++ = ':';
			continue;
		}
		if (i != 0)
			*tp++ = ':';
		if (i == 6 && best.base == 0 &&
			(best.len == 6 || (best.len == 5 && words[5] == 0xffff))) {
			if (!inet_ntop4(src+12, tp, sizeof tmp - (tp - tmp)))
				return NULL;
			tp += strlen(tp);
			break;
		}
		inc = snprintf(tp, 5, "%x", words[i]);
		tp += inc;
	}
	if (best.base != -1 && (best.base + best.len) == (NS_IN6ADDRSZ / NS_INT16SZ))
		*tp++ = ':';
	*tp++ = '\0';

	if ((size_t)(tp - tmp) > size) {
		return NULL;
	}
	memcpy(dst, tmp, tp - tmp);
	return dst;
}

const char *
inet_ntop(int af, const void *src, char *dst,  socklen_t size) {
	switch (af) {
	case AF_INET:
		return inet_ntop4((const unsigned char*)src, dst, size);
	case AF_INET6:
		return inet_ntop6((const unsigned char*)src, dst, size);
	default:
		return NULL;
	}
}

void
init_socketlib(lua_State *L) {
	static int init = 0;
	if (init)
		return;
	WSADATA wsaData;
	int result = WSAStartup(MAKEWORD(2,2), &wsaData);
	if (result != 0) {
		luaL_error(L, "WSAStartup failed: %d\n", result);
	}
	init = 1;
}

int
wsa_errno() {
	int errcode = WSAGetLastError();
	return wsa_error_to_errno(errcode);
}

int
win_select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval * const timeout) {
	if (writefds == NULL) {
		return select(nfds, readfds, NULL, NULL, timeout);
	}
	fd_set exfd;
	FD_ZERO(&exfd);

	// copy fd_set
	int i;
	for (i=0;i<writefds->fd_count;i++) {
		FD_SET(writefds->fd_array[i], &exfd);
	}
	int r = select(nfds, readfds, writefds, &exfd, timeout);
	if (r > 0) {
		for (i=0;i<exfd.fd_count;i++) {
			FD_SET(exfd.fd_array[i], writefds);
		}
	}
	return r;
}
