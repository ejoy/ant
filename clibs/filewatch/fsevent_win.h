#pragma once

#include <string>
#include <map>
#include <memory>
#include <thread>
#include "lockqueue.h"

#if defined(__MINGW32__)
#include <experimental/filesystem>
namespace fs = std::experimental::filesystem;
#else
#include <filesystem>
namespace fs = std::filesystem;
#endif

namespace ant::win::fsevent {
	class task;

	typedef int taskid;
	enum class tasktype {
		Error,
		Create,
		Delete,
		Modify,
		Rename,
	};
	struct notify {
		tasktype     type;
		std::wstring path;
	};
	static const taskid kInvalidTaskId = 0;

	class watch {
		friend class task;
	public:

	public:
		watch();
		~watch();

		void   stop();
		taskid add(const std::wstring& path);
		bool   remove(taskid id);
		bool   select(notify& notify);

	public:
		void   apc_cb();

	private:
		struct apc_arg {
			enum class type {
				Add,
				Remove,
				Terminate,
			};
			type                  m_type;
			taskid                m_id;
			std::wstring          m_path;
		};
		void apc_add(taskid id, const std::wstring& path);
		void apc_remove(taskid id);
		void apc_terminate();
		void removetask(task* task);
		bool thread_init();
		bool thread_signal();
		void thread_cb();

	private:
		std::unique_ptr<std::thread>            m_thread;
		lockqueue<apc_arg>                      m_apc_queue;
		lockqueue<notify>                       m_notify;
		taskid                                  m_gentask;
		std::map<taskid, std::unique_ptr<task>> m_tasks;
		bool                                    m_terminate;
	};
}
