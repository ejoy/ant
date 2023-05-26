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
			int t = m->type[i];
			if (t >= RENDER_MATERIAL_TYPE_MAX) {
				return;
			}
			if (mask & (1 << t)) {
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

static void
shift_next(struct render_material *R, struct material_tuple *m) {
	int index = m->next;
	if (index < 0) {
		m->type[TUPLE_N-1] = RENDER_MATERIAL_TYPE_MAX;
		return;
	}
	struct material_tuple *next = &R->arena[index];
	assert(next->type[0] < RENDER_MATERIAL_TYPE_MAX);
	m->type[TUPLE_N-1] = next->type[0];
	m->mat[TUPLE_N-1] = next->mat[0];
	
	int i = 0;
	while (i < TUPLE_N - 1) {
		next->type[i] = next->type[i+1];
		if (next->type[i] >= RENDER_MATERIAL_TYPE_MAX) {
			break;
		}
		next->mat[i] = next->mat[i+1];
		++i;
	}
	if (i == 0) {
		// remove next tuple
		m->next = -1;
		next->next = R->freelist;
		R->freelist = index;
	} else {
		shift_next(R, next);
	}
}

static void
remove_mat(struct render_material *R, int index, int type) {
	assert(index < R->n);
	struct material_tuple * m = &R->arena[index];
	for (;;) {
		int i;
		for (i=0;i<TUPLE_N;i++) {
			int t = m->type[i];
			if (t == type) {
				// move [i+1],... -> [i], ...
				while (i < TUPLE_N - 1) {
					m->type[i] = m->type[i+1];
					if (m->type[i] >= RENDER_MATERIAL_TYPE_MAX) {
						return;
					}
					m->mat[i] = m->mat[i+1];
					++i;
				}
				shift_next(R, m);
				return;
			}
			if (t > type) {
				return;
			}
		}
		if (m->next < 0)
			return;
		m = &R->arena[m->next];
	}
}

static void
insert_mat_at(struct render_material *R, struct material_tuple *m,int i, int type, void *mat) {
	for (;;) {
		int temp_type = m->type[i];
		void * temp_mat = m->mat[i];
		m->type[i] = type;
		m->mat[i] = mat;
		++i;
		if (i >= TUPLE_N) {
			int index = m->next;
			if (index < 0) {
				index = allocnode(R);
				m->next = index;
				m = &R->arena[index];
				m->next = -1;
				m->type[0] = type;
				m->mat[0] = mat;
				m->type[1] = RENDER_MATERIAL_TYPE_MAX;
			} else {
				m = &R->arena[index];
				insert_mat_at(R, m, 0, temp_type, temp_mat);
			}
			return;
		}
		type = temp_type;
		mat = temp_mat;
	}
}

static void
insert_mat(struct render_material *R, int index, int type, void * mat) {
	struct material_tuple * m = &R->arena[index];
	for (;;) {
		int i;
		for (i=0;i<TUPLE_N;i++) {
			int t = m->type[i];
			if (t >= RENDER_MATERIAL_TYPE_MAX) {
				// replace [i]
				m->type[i] = (uint8_t)type;
				m->mat[i] = mat;
				++i;
				if (i < TUPLE_N) {
					m->type[i] = RENDER_MATERIAL_TYPE_MAX;
				}
				return;
			}
			if (t > type) {
				insert_mat_at(R, m , i, type, mat);
				return;
			}
			if (t == type) {
				// replace
				m->type[i] = (uint8_t)type;
				m->mat[i] = mat;
				return;
			}
		}
		if (m->next < 0) {
			m->next = allocnode(R);
			m = &R->arena[m->next];
			m->next = -1;
			m->type[0] = type;
			m->mat[0] = mat;
			m->type[1] = RENDER_MATERIAL_TYPE_MAX;
			return;
		}
		m = &R->arena[m->next];
	}
}

void
render_material_set(struct render_material *R, int index, int type, void *mat) {
	if (mat == NULL) {
		remove_mat(R, index, type);
	} else {
		insert_mat(R, index, type, mat);
	}
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
		node->next = R->freelist;
		R->freelist = index;
		index = next;
	}
}

#ifdef TEST_RENDER_MATERIAL

#include <stdio.h>

static void
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

static void
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
	for (i=0;i<10;i++) {
		render_material_set(R, index, i, (void *)(uintptr_t)(i+1));
	}
	dump(R, index);
	dump_index(R, index);

	for (i=0;i<10;i+=2) {
		render_material_set(R, index, i, NULL);
	}
	dump(R, index);
	dump_index(R, index);

	for (i=1;i<10;i+=2) {
		render_material_set(R, index, i, NULL);
	}
	dump(R, index);
	dump_index(R, index);

	render_material_dealloc(R, index);

	render_material_release(R);
	return 0;
}

#endif
