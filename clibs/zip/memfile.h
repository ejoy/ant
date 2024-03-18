#ifndef memory_file_h
#define memory_file_h

#include <stdlib.h>

typedef void (*memory_file_closefunc)(void *ud);

struct memory_file {
	void *ud;
	const char *data;
	size_t sz;
	memory_file_closefunc close;
};

static inline void
memory_file_close(struct memory_file *mf) {
	if (mf) {
		mf->close(mf->ud);
	}
}

static inline struct memory_file *
memory_file_cstr(const char *data, size_t sz) {
	struct memory_file * cmf = (struct memory_file *)malloc(sizeof(*cmf));
	if (cmf == NULL)
		return NULL;
	cmf->ud = (void *)cmf;
	cmf->data = data;
	cmf->sz = sz;
	cmf->close = free;
	return cmf;
}

static inline struct memory_file *
memory_file_alloc(size_t sz) {
	struct memory_file * cmf = (struct memory_file *)malloc(sizeof(*cmf) + sz);
	if (cmf == NULL)
		return NULL;
	cmf->ud = (void *)cmf;
	cmf->data = (const char *)(cmf + 1);
	cmf->sz = sz;
	cmf->close = free;
	return cmf;
}

#endif
