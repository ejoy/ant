
#ifndef __EFFEKSEER_SOCKET_H__
#define __EFFEKSEER_SOCKET_H__

#if !(defined(_PSVITA) || defined(_XBOXONE))

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <stdint.h>
#include <stdio.h>

#if defined(_WIN32) && !defined(_PS4)

#ifdef __EFFEKSEER_FOR_UE4__
#include "Windows/AllowWindowsPlatformTypes.h"
#endif
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define _WINSOCKAPI_
#include <winsock2.h>
#pragma comment(lib, "ws2_32.lib")

#ifdef __EFFEKSEER_FOR_UE4__
#include "Windows/HideWindowsPlatformTypes.h"
#endif

#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#if !defined(_PS4)
#include <netdb.h>
#endif

#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#if defined(_WIN32) && !defined(_PS4)

typedef SOCKET EfkSocket;
typedef int SOCKLEN;
const EfkSocket InvalidSocket = INVALID_SOCKET;
const int32_t SocketError = SOCKET_ERROR;
const int32_t InaddrNone = INADDR_NONE;

#else

typedef int32_t EfkSocket;
typedef socklen_t SOCKLEN;
const EfkSocket InvalidSocket = -1;
const int32_t SocketError = -1;
const int32_t InaddrNone = -1;

typedef struct hostent HOSTENT;
typedef struct in_addr IN_ADDR;
typedef struct sockaddr_in SOCKADDR_IN;
typedef struct sockaddr SOCKADDR;

#endif

class Socket
{
private:
public:
	static void Initialize();
	static void Finalize();

	static EfkSocket GenSocket();

	static void Close(EfkSocket s);
	static void Shutsown(EfkSocket s);

	static bool Listen(EfkSocket s, int32_t backlog);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#endif // #if !( defined(_PSVITA) || defined(_XBOXONE) )

#endif // __EFFEKSEER_SOCKET_H__
