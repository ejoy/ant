#include "fsevent.h"
#include <thread>

namespace ant {
    static void fsevent_event_cb(ConstFSEventStreamRef streamRef,
        void* info,
        size_t numEvents,
        void* eventPaths,
        const FSEventStreamEventFlags eventFlags[],
        const FSEventStreamEventId eventIds[])
    {
        fsevent* self = (fsevent*)info;
        self->event_cb((const char**)eventPaths, eventFlags, numEvents);
    }

    static void fsevent_apc_cb(void* arg) {
        fsevent* self = (fsevent*)arg;
        self->apc_cb();
    }

    fsevent::fsevent() 
		: m_stream(NULL)
        , m_loop(NULL)
        , m_source(NULL)
        , m_gentask(kInvalidTaskId)
    { }
    fsevent::~fsevent() {
        stop();
    }
    void fsevent::stop() {
        if (!m_thread) {
            return;
        }
        if (!m_thread->joinable()) {
            m_thread.reset();
            return;
        }
        m_apc_queue.push ({
            apc_arg::type::Terminate
        });
        thread_signal();
        m_thread->join();
        m_thread.reset();
    }
    bool fsevent::thread_init() {
        if (m_thread) {
            return true;
        }
        CFRunLoopSourceContext ctx = {0};
        ctx.info = this;
        ctx.perform = fsevent_apc_cb;
        m_source = CFRunLoopSourceCreate(NULL, 0, &ctx);
        if (!m_source) {
            return false;
        }
        m_thread.reset(new std::thread(std::bind(&fsevent::thread_cb, this)));
        m_sem.wait();
        return true;
    }

    void fsevent::thread_signal() {
        CFRunLoopSourceSignal(m_source);
        CFRunLoopWakeUp(m_loop);
    }

    bool fsevent::apc_create_stream(CFArrayRef cf_paths) {
        if (m_stream) {
            return false;
        }
        FSEventStreamContext ctx = {0};
        ctx.info = this;

        FSEventStreamRef ref = 
            FSEventStreamCreate(NULL,
                &fsevent_event_cb,
                &ctx,
                cf_paths,
                kFSEventStreamEventIdSinceNow,
                0.05,
                kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents
            );
        assert(ref != NULL);
        FSEventStreamScheduleWithRunLoop(ref, m_loop, kCFRunLoopDefaultMode);
        if (!FSEventStreamStart(ref)) {
            FSEventStreamInvalidate(ref);
            FSEventStreamRelease(ref);
            return false;
        }
        m_stream = ref;
        return true;
    }

    void fsevent::apc_destroy_stream() {
        if (!m_stream) {
            return;
        }
        FSEventStreamStop(m_stream);
        FSEventStreamInvalidate(m_stream);
        FSEventStreamRelease(m_stream);
        m_stream = NULL;
    }

    fsevent::taskid fsevent::add_watch(const std::string& path) {
        if (!thread_init()) {
            return kInvalidTaskId;
        }
        taskid id = ++m_gentask;
        m_apc_queue.push ({
            apc_arg::type::Add,
            ++m_gentask,
            path
        });
        thread_signal();
        return id;
    }

    bool fsevent::remove_watch(taskid id) {
        if (!m_thread) {
            return false;
        }
        m_apc_queue.push ({
            apc_arg::type::Remove,
            id
        });
        thread_signal();
        return true;
    }
    void fsevent::thread_cb() {
        m_loop = CFRunLoopGetCurrent();
        m_sem.signal();
        CFRunLoopAddSource(m_loop, m_source, kCFRunLoopDefaultMode);
        CFRunLoopRun();
        CFRunLoopRemoveSource(m_loop, m_source, kCFRunLoopDefaultMode);
    }

    void fsevent::apc_cb() {
        apc_arg arg;
        while (m_apc_queue.pop(arg)) {
            switch (arg.m_type) {
            case apc_arg::type::Add:
                apc_add(arg.m_id, arg.m_path);
                break;
            case apc_arg::type::Remove:
                apc_remove(arg.m_id);
                break;
            case apc_arg::type::Terminate:
                apc_terminate();
                return;
            }
        }
    }

    void fsevent::apc_update() {
        apc_destroy_stream();
        if (m_tasks.empty()) {
            return;
        }
        std::unique_ptr<CFStringRef[]> paths(new CFStringRef[m_tasks.size()]);
        size_t i = 0;
        for (auto task : m_tasks) {
            paths[i] = CFStringCreateWithCString(NULL, task.second.c_str(), kCFStringEncodingUTF8);
            if (paths[i] == NULL) {
                while (i != 0) {
                    CFRelease(paths[--i]);
                }
                return;
            }
            i++;
        }
        CFArrayRef cf_paths = CFArrayCreate(NULL, (const void **)&paths[0], m_tasks.size(), NULL);
        if (apc_create_stream(cf_paths)) {
            return;
        }
        CFRelease(cf_paths);
    }

    void fsevent::apc_add(taskid id, const std::string& path) {
        m_tasks.insert(std::make_pair(id, path));
        apc_update();
    }

    void fsevent::apc_remove(taskid id) {
        m_tasks.erase(id);
        apc_update();
    }

    void fsevent::apc_terminate() {
    }

    bool fsevent::select(notify& notify) {
        return m_notify.pop(notify);
    }

    void fsevent::event_cb(const char* paths[], const FSEventStreamEventFlags flags[], size_t n) {
        for (size_t i = 0; i < n; ++i) {
            if (flags[i] & kFSEventStreamEventFlagItemCreated) {
                m_notify.push({
                    tasktype::Create, paths[i]
                });
            }
            if (flags[i] & kFSEventStreamEventFlagItemRemoved) {
                m_notify.push({
                    tasktype::Delete, paths[i]
                });
            }
            if (flags[i] & kFSEventStreamEventFlagItemRenamed) {
                m_notify.push({
                    tasktype::Rename, paths[i]
                });
            }
            if (flags[i] & kFSEventStreamEventFlagItemModified) {
                m_notify.push({
                    tasktype::Modify, paths[i]
                });
            }
        }
    }
}
