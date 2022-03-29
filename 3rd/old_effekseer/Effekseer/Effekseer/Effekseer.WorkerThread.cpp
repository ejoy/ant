//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.WorkerThread.h"

#include "Utils/Profiler.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
WorkerThread::WorkerThread()
{
	m_TaskCompleted.store(true);
	m_TaskRequested.store(false);
	m_QuitRequested.store(false);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
WorkerThread::~WorkerThread()
{
	Shutdown();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void WorkerThread::Launch()
{
	m_Thread = std::thread([this]() {
		PROFILER_THREAD("WorkerThread");
		while (1)
		{
			std::unique_lock<std::mutex> lock(m_Mutex);
			m_TaskRequestCV.wait(lock, [this]() { return m_TaskRequested.load() || m_QuitRequested.load(); });
			if (m_QuitRequested)
			{
				break;
			}
			if (m_Task)
			{
				m_Task();
			}
			m_TaskRequested.store(false);
			m_TaskCompleted.store(true);
			m_TaskWaitCV.notify_all();
		}
	});
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void WorkerThread::Shutdown()
{
	m_QuitRequested.store(true);
	m_TaskRequestCV.notify_one();
	m_Thread.join();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void WorkerThread::RunAsync(std::function<void()> task)
{
	std::unique_lock<std::mutex> lock(m_Mutex);
	m_Task = task;
	m_TaskCompleted.store(false);
	m_TaskRequested.store(true);
	m_TaskRequestCV.notify_all();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void WorkerThread::WaitForComplete()
{
	std::unique_lock<std::mutex> lock(m_Mutex);
	m_TaskWaitCV.wait(lock, [this]() { return m_TaskCompleted.load(); });
	m_Task = nullptr;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
