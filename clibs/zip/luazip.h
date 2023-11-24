#ifndef luazip_h
#define luazip_h

#include <stddef.h>

int luaopen_zip(lua_State *L);

struct zip_reader_cache;

struct zip_reader_cache * luazip_new(size_t sz, struct zip_reader_cache *);
void luazip_close(struct zip_reader_cache *f);
void* luazip_data(struct zip_reader_cache *f, size_t *sz);
size_t luazip_read(struct zip_reader_cache *f, void *buf, size_t sz);
size_t luazip_tell(struct zip_reader_cache *f);
void luazip_seek(struct zip_reader_cache *f, long offset, int whence);

#endif
