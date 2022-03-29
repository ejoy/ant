
#ifndef __EFFEKSEER_WORKER_THREAD_H__
#define __EFFEKSEER_WORKER_THREAD_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

class WorkerThread
{
private:
	std::thread m_Thread;
	std::function<void()> m_Task;
	std::mutex m_Mutex;
	std::condition_variable m_TaskRequestCV;
	std::condition_variable m_TaskWaitCV;
	std::atomic<bool> m_TaskRequested;
	std::atomic<bool> m_TaskCompleted;
	std::atomic<bool> m_QuitRequested;

public:
	WorkerThread();

	WorkerThread(const WorkerThread&)
	{
	}

	~WorkerThread();

	void Launch();

	void Shutdown();

	ThreadNativeHandleType GetThreadHandle()
	{
		return m_Thread.native_handle();
	}

	std::thread::id GetThreadId()
	{
		return m_Thread.get_id();
	}

	void RunAsync(std::function<void()> task);

	void WaitForComplete();
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#endif // __EFFEKSEER_CLIENT_H__
