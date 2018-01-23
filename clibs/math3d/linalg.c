#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define MINCAP 128

#define VECTOR4 4
#define MATRIX 16

struct stackid_ {
	uint32_t version:25;
	uint32_t id:25;
	uint32_t vector:1;	// 0: vector 1:matrix
	uint32_t persistent:1;	// 0: persisent 1: temp
};

union stackid {
	struct stackid_ s;
	int64_t i;
};

struct lastack {
	int temp_vector_cap;
	int temp_vector_top;
	int temp_matrix_cap;
	int temp_matrix_top;
	int version;
	int stack_cap;
	int stack_top;
	float * temp_vec;
	float * temp_mat;
	struct blob * per_vec;
	struct blob * per_mat;
	struct oldpage *old;
	union stackid *stack;
};

#define TAG_FREE 0
#define TAG_USED 1
#define TAG_WILLFREE 2

struct slot {
	uint32_t id : 30;
	uint32_t tag : 2;
};

struct oldpage {
	struct oldpage *next;
	void *page;
};

struct blob {
	int size;
	int cap;
	int freeslot;	// free slot list
	int freelist;	// will free
	char * buffer;
	struct slot *s;
	struct oldpage *old;
};

static struct blob *
blob_new(int size, int cap) {
	struct blob * B = malloc(sizeof(*B));
	B->size = size;
	B->cap = cap;
	B->freeslot = 1;	// base 1
	B->freelist = 0;	// empty list
	B->buffer = malloc(size * cap);
	B->s = malloc(cap * sizeof(*B->s));
	int i;
	for (i=0;i<cap;i++) {
		B->s[i].tag = TAG_FREE;
		B->s[i].id = i+2;
	}
	B->s[cap-1].id = 0;
	B->old = NULL;
	return B;
}

static void
free_oldpage(struct oldpage *p) {
	while (p) {
		struct oldpage *next = p->next;
		free(p->page);
		free(p);
		p = next;
	}
}

#define SLOT_INDEX(idx) ((idx)-1)
#define SLOT_EMPTY(idx) ((idx)==0)

static int
blob_alloc(struct blob *B, int version) {
	if (SLOT_EMPTY(B->freeslot)) {
		int cap = B->cap;
		struct oldpage * p = malloc(sizeof(*p));
		B->cap *= 2;
		p->next = B->old;
		p->page = B->buffer;
		B->buffer = malloc(B->size * B->cap);
		memcpy(B->buffer, p->page, B->size * cap);
		B->s = realloc(B->s, B->cap * sizeof(*B->s));
		int i;
		for (i=0;i<cap;i++) {
			B->s[cap+i].tag = TAG_FREE;
			B->s[cap+i].id = cap+2;
		}
		B->s[cap*2-1].id = 0;
		B->freeslot = cap + 1;
	}
	int ret = SLOT_INDEX(B->freeslot);
	struct slot *s = &B->s[ret];
	B->freeslot = s->id;	// next free slot
	s->tag = TAG_USED;
	s->id = version;
	return ret;
}

static void *
blob_address(struct blob *B, int index, int version) {
	struct slot *s = &B->s[index];
	if (s->tag != TAG_USED || s->id != version)
		return NULL;
	return B->buffer + index * B->size;
}

static void
blob_dealloc(struct blob *B, int index, int version) {
	struct slot *s = &B->s[index];
	if (s->tag != TAG_USED || s->id != version)
		return;
	s->id = B->freelist;
	s->tag = TAG_WILLFREE;
	B->freelist = index + 1;
}

static void
blob_flush(struct blob *B) {
	int slot = B->freelist;
	while (slot) {
		struct slot *s = &B->s[SLOT_INDEX(slot)];
		s->tag = TAG_FREE;
		if (SLOT_EMPTY(s->id)) {
			s->id = B->freeslot;
			B->freeslot = B->freelist;
			B->freelist = 0;
			break;
		}
		slot = s->id;
	}
	free_oldpage(B->old);
	B->old = NULL;
}

static void
blob_delete(struct blob *B) {
	if (B) {
		free(B->buffer);
		free(B->s);
		free_oldpage(B->old);
		free(B);
	}
}

static void
print_list(struct blob *B, const char * h, int list, int tag) {
	printf("%s ", h);
	while (!SLOT_EMPTY(list)) {
		int index = SLOT_INDEX(list);
		struct slot *s = &B->s[index];
		if (s->tag == tag) {
			printf("%d,", SLOT_INDEX(list));
		} else {
			printf("%d [ERROR]", SLOT_INDEX(list));
			break;
		}
		list = s->id;
	}
	printf("\n");
}

static void
blob_print(struct blob *B) {
	int i;
	printf("USED: ");
	for (i=0;i<B->cap;i++) {
		if (B->s[i].tag == TAG_USED) {
			printf("%d,", i);
		}
	}
	printf("\n");
	print_list(B, "FREE :", B->freeslot, TAG_FREE);
	print_list(B, "WILLFREE :", B->freelist, TAG_WILLFREE);
}

#if 0
int
blob_test_main() {
	struct blob *B = blob_new(4, 10);
	int a = blob_alloc(B,1);
	int b = blob_alloc(B,1);
	int c = blob_alloc(B,1);
	blob_print(B);
	blob_dealloc(B, a, 1);
	blob_print(B);
	blob_flush(B);
	blob_print(B);


	return 0;
}
#endif

struct lastack *
lastack_new() {
	struct lastack * LS = malloc(sizeof(*LS));
	LS->temp_vector_cap = MINCAP;
	LS->temp_vector_top = 0;
	LS->temp_matrix_cap = MINCAP;
	LS->temp_matrix_top = 0;
	LS->version = 1;	// base 1
	LS->stack_cap = MINCAP;
	LS->stack_top = 0;
	LS->temp_vec = malloc(LS->temp_vector_cap * VECTOR4 * sizeof(float));
	LS->temp_mat = malloc(LS->temp_matrix_cap * MATRIX * sizeof(float));
	LS->per_vec = blob_new(VECTOR4 * sizeof(float), MINCAP);
	LS->per_mat = blob_new(MATRIX * sizeof(float), MINCAP);
	LS->old = NULL;
	LS->stack = malloc(LS->stack_cap * sizeof(*LS->stack));
	return LS;
}

void
lastack_delete(struct lastack *LS) {
	if (LS == NULL)
		return;
	free(LS->temp_vec);
	free(LS->temp_mat);
	blob_delete(LS->per_vec);
	blob_delete(LS->per_mat);
	free(LS->stack);
	free_oldpage(LS->old);
	free(LS);
}

static void
push_id(struct lastack *LS, union stackid id) {
	if (LS->stack_top >= LS->stack_cap) {
		LS->stack = realloc(LS->stack, (LS->stack_cap *= 2) * sizeof(*LS->stack));
	}
	LS->stack[LS->stack_top++] = id;
}

static void *
new_page(struct lastack *LS, void *page) {
	struct oldpage * p = malloc(sizeof(*p));
	p->next = LS->old;
	p->page = page;
	LS->old = p;
	return page;
}

void
lastack_pushvector(struct lastack *LS, float *vec4) {
	if (LS->temp_vector_top >= LS->temp_vector_cap) {
		void * p = new_page(LS, LS->temp_vec);
		LS->temp_vec = malloc(LS->temp_vector_cap * 2 * sizeof(float) * VECTOR4);
		memcpy(LS->temp_vec, p, LS->temp_vector_cap * sizeof(float) * VECTOR4);
		LS->temp_vector_cap *= 2;
	}
	memcpy(LS->temp_vec + LS->temp_vector_top * VECTOR4, vec4, sizeof(float) * VECTOR4);
	union stackid sid;
	sid.s.vector = 1;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_vector_top;
	push_id(LS, sid);
	++ LS->temp_vector_top;
}

void
lastack_pushmatrix(struct lastack *LS, float *mat) {
	if (LS->temp_matrix_top >= LS->temp_matrix_cap) {
		void * p = new_page(LS, LS->temp_mat);
		LS->temp_mat = malloc(LS->temp_matrix_cap * 2 * sizeof(float) * MATRIX);
		memcpy(LS->temp_mat, p, LS->temp_matrix_cap * sizeof(float) * MATRIX);
		LS->temp_matrix_cap *= 2;
	}
	memcpy(LS->temp_mat + LS->temp_matrix_top * MATRIX, mat, sizeof(float) * MATRIX);
	union stackid sid;
	sid.s.vector = 0;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_matrix_top;
	push_id(LS, sid);
	++ LS->temp_matrix_top;
}

float *
lastack_value(struct lastack *LS, int64_t ref, int *size) {
	union stackid sid;
	sid.i = ref;
	int id = sid.s.id;
	int ver = sid.s.version;
	void * address = NULL;
	if (sid.s.persistent) {
		if (sid.s.vector) {
			if (size)
				*size = 4;
			address = blob_address( LS->per_vec , id, ver);
		} else {
			if (size)
				*size = 16;
			address = blob_address( LS->per_mat , id, ver);
		}
		return address;
	} else {
		if (ver != LS->version) {
			// version expired
			return NULL;
		}
		if (sid.s.vector) {
			if (size)
				*size = 4;
			if (id >= LS->temp_vector_top) {
				return NULL;
			}
			return LS->temp_vec + id * VECTOR4;
		} else {
			if (size)
				*size = 16;
			if (id >= LS->temp_matrix_top) {
				return NULL;
			}
			return LS->temp_mat + id * MATRIX;
		}
	}
}

int
lastack_pushref(struct lastack *LS, int64_t ref) {
	union stackid id;
	if (ref > 0) {
		id.i = ref;
	} else {
		id.i = -ref;
	}
	void *address = lastack_value(LS, id.i, NULL);
	if (address == NULL)
		return 1;
	if (ref > 0) {
		if (id.s.persistent) {
			if (id.s.vector) {
				lastack_pushvector(LS, address);
				blob_dealloc(LS->per_vec, id.s.id, id.s.version);
			} else {
				lastack_pushmatrix(LS, address);
				blob_dealloc(LS->per_mat, id.s.id, id.s.version);
			}
		} else {
			push_id(LS, id);
		}
	} else {
		push_id(LS, id);
	}
	return 0;
}

int64_t
lastack_mark(struct lastack *LS) {
	if (LS->stack_top <= 0)
		return 0;	// 0 is always a invalid id
	union stackid sid = LS->stack[--LS->stack_top];
	float *address = lastack_value(LS, sid.i, NULL);
	int id;
	if (sid.s.vector) {
		id = blob_alloc(LS->per_vec, LS->version);
		void * dest = blob_address(LS->per_vec, id, LS->version);
		memcpy(dest, address, sizeof(float) * VECTOR4);
		sid.s.vector = 1;
	} else {
		id = blob_alloc(LS->per_mat, LS->version);
		void * dest = blob_address(LS->per_mat, id, LS->version);
		memcpy(dest, address, sizeof(float) * MATRIX);
		sid.s.vector = 0;
	}
	sid.s.id = id;
	if (sid.s.id != id) {
		return 0;
	}
	sid.s.persistent = 1;
	return sid.i;
}

int64_t
lastack_pop(struct lastack *LS) {
	if (LS->stack_top <= 0)
		return 0;
	union stackid sid = LS->stack[--LS->stack_top];
	return sid.i;
}

int64_t
lastack_top(struct lastack *LS) {
	if (LS->stack_top <= 0)
		return 0;
	union stackid sid = LS->stack[LS->stack_top-1];
	return sid.i;
}

int64_t
lastack_dup(struct lastack *LS, int index) {
	if (LS->stack_top < index)
		return 0;
	union stackid sid = LS->stack[LS->stack_top-index];
	push_id(LS, sid);
	return sid.i;
}

int64_t
lastack_swap(struct lastack *LS) {
	if (LS->stack_top <= 1)
		return 0;
	union stackid top = LS->stack[LS->stack_top-1];
	union stackid newtop = LS->stack[LS->stack_top-2];
	LS->stack[LS->stack_top-2] = top;
	LS->stack[LS->stack_top-1] = newtop;
	return newtop.i;
}

void
lastack_reset(struct lastack *LS) {
	union stackid v;
	v.s.version = LS->version + 1;
	if (v.s.version == 0)
		++ v.s.version;
	LS->version = v.s.version;
	LS->stack_top = 0;
	free_oldpage(LS->old);
	LS->old = NULL;
	blob_flush(LS->per_vec);
	blob_flush(LS->per_mat);
}

void
lastack_print(struct lastack *LS) {
	printf("version = %d\n", LS->version);
	printf("stack %d/%d:\n", LS->stack_top, LS->stack_cap);
	int i;
	for (i=0;i<LS->stack_top;i++) {
		union stackid id = LS->stack[i];
		int sz;
		int j,k;
		float *address = lastack_value(LS, id.i, &sz);
		printf("\t[%d] id = %d ", i, id.s.id);
		if (id.s.persistent) {
			printf("version = %d ", id.s.version);
		}
		for (j=0;j<sz;j+=4) {
			printf("(");
			for (k=0;k<4;k++) {
				printf("%f ",address[j+k]);
			}
			printf(") ");
		}
		printf("\n");
	}
	printf("Persistent Vector ");
	blob_print(LS->per_vec);
	printf("Persistent Matrix ");
	blob_print(LS->per_mat);
}

#if 0
int
test_main() {
	struct lastack *LS = lastack_new();
	float v[4] = { 1,2,3,4 };
	float m[16] = {
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1
	};
	lastack_pushvector(LS, v);
	int64_t c = lastack_mark(LS);
	lastack_pushmatrix(LS, m);
	lastack_pushref(LS, -c);
	lastack_dup(LS);
	lastack_print(LS);
	lastack_reset(LS);
	lastack_pushref(LS, c);
	lastack_dup(LS);
	lastack_dup(LS);
	lastack_dup(LS);
	lastack_dup(LS);
	lastack_dup(LS);
	lastack_dup(LS);
	lastack_print(LS);
	lastack_reset(LS);
	lastack_print(LS);
	lastack_delete(LS);
	return 0;
}

#endif
