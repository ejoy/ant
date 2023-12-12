#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include "render_material.h"

#define TUPLE_N 4

struct material_tuple {
	uint8_t type[TUPLE_N];
	int next;
	void * mat[TUPLE_N];
};

struct render_material {
	int max_type;
	int freelist;
	int n;
	int cap;
	struct material_tuple *arena;
};

#define MAX_CHUNK ((RENDER_MATERIAL_TYPE_MAX + TUPLE_N - 1) / TUPLE_N)

struct material_chunk {
	struct material_tuple * c[MAX_CHUNK];
};

static inline int
highest_bit(uint64_t xx) {
	int r = 0;
	uint32_t x;
	if ( xx & (~0ull << 32) ) {
		x = xx >> 32; 
		r += 32;
	} else {
		x = (uint32_t)xx;
	}
	if ( x & 0xffff0000 ) { x >>= 16; r += 16; }
	if ( x & 0x0000ff00 ) { x >>= 8; r += 8; }
	if ( x & 0x000000f0 ) { x >>= 4; r += 4; }
	if ( x & 0x0000000c ) { x >>= 2; r += 2; }
	if ( x & 0x00000002 ) { r += 1; }
	return r;
}

void
render_material_fetch(struct render_material *R, int index, uint64_t mask, void *mat[]) {
	int h = highest_bit(mask);
	memset(mat, 0, h * sizeof(void *));
	assert(index < R->n);
	struct material_tuple * m = &R->arena[index];
	for (;;) {
		int i;
		for (i=0;i<TUPLE_N;i++) {
			uint8_t t = m->type[i];
			if (t >= RENDER_MATERIAL_TYPE_MAX) {
				return;
			}
			if (mask & (1ull << t)) {
				mat[t] = m->mat[i];
			}
		}
		if (m->next < 0)
			return;
		m = &R->arena[m->next];
	}
}

struct render_material *
render_material_create() {
	struct render_material *R = (struct render_material *)malloc(sizeof(*R));
	memset(R, 0, sizeof(*R));
	R->freelist = -1;
	return R;
}

void
render_material_release(struct render_material *R) {
	if (R) {
		free(R->arena);
		free(R);
	}
}

int
render_material_newtype(struct render_material *R) {
	int t = R->max_type++;
	assert(t < RENDER_MATERIAL_TYPE_MAX);
	return t;
}

size_t
render_material_memsize(struct render_material *R) {
	return sizeof(*R) + sizeof(struct material_tuple) * R->cap;
}

static inline int
allocnode(struct render_material *R) {
	int index = R->freelist;
	if (index >= 0) {
		R->freelist = R->arena[index].next;
		return index;
	}
	index = R->n;
	if (index < R->cap) {
		++R->n;
		return index;
	}
	R->cap = (R->cap + 1) * 3 / 2;
	R->arena = realloc(R->arena, R->cap * sizeof(struct material_tuple));
	return R->n++;
}

static int
fetch_chunk(struct render_material *R, int index, struct material_chunk *C) {
	int i = 0;
	while (i < MAX_CHUNK) {
		struct material_tuple * m = &R->arena[index];
		C->c[i] = m;
		index = m->next;
		if (index < 0) {
			int j;
			for (j=0;j<TUPLE_N;j++) {
				if (m->type[j] >= RENDER_MATERIAL_TYPE_MAX) {
					break;
				}
			}
			return i * TUPLE_N + j;
		}
		++i;
	}
	assert(0);
	return -1;
}

static inline void *
get_material(struct material_chunk *C, int index, int *type) {
	int page = index / TUPLE_N;
	index = index % TUPLE_N;
	*type = C->c[page]->type[index];
	return C->c[page]->mat[index];
}

static inline void
set_material(struct material_chunk *C, int index, int type, void *ud) {
	int page = index / TUPLE_N;
	index = index % TUPLE_N;
	C->c[page]->type[index] = (uint8_t)type;
	C->c[page]->mat[index] = ud;
}

static inline void
expand_chunk(struct render_material *R, struct material_chunk *C, int n) {
	if (n % TUPLE_N != 0 || n == 0)
		return;
	assert(n < RENDER_MATERIAL_TYPE_MAX);
	int node = allocnode(R);
	int last = (n - 1) / TUPLE_N;
	C->c[last]->next = node;
	C->c[last+1] = &R->arena[node];
	C->c[last+1]->next = -1;
}

static inline void
close_chunk(struct material_chunk *C, int n) {
	if ((n+1) % TUPLE_N != 0) {
		set_material(C, n+1, RENDER_MATERIAL_TYPE_MAX, NULL);
	}
}

void
render_material_set(struct render_material *R, int index, int type, void *mat) {
	struct material_chunk C;
	int n = fetch_chunk(R, index, &C);
	int i;
	for (i=0;i<n;i++) {
		int t;
		void *ud = get_material(&C, i, &t);
		if (t == type) {
			if (mat == NULL) {
				// remove [i]
				for (;i<n-1;i++) {
					ud = get_material(&C, i+1, &t);
					set_material(&C, i, t, ud);
				}
				set_material(&C, i, RENDER_MATERIAL_TYPE_MAX, NULL);
				if (n > TUPLE_N && ((n-1) % TUPLE_N == 0)) {
					n /= TUPLE_N;
					C.c[n]->next = R->freelist;
					R->freelist = C.c[n-1]->next;
					C.c[n-1]->next = -1;
				}
			} else {
				// replace [i]
				set_material(&C, i, type, mat);
			}
			return;
		}
		if (t > type) {
			if (mat == NULL)
				return;
			expand_chunk(R, &C, n);
			// insert at i
			int j;
			for (j = n; j > i; j--) {
				ud = get_material(&C, j-1, &t);
				set_material(&C, j, t, ud);
			}
			set_material(&C, i, type, mat);
			close_chunk(&C, n);
			return;
		}
	}
	if (mat == NULL)
		return;
	// append
	expand_chunk(R, &C, n);
	set_material(&C, n, type, mat);
	close_chunk(&C, n);
}

int
render_material_alloc(struct render_material *R) {
	int index = allocnode(R);
	struct material_tuple *node = &R->arena[index];
	node->next = -1;
	node->type[0] = RENDER_MATERIAL_TYPE_MAX;
	return index;
}

void
render_material_dealloc(struct render_material *R, int index) {
	while (index >= 0) {
		struct material_tuple *node = &R->arena[index];
		int next = node->next;
		assert(next != index);
		node->next = R->freelist;
		R->freelist = index;
		index = next;
	}
}

#ifdef TEST_RENDER_MATERIAL

#include <stdio.h>

static inline void
dump(struct render_material *R, int index) {
	printf("FETCH %d\n", index);
	void *mat[RENDER_MATERIAL_TYPE_MAX];
	render_material_fetch(R, index, 0xffff, mat);
	int i;
	for (i=0;i<10;i++) {
		if (mat[i]) {
			printf("%d:%p\n",i, mat[i]);
		}
	}
}

static inline void
dump_index(struct render_material *R, int index) {
	printf("DEBUG %d\n", index);
	struct material_tuple *m = &R->arena[index];
	int base = 0;
	for (;;) {
		int i;
		for (i=0;i<TUPLE_N;i++) {
			if (m->type[i] >= RENDER_MATERIAL_TYPE_MAX) {
				return;
			}
			printf("%d : %d %p\n", base + i, m->type[i], m->mat[i]);
		}
		if (m->next < 0)
			return;
		m = &R->arena[m->next];
		base += 4;
	}
}

int
main() {
	struct render_material *R = render_material_create();

	int index = render_material_alloc(R);
	int i;
	for (i=0;i<10;i+=2) {
		render_material_set(R, index, i, (void *)(uintptr_t)(i+1));
	}
	dump_index(R, index);
	for (i=1;i<10;i+=2) {
		render_material_set(R, index, i, (void *)(uintptr_t)(i+1));
	}
	dump_index(R, index);
	for (i=0;i<10;i+=2) {
		render_material_set(R, index, i, NULL);
	}
	dump_index(R, index);

	for (i=1;i<10;i+=2) {
		render_material_set(R, index, i, NULL);
	}
	dump_index(R, index);

	render_material_dealloc(R, index);

	render_material_release(R);
	return 0;
}

#endif
