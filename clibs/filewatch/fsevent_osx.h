#pragma once

#include <CoreServices/CoreServices.h>
#include <memory>
#include <thread>
#include <vector>
#include <string>
#include <map>
#include "lockqueue.h"
#include "semaphore.h"

namespace ant::osx::fsevent {
	typedef int taskid;
	static const taskid kInvalidTaskId = 0;
	enum class tasktype {
		Error,
		Create,
		Delete,
		Modify,
		Rename,
	};
	struct notify {
		tasktype    type;
		std::string path;
	};
    class watch {
    public:
        watch();
        ~watch();
        taskid add(const std::string&  path);
        bool   remove(taskid id);
        void   stop();
		bool   select(notify& notify);
    private:
        bool apc_create_stream(CFArrayRef cf_paths);
        void apc_destroy_stream();
        void apc_add(taskid id, const std::string& path);
        void apc_remove(taskid id);
        void apc_terminate();
        void apc_update();
        bool thread_init();
        bool thread_signal();
        void thread_cb();
   public:
        void event_cb(const char* paths[], const FSEventStreamEventFlags flags[], size_t n);
        void apc_cb();
    private:
		struct apc_arg {
			enum class type {
				Add,
				Remove,
				Terminate,
			};
			type                  m_type;
			taskid                m_id;
			std::string           m_path;
		};

        FSEventStreamRef              m_stream;
        CFRunLoopRef                  m_loop;
        CFRunLoopSourceRef            m_source;
        std::unique_ptr<std::thread>  m_thread;
        lockqueue<apc_arg>            m_apc_queue; 
		lockqueue<notify>             m_notify;
        std::map<taskid, std::string> m_tasks; 
		taskid                        m_gentask;
        semaphore                     m_sem;
    };
}
