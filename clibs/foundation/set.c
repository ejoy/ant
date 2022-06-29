#include "set.h"
#include <stdlib.h>
#include <string.h>

#define HASH_INITIAL 0
#define HASH_EXIST 1
#define HASH_INEXIST 2

static inline int
inthash(SET_TYPE p) {
	int h = (2654435761 * (unsigned int)p) % (SET_HASHCACHE * 4);
	return h;
}

void
set_init(struct set *s) {
	memset(s->hashcache_v, 0, sizeof(s->hashcache_v));
	s->n = 0;
	s->cap = SET_ONSTACK;
	s->set = s->set_stack;
	s->dirty = 0;
}

void
set_deinit(struct set *s) {
	if (s->set != s->set_stack) {
		free(s->set);
		s->set = NULL;
	}
}

static int
compar_int(const void *a, const void *b) {
	const SET_TYPE *aa = (const SET_TYPE *)a;
	const SET_TYPE *bb = (const SET_TYPE *)b;
	return (int)(*aa - *bb);
}

#include <stdio.h>

static void
set_key(struct set *s, int index, SET_TYPE v, int status) {
	s->hashcache_k[index] = v;
	int shift = (index % 4) * 2;
	int mask = 3 << shift;
	s->hashcache_v[index/4] &= ~mask;
	s->hashcache_v[index/4] |= status << shift;
}

static int
index_cache(struct set *s, SET_TYPE v, int *status) {
	int index = inthash(v);
	*status = (s->hashcache_v[index / 4] >> ((index % 4) * 2)) & 3;
	return index;
}

int
set_exist(struct set *s , SET_TYPE v) {
	int status;
	int index = index_cache(s, v, &status);
	if (s->hashcache_k[index] == v) {
		if (status == HASH_EXIST)
			return 1;
		if (status == HASH_INEXIST)
			return 0;
	}
	// lookup in set
	if (s->dirty) {
		qsort(s->set, s->n, sizeof(SET_TYPE), compar_int);
		s->dirty = 0;
	}
	int begin = 0;
	int end = s->n;
	while (begin < end) {
		int mid = (begin + end) / 2;
		SET_TYPE t = s->set[mid];
		if (v == t) {
			set_key(s, index, v, HASH_EXIST);
			return 1;
		} else if (v < t) {
			end = mid;
		} else {
			begin = mid + 1;
		}
	}
	set_key(s, index, v, HASH_INEXIST);
	return 0;
}

void
set_insert(struct set *s, SET_TYPE v) {
	int status;
	int index = index_cache(s, v, &status);
	if (s->hashcache_k[index] == v && status == HASH_EXIST)
		return;
	set_key(s, index, v, HASH_EXIST);
	if (s->n >= s->cap) {
		int newcap = s->cap * 3 / 2;
		if (s->set == s->set_stack) {
			s->set = (SET_TYPE *)malloc(newcap * sizeof(SET_TYPE));
			memcpy(s->set, s->set_stack, s->n * sizeof(SET_TYPE));
		} else {
			s->set = realloc(s->set, newcap * sizeof(SET_TYPE));
		}
		s->cap = newcap;
	}
	s->set[s->n] = v;
	if (s->n > 0 && v < s->set[s->n-1]) {
		s->dirty = 1;
	}
	++s->n;
}

void
set_erase(struct set *s, SET_TYPE v) {
	int status;
	int index = index_cache(s, v, &status);
	if (s->hashcache_k[index] == v && status == HASH_INEXIST)
		return;
	set_key(s, index, v, HASH_INEXIST);
	if (s->dirty) {
		int i;
		for (i=0;i<s->n;i++) {
			if (s->set[i] == v) {
				--s->n;
				s->set[i] = s->set[s->n];
				return;
			}
		}
	} else {
		int begin = 0;
		int end = s->n;
		while (begin < end) {
			int mid = (begin + end) / 2;
			SET_TYPE t = s->set[mid];
			if (v == t) {
				--s->n;
				memmove(s->set + mid, s->set + mid + 1, (s->n - mid) * sizeof(SET_TYPE));
				return;
			} else if (v < t) {
				end = mid;
			} else {
				begin = mid + 1;
			}
		}
	}
}

#ifdef TEST_MAIN

#include <stdio.h>

int
main() {
	struct set s;
	set_init(&s);
	int i;
	for (i=0;i<2000;i++) {
		set_insert(&s, i);
	}
	for (i=0;i<2000;i+=16) {
		set_erase(&s, i);
	}
	for (i=0;i<2000;i+=100) {
		printf("%d : %s\n", i, set_exist(&s, i) ? "true" : "false");
	}
	for (i=0;i<2000;i+=200) {
		printf("%d : %s\n", i, set_exist(&s, i) ? "true" : "false");
	}
	set_deinit(&s);
	return 0;
}

#endif