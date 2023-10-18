#ifndef __fontmutex_h_
#define __fontmutex_h_

struct mutex_t;
struct mutex_t* mutex_create();
void mutex_destroy(struct mutex_t* m);
void mutex_acquire(struct mutex_t* m);
void mutex_release(struct mutex_t* m);

#endif
