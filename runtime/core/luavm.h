#ifndef luavm_h
#define luavm_h

struct luavm;

// Argument format: 
// n double
// i int
// f lua_Cfunction
// p void *
// s const char *
// N double *
// I int *
// S const char **
// B int *	(for boolean return)

struct luavm * luavm_new();
const char * luavm_init(struct luavm *L, const char * source, const char *format, ...);
void luavm_close(struct luavm * L);
const char * luavm_register(struct luavm * L, const char * source, const char *chunkname, int *handle);
const char * luavm_call(struct luavm *L, int handle, const char *format, ...);

#endif
