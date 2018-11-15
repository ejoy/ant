#ifndef SIMPLE_THREAD_H
#define SIMPLE_THREAD_H

struct thread {
	void* (*func)(void *);
	void *ud;
	void* id;
};

struct thread_event;

static int thread_create(struct thread * thread);
static void thread_wait(void *id);
static void thread_event_create(struct thread_event *ev);
static void thread_event_release(struct thread_event *ev);
static void thread_event_trigger(struct thread_event *ev);
static void thread_event_wait(struct thread_event *ev);
static void thread_sleep(int msec);

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)

#include <windows.h>
#include <process.h>

#ifdef _MSC_VER
#define INLINE __inline
#else
#define INLINE inline
#endif

static unsigned INLINE __stdcall
thread_function(void *lpParam) {
	struct thread * t = (struct thread *)lpParam;
	t->func(t->ud);
	HeapFree(GetProcessHeap(), 0, t);
	_endthreadex(0);
	return 0;
}

static INLINE int
thread_create(struct thread * thread) {
	struct thread *temp = (struct thread *)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*temp));
	*temp = *thread;
	thread->id = (void *)_beginthreadex(NULL, 0, thread_function, (LPVOID)temp, 0, NULL);
	if (thread->id == NULL) {
		HeapFree(GetProcessHeap(), 0, temp);
		return 1;
	}
	return 0;
}

static INLINE void
thread_wait(void *id) {
	HANDLE h = (HANDLE)id;
	WaitForSingleObject(h, INFINITE);
	CloseHandle(h);
}

struct thread_event {
	HANDLE event;
};

static INLINE void
thread_event_create(struct thread_event *ev) {
	ev->event = CreateEvent(NULL, FALSE, FALSE, NULL);
}

static INLINE void
thread_event_release(struct thread_event *ev) {
	if (ev->event) {
		CloseHandle(ev->event);
		ev->event = NULL;
	}
}

static INLINE void
thread_event_trigger(struct thread_event *ev) {
	SetEvent(ev->event);
}

static INLINE void
thread_event_wait(struct thread_event *ev) {
	WaitForSingleObject(ev->event, INFINITE);
}

static INLINE void
thread_sleep(int msec) {
	Sleep(msec);
}

#else

#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>

static inline void *
thread_function(void * args) {
	struct thread * t = (struct thread *)args;
	t->func(t->ud);
	return NULL;
}

static inline int
thread_create(struct thread * thread) {
	pthread_t pid;

	int ret = pthread_create(&pid, NULL, thread->func, thread->ud);
	thread->id = (void *)pthread_t;
	return ret;
}

static inline void
thread_wait(void *id) {
	pthread_t pid = (pthread_t)id;
	pthread_join(pid, NULL);
}

struct thread_event {
	pthread_cond_t cond;
	pthread_mutex_t mutex;
	int flag;
};

static inline void
thread_event_create(struct thread_event *ev) {
	pthread_mutex_init(&ev->mutex, NULL);
	pthread_cond_init(&ev->cond, NULL);
	ev->flag = 0;
}

static inline void
thread_event_release(struct thread_event *ev) {
	pthread_mutex_destroy(&ev->mutex);
	pthread_cond_destroy(&ev->cond);
}

static inline void
thread_event_trigger(struct thread_event *ev) {
	pthread_mutex_lock(&ev->mutex);
	ev->flag = 1;
	pthread_mutex_unlock(&ev->mutex);
	pthread_cond_signal(&ev->cond);
}

static inline void
thread_event_wait(struct thread_event *ev) {
	pthread_mutex_lock(&ev->mutex);

	while (!ev->flag)
		pthread_cond_wait(&ev->cond, &ev->mutex);

	ev->flag = 0;

	pthread_mutex_unlock(&ev->mutex);
}

static inline void
thread_sleep(int msec) {
	usleep(msec * 1000);
}

#endif

#endif
