
#ifndef __EFFEKSEER_CLIENT_IMPLEMENTED_H__
#define __EFFEKSEER_CLIENT_IMPLEMENTED_H__

#if !(defined(__EFFEKSEER_NETWORK_DISABLED__))
#if !(defined(_PSVITA) || defined(_PS4) || defined(_SWITCH) || defined(_XBOXONE))

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Client.h"

#include "Effekseer.Socket.h"
#include <set>
#include <vector>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class ClientImplemented : public Client
{
private:
	bool isThreadRunning = false;
	std::thread m_threadRecv;

	EfkSocket m_socket;
	uint16_t m_port;
	std::vector<uint8_t> m_sendBuffer;

	bool m_running;
	std::mutex mutexStop;

	bool GetAddr(const char* host, IN_ADDR* addr);

	static void RecvAsync(void* data);
	void StopInternal();

public:
	ClientImplemented();
	~ClientImplemented();

	bool Start(char* host, uint16_t port);
	void Stop();

	bool Send(void* data, int32_t datasize);

	void Reload(const char16_t* key, void* data, int32_t size);
	void Reload(ManagerRef manager, const char16_t* path, const char16_t* key);

	bool IsConnected();
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#endif // #if !( defined(_PSVITA) || defined(_PS4) || defined(_SWITCH) || defined(_XBOXONE) )

#endif // __EFFEKSEER_CLIENT_IMPLEMENTED_H__
#endif