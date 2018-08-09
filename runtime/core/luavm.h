#ifndef luavm_h
#define luavm_h

struct luavm;

struct luavm * luavm_new();
int luavm_init(struct luavm *L, const char * source, const char *format, ...);
void luavm_close(struct luavm * L);
int luavm_register(struct luavm * L, const char * source, const char *chunkname);
int luavm_call(struct luavm *L, int handle, const char *format, ...);
const char * luavm_lasterror(struct luavm *L);

#endif
