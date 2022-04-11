#ifndef ant_file_interface_h
#define ant_file_interface_h

#include <stddef.h>

typedef void * file_handle;

struct file_factory;

struct file_api {
	file_handle (*open)(struct file_factory *f, const char *filename, const char *mode);
	void (*close)(struct file_factory *f, file_handle handle);
	size_t (*read)(struct file_factory *f, file_handle handle, void *buffer, size_t sz);
	size_t (*write)(struct file_factory *f, file_handle handle, const void *buffer, size_t sz);
	int (*seek)(struct file_factory *f, file_handle handle, size_t offset);
};

struct file_interface {
	const struct file_api *api;
};

static inline struct file_factory *
file_factory_(struct file_interface *f) {
	return (struct file_factory *)(f+1);
}

static inline file_handle
file_open(struct file_interface *f, const char *filename, const char *mode) {
	return f->api->open(file_factory_(f), filename, mode);
}

static inline void
file_close(struct file_interface *f, file_handle handle) {
	f->api->close(file_factory_(f), handle);
}

static inline size_t
file_read(struct file_interface *f, file_handle handle, void *buffer, size_t sz) {
	return f->api->read(file_factory_(f), handle, buffer, sz);
}

static inline size_t
file_write(struct file_interface *f, file_handle handle, const void *buffer, size_t sz) {
	return f->api->write(file_factory_(f), handle, buffer, sz);
}

static inline int
file_seek(struct file_interface *f, file_handle handle, size_t offset) {
	return f->api->seek(file_factory_(f), handle, offset);
}

#endif
