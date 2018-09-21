#pragma once

#include <Windows.h>
#include <string>
#include <array>
#include <map>
#include <memory>
#include "queue.h"

class FileWatch
{
public:
    typedef int TaskId;
    static const TaskId kInvalidTaskId = 0;

    struct Notify {
        enum class Type {
            Create = 1,
            Delete,
            Modify,
            RenameFrom,
            RenameTo,
        };
        TaskId       id;
        Type         type;
        std::wstring path;
    };

    static const int FilterFile    = 0x0001;
    static const int FilterDir     = 0x0002;
    static const int FilterTime    = 0x0004;
    static const int FilterSubtree = 0x0008;

    class Task
        : public OVERLAPPED
    {
        static const size_t kBufSize = 16 * 1024;

    public:
        Task(FileWatch* watch, TaskId id, int filter);
        virtual ~Task();

        bool   open(const std::wstring& directory);
        bool   start();
        void   cancel();
        TaskId getId();

    private:
        void remove();
        static void __stdcall changesProc(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, LPOVERLAPPED lpOverlapped);
        void changesProc(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered);

    private:
        FileWatch*                    m_watch;
        TaskId                        m_id;
        HANDLE                        m_directory;
        int                           m_filter;
        std::array<uint8_t, kBufSize> m_buffer;
        std::array<uint8_t, kBufSize> m_bakbuffer;
    };

    typedef std::shared_ptr<Task> TaskPtr;

public:
    FileWatch();
    virtual ~FileWatch();
    
    void   stop();
    TaskId add(const std::wstring& directory, int filter);
    bool   remove(TaskId id);
    bool   pop(Notify& notify);
    void   push(Notify const& notify);
    void   removeTask(Task* task);

private:
    struct ApcArg {
        enum class Type {
            Add,
            Remove,
            Terminate,
        };
        FileWatch*            self;
        Type                  type;
        TaskId                id;
        std::wstring          directory;
        int                   filter;
    };
    static unsigned int __stdcall threadProc(void* arg);
    static void         __stdcall apcProc(ULONG_PTR arg);
    void threadProc();
    void apcProc(ApcArg* arg);
    void addProc(ApcArg* arg);
    void removeProc(ApcArg* arg);
    void terminateProc(ApcArg* arg);

private:
    HANDLE                    m_thread;
    std::map<TaskId, TaskPtr> m_tasks;
    blocking_queue<Notify>    m_queue;
    bool                      m_terminate;
    TaskId                    m_gentask;
};
