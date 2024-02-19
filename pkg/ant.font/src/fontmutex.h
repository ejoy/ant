#ifndef __fontmutex_h_
#define __fontmutex_h_

#if defined(_WIN32)
    #include <windows.h>
    #define mutex_t SRWLOCK
    #define mutex_init(m) InitializeSRWLock(&m)
    #define mutex_acquire(m) AcquireSRWLockExclusive(&m)
    #define mutex_release(m) ReleaseSRWLockExclusive(&m)
#else
    #include <pthread.h>
    #define mutex_t pthread_mutex_t
    #define mutex_init(m) pthread_mutex_init(&m, NULL)
    #define mutex_acquire(m) pthread_mutex_lock(&m)
    #define mutex_release(m) pthread_mutex_unlock(&m)
#endif


#endif
