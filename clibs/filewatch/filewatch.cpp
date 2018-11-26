#include "filewatch.h"
#include <process.h>
#include <assert.h>

FileWatch::Task::Task(FileWatch* watch, TaskId id, int filter)
    : m_watch(watch)
    , m_id(id)
    , m_directory(INVALID_HANDLE_VALUE)
    , m_filter(filter)
{
    memset(this, 0, sizeof(OVERLAPPED));
    hEvent = this;
}

FileWatch::Task::~Task() {
    assert(m_directory == INVALID_HANDLE_VALUE);
}

bool FileWatch::Task::open(const std::wstring& directory) {
    if (m_directory != INVALID_HANDLE_VALUE) {
        return true;
    }
    m_directory = ::CreateFileW(directory.c_str(),
        FILE_LIST_DIRECTORY,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
        NULL);
    return (m_directory != INVALID_HANDLE_VALUE);
}

void FileWatch::Task::cancel() {
    if (m_directory != INVALID_HANDLE_VALUE) {
        ::CancelIo(m_directory);
        ::CloseHandle(m_directory);
        m_directory = INVALID_HANDLE_VALUE;
    }
}

FileWatch::TaskId FileWatch::Task::Task::getId() {
    return m_id;
}

void FileWatch::Task::remove() {
    if (m_watch) {
        m_watch->removeTask(this);
    }
}

bool FileWatch::Task::start() {
    if (m_directory == INVALID_HANDLE_VALUE) {
        return false;
    }
    BOOL subtree = m_filter & FilterSubtree;
    DWORD flags = 0;
    if (m_filter & FilterFile) {
        flags |= FILE_NOTIFY_CHANGE_FILE_NAME;
    }
    if (m_filter & FilterDir) {
        flags |= FILE_NOTIFY_CHANGE_DIR_NAME;
    }
    if (m_filter & FilterTime) {
        flags |= FILE_NOTIFY_CHANGE_LAST_WRITE
              | FILE_NOTIFY_CHANGE_LAST_WRITE;
    }
    return !!::ReadDirectoryChangesW(
        m_directory,
        &m_buffer[0],
        static_cast<DWORD>(m_buffer.size()),
        subtree,
        flags,
        NULL,
        this,
        &Task::changesProc);
}

void FileWatch::Task::changesProc(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, LPOVERLAPPED lpOverlapped) {
    Task* task = (Task*)lpOverlapped->hEvent;
    task->changesProc(dwErrorCode, dwNumberOfBytesTransfered);
}

void FileWatch::Task::changesProc(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered) {
    if (dwErrorCode == ERROR_OPERATION_ABORTED) {
        remove();
        return;
    }
    if (!dwNumberOfBytesTransfered) {
        return;
    }
    assert(dwNumberOfBytesTransfered >= offsetof(FILE_NOTIFY_INFORMATION, FileName) + sizeof(WCHAR));
    assert(dwNumberOfBytesTransfered <= m_bakbuffer.size());
    memcpy(&m_bakbuffer[0], &m_buffer[0], dwNumberOfBytesTransfered);
    start();

    uint8_t* data = m_bakbuffer.data();
    for (;;) {
        FILE_NOTIFY_INFORMATION& fni = (FILE_NOTIFY_INFORMATION&)*data;
        m_watch->push({
            m_id,
            (FileWatch::Notify::Type)fni.Action,
            std::wstring(fni.FileName, fni.FileNameLength / sizeof(wchar_t)),
            });
        if (!fni.NextEntryOffset) {
            break;
        }
        data += fni.NextEntryOffset;
    }
}

FileWatch::FileWatch()
    : m_thread(NULL)
    , m_tasks()
    , m_queue()
    , m_terminate(false)
    , m_gentask(kInvalidTaskId)
{ }

FileWatch::~FileWatch() {
    stop();
    assert(m_tasks.empty());
}

void FileWatch::removeTask(Task* task) {
    if (task) {
        auto it = m_tasks.find(task->getId());
        if (it != m_tasks.end()) {
            m_tasks.erase(it);
        }
    }
}

void FileWatch::stop() {
    if (!m_thread) {
        return;
    }
    m_terminate = true;
    std::unique_ptr<ApcArg> arg(new ApcArg);
    arg->self = this;
    arg->type = ApcArg::Type::Terminate;
    bool ok = !!::QueueUserAPC(FileWatch::apcProc, m_thread, (ULONG_PTR)arg.get());
    if (ok) {
        arg.release();
    }
    ::WaitForSingleObject(m_thread, INFINITE);
    ::CloseHandle(m_thread);
    m_thread = NULL;
}

FileWatch::TaskId FileWatch::add(const std::wstring& directory, int filter) {
    bool ok = true;
    if (!m_thread) {
        m_thread = (HANDLE)_beginthreadex(NULL, 0, FileWatch::threadProc, this, 0, NULL);
        if (!m_thread) {
            return kInvalidTaskId;
        }
    }
    TaskId id = ++m_gentask;
    std::unique_ptr<ApcArg> arg(new ApcArg);
    arg->self = this;
    arg->type = ApcArg::Type::Add;
    arg->id = id;
    arg->directory = directory;
    arg->filter = filter;
    ok = !!::QueueUserAPC(FileWatch::apcProc, m_thread, (ULONG_PTR)arg.get());
    if (!ok) {
        return kInvalidTaskId;
    }
    arg.release();
    return id;
}

bool FileWatch::remove(TaskId id) {
    if (!m_thread) {
        return false;
    }
    std::unique_ptr<ApcArg> arg(new ApcArg);
    arg->self = this;
    arg->type = ApcArg::Type::Remove;
    arg->id = id;
    bool ok = !!::QueueUserAPC(FileWatch::apcProc, m_thread, (ULONG_PTR)arg.get());
    if (ok) {
        arg.release();
    }
    return ok;
}

unsigned int FileWatch::threadProc(void* arg) {
    FileWatch* self = (FileWatch*)arg;
    self->threadProc();
    return 0;
}

void FileWatch::threadProc() {
    while (!m_terminate || !m_tasks.empty()) {
        ::SleepEx(INFINITE, true);
    }
}

void FileWatch::apcProc(ULONG_PTR arg) {
    std::unique_ptr<ApcArg> ptr((ApcArg*)arg);
    ptr->self->apcProc(ptr.get());
}

void FileWatch::apcProc(ApcArg* arg) {
    switch (arg->type) {
    case ApcArg::Type::Add:
        addProc(arg);
        break;
    case ApcArg::Type::Remove:
        removeProc(arg);
        break;
    case ApcArg::Type::Terminate:
        terminateProc(arg);
        break;
    }
}

void FileWatch::addProc(ApcArg* arg) {
    Task* task = new Task(this, arg->id, arg->filter);
    if (!task->open(arg->directory)) {
        return;
    }
    m_tasks.insert(std::make_pair(arg->id, task));
    task->start();
}

void FileWatch::removeProc(ApcArg* arg) {
    auto it = m_tasks.find(arg->id);
    if (it != m_tasks.end()) {
        it->second->cancel();
    }
}

void FileWatch::terminateProc(ApcArg* arg) {
    if (m_tasks.empty()) {
        return;
    }
    std::vector<TaskPtr> tmp;
    for (auto& it : m_tasks) {
        tmp.push_back(it.second);
    }
    for (auto& it : tmp) {
        it->cancel();
    }
}

bool FileWatch::pop(Notify& notify) {
    return m_queue.try_pop(notify);
}

void FileWatch::push(Notify const& notify) {
    m_queue.push(notify);
}
