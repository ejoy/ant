#include "fontmutex.h"
#include <stdlib.h>

#if defined(_WIN32)
    #include <windows.h>
    struct mutex_t { CRITICAL_SECTION cs; };
    static void mutex_init(struct mutex_t* m) { InitializeCriticalSection(&m->cs); }
    void mutex_destroy(struct mutex_t* m) { DeleteCriticalSection(&m->cs); }
    void mutex_acquire(struct mutex_t* m) { EnterCriticalSection(&m->cs); }
    void mutex_release(struct mutex_t* m) { LeaveCriticalSection(&m->cs); }
#else
    #include <pthread.h>
    struct mutex_t { pthread_mutex_t mutex; };
    static void mutex_init(struct mutex_t* m) { pthread_mutex_init(&m->mutex, NULL); }
    void mutex_destroy(struct mutex_t* m) { pthread_mutex_destroy(&m->mutex); }
    void mutex_acquire(struct mutex_t* m) { pthread_mutex_lock(&m->mutex); }
    void mutex_release(struct mutex_t* m) { pthread_mutex_unlock(&m->mutex); }
#endif

struct mutex_t* mutex_create() {
    struct mutex_t* m = (struct mutex_t*)malloc(sizeof(struct mutex_t));
    mutex_init(m);
    return m;
}
