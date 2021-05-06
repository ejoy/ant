
#if !(defined(__EFFEKSEER_NETWORK_DISABLED__))
#if !(defined(_PSVITA) || defined(_XBOXONE))

#include "Effekseer.Server.h"
#include "Effekseer.Effect.h"
#include "Effekseer.ServerImplemented.h"
#include <thread>

#include <string.h>

#if defined(_WIN32) && !defined(_PS4)
#else
#include <unistd.h>
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::InternalClient::RecvAsync(void* data)
{
	InternalClient* client = (InternalClient*)data;

	while (true)
	{
		client->m_recvBuffer.clear();

		int32_t size = 0;
		int32_t restSize = 0;

		restSize = 4;
		while (restSize > 0)
		{
			auto recvSize = ::recv(client->m_socket, (char*)(&size), restSize, 0);
			restSize -= recvSize;

			if (recvSize == 0 || recvSize == -1)
			{
				// Failed
				client->m_server->RemoveClient(client);
				client->ShutDown();
				return;
			}
		}

		restSize = size;
		while (restSize > 0)
		{
			uint8_t buf[256];

			auto recvSize = ::recv(client->m_socket, (char*)(buf), Min(restSize, 256), 0);
			restSize -= recvSize;

			if (recvSize == 0 || recvSize == -1)
			{
				// Failed
				client->m_server->RemoveClient(client);
				client->ShutDown();
				return;
			}

			for (int32_t i = 0; i < recvSize; i++)
			{
				client->m_recvBuffer.push_back(buf[i]);
			}
		}

		// recieve buffer
		client->m_ctrlRecvBuffers.lock();
		client->m_recvBuffers.push_back(client->m_recvBuffer);
		client->m_ctrlRecvBuffers.unlock();
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ServerImplemented::InternalClient::InternalClient(EfkSocket socket_, ServerImplemented* server)
	: m_socket(socket_)
	, m_server(server)
	, m_active(true)
{
	m_threadRecv = std::thread([this]() { RecvAsync(this); });
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ServerImplemented::InternalClient::~InternalClient()
{
	m_threadRecv.join();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::InternalClient::ShutDown()
{
	if (m_socket != InvalidSocket)
	{
		Socket::Shutsown(m_socket);
		Socket::Close(m_socket);
		m_socket = InvalidSocket;
		m_active = false;
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ServerImplemented::ServerImplemented()
	: m_running(false)
{
	Socket::Initialize();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
ServerImplemented::~ServerImplemented()
{
	Stop();

	Socket::Finalize();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Server* Server::Create()
{
	return new ServerImplemented();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::AddClient(InternalClient* client)
{
	std::lock_guard<std::mutex> lock(m_ctrlClients);
	m_clients.insert(client);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::RemoveClient(InternalClient* client)
{
	std::lock_guard<std::mutex> lock(m_ctrlClients);
	if (m_clients.count(client) > 0)
	{
		m_clients.erase(client);
		m_removedClients.insert(client);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::AcceptAsync(void* data)
{
	ServerImplemented* server = (ServerImplemented*)data;

	while (true)
	{
		SOCKADDR_IN socketAddrIn;
		int32_t Size = sizeof(SOCKADDR_IN);

		EfkSocket socket_ = ::accept(server->m_socket, (SOCKADDR*)(&socketAddrIn), (SOCKLEN*)(&Size));

		if (server->m_socket == InvalidSocket || socket_ == InvalidSocket)
		{
			break;
		}

		// Accept and add an internal client
		server->AddClient(new InternalClient(socket_, server));

		EffekseerPrintDebug("Server : AcceptClient\n");
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
bool ServerImplemented::Start(uint16_t port)
{
	if (m_running)
	{
		Stop();
	}

	int32_t returnCode;
	sockaddr_in sockAddr = {AF_INET};

	// Create a socket
	EfkSocket socket_ = Socket::GenSocket();
	if (socket_ == InvalidSocket)
	{
		return false;
	}

	memset(&sockAddr, 0, sizeof(SOCKADDR_IN));
	sockAddr.sin_family = AF_INET;
	sockAddr.sin_port = htons(port);

	returnCode = ::bind(socket_, (sockaddr*)&sockAddr, sizeof(sockaddr_in));
	if (returnCode == SocketError)
	{
		if (socket_ != InvalidSocket)
		{
			Socket::Close(socket_);
		}
		return false;
	}

	// Connect
	if (!Socket::Listen(socket_, 30))
	{
		if (socket_ != InvalidSocket)
		{
			Socket::Close(socket_);
		}
		return false;
	}

	m_running = true;
	m_socket = socket_;
	m_port = port;

	m_thread = std::thread([this]() { AcceptAsync(this); });

	EffekseerPrintDebug("Server : Start\n");

	return true;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::Stop()
{
	if (!m_running)
		return;

	Socket::Shutsown(m_socket);
	Socket::Close(m_socket);
	m_socket = InvalidSocket;

	m_running = false;

	m_thread.join();

	// Stop clients
	m_ctrlClients.lock();
	for (std::set<InternalClient*>::iterator it = m_clients.begin(); it != m_clients.end(); ++it)
	{
		(*it)->ShutDown();
	}
	m_ctrlClients.unlock();

	// Wait clients to be removed
	while (true)
	{
		m_ctrlClients.lock();
		int32_t size = (int32_t)m_clients.size();
		m_ctrlClients.unlock();

		if (size == 0)
			break;

		std::this_thread::sleep_for(std::chrono::milliseconds(1));
	}

	// Delete clients
	for (std::set<InternalClient*>::iterator it = m_removedClients.begin(); it != m_removedClients.end(); ++it)
	{
		while ((*it)->m_active)
		{
			std::this_thread::sleep_for(std::chrono::milliseconds(1));
		}
		delete (*it);
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::Register(const char16_t* key, const EffectRef& effect)
{
	if (effect == nullptr)
		return;

	std::u16string key_((const char16_t*)key);
	m_effects[key_] = {effect, false};
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::Unregister(const EffectRef& effect)
{
	if (effect == nullptr)
		return;

	auto it = m_effects.begin();
	auto it_end = m_effects.end();

	while (it != it_end)
	{
		if ((*it).second.EffectPtr == effect)
		{
			m_effects.erase(it);
			return;
		}

		it++;
	}
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::Update(ManagerRef* managers, int32_t managerCount, ReloadingThreadType reloadingThreadType)
{
	m_ctrlClients.lock();

	for (std::set<InternalClient*>::iterator it = m_removedClients.begin(); it != m_removedClients.end(); ++it)
	{
		while ((*it)->m_active)
		{
			std::this_thread::sleep_for(std::chrono::milliseconds(1));
		}
		delete (*it);
	}
	m_removedClients.clear();

	for (auto& kv : m_effects)
	{
		if (kv.second.IsRegistered)
		{
			continue;
		}

		kv.second.IsRegistered = true;

		auto key_ = kv.first;

		auto found = m_data.find(kv.first);
		if (found != m_data.end())
		{
			const auto& data = found->second;

			if (m_materialPath.size() > 1)
			{
				m_effects[key_].EffectPtr->Reload(managers, managerCount, data.data(), (int32_t)data.size(), m_materialPath.data());
			}
			else
			{
				m_effects[key_].EffectPtr->Reload(managers, managerCount, data.data(), (int32_t)data.size());
			}
		}
	}

	for (std::set<InternalClient*>::iterator it = m_clients.begin(); it != m_clients.end(); ++it)
	{
		(*it)->m_ctrlRecvBuffers.lock();

		for (size_t i = 0; i < (*it)->m_recvBuffers.size(); i++)
		{
			std::vector<uint8_t>& buf = (*it)->m_recvBuffers[i];

			uint8_t* p = &(buf[0]);

			int32_t keylen = 0;
			memcpy(&keylen, p, sizeof(int32_t));
			p += sizeof(int32_t);

			std::u16string key;
			for (int32_t k = 0; k < keylen; k++)
			{
				key.push_back(((char16_t*)p)[0]);
				p += sizeof(char16_t);
			}

			uint8_t* recv_data = p;
			auto datasize = (int32_t)buf.size() - (p - &(buf[0]));

			if (m_data.count(key) > 0)
			{
				m_data[key].clear();
			}

			for (int32_t d = 0; d < datasize; d++)
			{
				m_data[key].push_back(recv_data[d]);
			}

			if (m_effects.count(key) > 0)
			{
				const auto& data_ = m_data[key];

				if (m_materialPath.size() > 1)
				{
					m_effects[key].EffectPtr->Reload(
						managers, managerCount, data_.data(), (int32_t)data_.size(), m_materialPath.data(), reloadingThreadType);
				}
				else
				{
					m_effects[key].EffectPtr->Reload(managers, managerCount, data_.data(), (int32_t)data_.size(), nullptr, reloadingThreadType);
				}	
			}
		}

		(*it)->m_recvBuffers.clear();
		(*it)->m_ctrlRecvBuffers.unlock();
	}
	m_ctrlClients.unlock();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void ServerImplemented::SetMaterialPath(const char16_t* materialPath)
{
	m_materialPath.clear();

	int32_t pos = 0;
	while (materialPath[pos] != 0)
	{
		m_materialPath.push_back(materialPath[pos]);
		pos++;
	}
	m_materialPath.push_back(0);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#endif // #if !( defined(_PSVITA) || defined(_XBOXONE) )
#endif