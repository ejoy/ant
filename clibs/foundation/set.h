#ifndef SET_VLA_H
#define SET_VLA_H

#include <stdint.h>

#define SET_HASHCACHE 256
#define SET_ONSTACK 1024

#define SET_TYPE int64_t

struct set {
	SET_TYPE hashcache_k[SET_HASHCACHE * 4];
	unsigned char hashcache_v[SET_HASHCACHE];
	SET_TYPE set_stack[SET_ONSTACK];
	SET_TYPE *set;
	int n;
	int cap;
	int dirty;
};

void set_init(struct set *s);
void set_deinit(struct set *s);

int set_exist(struct set *s , SET_TYPE v);
void set_insert(struct set *s, SET_TYPE v);
void set_erase(struct set *s, SET_TYPE v);

#endif
