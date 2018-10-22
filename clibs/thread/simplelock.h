#ifndef SIMPLE_LOCK_H
#define SIMPLE_LOCK_H

#ifdef _MSC_VER

#include <windows.h>
#define inline __inline

#define atom_cas_long(ptr, oval, nval) (InterlockedCompareExchange((LONG volatile *)ptr, nval, oval) == oval)
#define atom_cas_pointer(ptr, oval, nval) (InterlockedCompareExchangePointer((PVOID volatile *)ptr, nval, oval) == oval)
#define atom_inc(ptr) InterlockedIncrement((LONG volatile *)ptr)
#define atom_dec(ptr) InterlockedDecrement((LONG volatile *)ptr)
#define atom_add(ptr, n) InterlockedAdd((LONG volatile *)ptr, n)
#define atom_sync() MemoryBarrier()
#define atom_spinlock(ptr) while (InterlockedExchange((LONG volatile *)ptr , 1)) {}
#define atom_spintrylock(ptr) (InterlockedExchange((LONG volatile *)ptr , 1) == 0)
#define atom_spinunlock(ptr) InterlockedExchange((LONG volatile *)ptr, 0)

#else

#define atom_cas_long(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
#define atom_cas_pointer(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
#define atom_inc(ptr) __sync_add_and_fetch(ptr, 1)
#define atom_dec(ptr) __sync_sub_and_fetch(ptr, 1)
#define atom_add(ptr, n) __sync_add_and_fetch(ptr, n)
#define atom_sync() __sync_synchronize()
#define atom_spinlock(ptr) while (__sync_lock_test_and_set(ptr,1)) {}
#define atom_spintrylock(ptr) (__sync_lock_test_and_set(ptr,1) == 0)
#define atom_spinunlock(ptr) __sync_lock_release(ptr)

#endif

typedef int spinlock_t;

/* spin lock */
#define spin_lock_init(Q) (Q)->lock = 0
#define spin_lock_destory(Q)
#define spin_lock(Q) atom_spinlock(&(Q)->lock)
#define spin_unlock(Q) atom_spinunlock(&(Q)->lock)
#define spin_trylock(Q) atom_spintrylock(&(Q)->lock)

/* read write lock */

struct rwlock {
	int write;
	int read;
};

static inline void
rwlock_init(struct rwlock *lock) {
	lock->write = 0;
	lock->read = 0;
}

static inline void
rwlock_destory(struct rwlock *lock) {
	(void)lock;
	// to nothing
}

static inline void
rwlock_rlock(struct rwlock *lock) {
	for (;;) {
		while(lock->write) {
			atom_sync();
		}
		atom_inc(&lock->read);
		if (lock->write) {
			atom_dec(&lock->read);
		} else {
			break;
		}
	}
}

static inline void
rwlock_wlock(struct rwlock *lock) {
	atom_spinlock(&lock->write);
	while(lock->read) {
		atom_sync();
	}
}

static inline void
rwlock_wunlock(struct rwlock *lock) {
	atom_spinunlock(&lock->write);
}

static inline void
rwlock_runlock(struct rwlock *lock) {
	atom_dec(&lock->read);
}

#endif
