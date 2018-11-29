#include "fsevent_osx.h"
#include <thread>

namespace ant::osx::fsevent {
    static void watch_event_cb(ConstFSEventStreamRef streamRef,
        void* info,
        size_t numEvents,
        void* eventPaths,
        const FSEventStreamEventFlags eventFlags[],
        const FSEventStreamEventId eventIds[])
    {
        watch* self = (watch*)info;
        self->event_cb((const char**)eventPaths, eventFlags, numEvents);
    }

    static void watch_apc_cb(void* arg) {
        watch* self = (watch*)arg;
        self->apc_cb();
    }

    watch::watch() 
        : m_stream(NULL)
        , m_loop(NULL)
        , m_source(NULL)
        , m_gentask(kInvalidTaskId)
    { }
    watch::~watch() {
        stop();
    }
    void watch::stop() {
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
        if (!thread_signal()) {
            m_thread->detach();
            m_thread.reset();
            return;
        }
        m_thread->join();
        m_thread.reset();
    }
    bool watch::thread_init() {
        if (m_thread) {
            return true;
        }
        CFRunLoopSourceContext ctx = {0};
        ctx.info = this;
        ctx.perform = watch_apc_cb;
        m_source = CFRunLoopSourceCreate(NULL, 0, &ctx);
        if (!m_source) {
            return false;
        }
        m_thread.reset(new std::thread(std::bind(&watch::thread_cb, this)));
        m_sem.wait();
        return true;
    }

    bool watch::thread_signal() {
        if (!m_source || !m_loop) {
            return false;
        }
        CFRunLoopSourceSignal(m_source);
        CFRunLoopWakeUp(m_loop);
        return true;
    }

    bool watch::apc_create_stream(CFArrayRef cf_paths) {
        if (m_stream) {
            return false;
        }
        FSEventStreamContext ctx = {0};
        ctx.info = this;

        FSEventStreamRef ref = 
            FSEventStreamCreate(NULL,
                &watch_event_cb,
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

    void watch::apc_destroy_stream() {
        if (!m_stream) {
            return;
        }
        FSEventStreamStop(m_stream);
        FSEventStreamInvalidate(m_stream);
        FSEventStreamRelease(m_stream);
        m_stream = NULL;
    }

    taskid watch::add(const std::string& path) {
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

    bool watch::remove(taskid id) {
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
    void watch::thread_cb() {
        m_loop = CFRunLoopGetCurrent();
        m_sem.signal();
        CFRunLoopAddSource(m_loop, m_source, kCFRunLoopDefaultMode);
        CFRunLoopRun();
        CFRunLoopRemoveSource(m_loop, m_source, kCFRunLoopDefaultMode);
        m_loop = NULL;
    }

    void watch::apc_cb() {
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

    void watch::apc_update() {
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

    void watch::apc_add(taskid id, const std::string& path) {
        m_tasks.insert(std::make_pair(id, path));
        apc_update();
    }

    void watch::apc_remove(taskid id) {
        m_tasks.erase(id);
        apc_update();
    }

    void watch::apc_terminate() {
        apc_destroy_stream();
        m_tasks.clear();
        CFRunLoopStop(m_loop);
    }

    bool watch::select(notify& notify) {
        return m_notify.pop(notify);
    }

    void watch::event_cb(const char* paths[], const FSEventStreamEventFlags flags[], size_t n) {
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
