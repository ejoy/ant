#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include "linalg.h"

#define MINCAP 128

#define VECTOR4 4
#define MATRIX 16

// Constant: version should be 0, id is the constant id, persistent should be 1

static float c_ident_vec[4] = { 0,0,0,1 };
static float c_ident_mat[16] = {
	1,0,0,0,
	0,1,0,0,
	0,0,1,0,
	0,0,0,1,
};

static float c_ident_num[4] = {
	0, 0, 0, 0
};

static float c_ident_quat[4] = {
	0, 0, 0, 1,
};
static float c_ident_euler[4] = {
	0, 0, 0, 0,
};

struct constant {
	float * ptr;
	int size;
};

static struct constant c_constant_table[LINEAR_CONSTANT_COUNT] = {
	{ c_ident_mat, MATRIX },
	{ c_ident_vec, VECTOR4 },	
	{ c_ident_num, VECTOR4 },
	{ c_ident_quat, VECTOR4 },
	{ c_ident_euler, VECTOR4 },
};

struct stackid_ {
	uint32_t version:24;
	uint32_t id:24;
	uint32_t type : LINEAR_TYPE_BITS_NUM;	// 0:matrix 1:vector4 2:float 3:quaternion 4:euler
	uint32_t persistent:1;	// 0: persisent 1: temp
};

union stackid {
	struct stackid_ s;
	int64_t i;
};

int64_t
lastack_constant(int cons) {
	if (cons < 0 || cons >= LINEAR_CONSTANT_COUNT)
		return 0;
	union stackid sid;	
	sid.s.version = 0;
	sid.s.id = cons;
	sid.s.persistent = 1;
	sid.s.type = cons;
	
	return sid.i;
}

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

static inline void
init_blob_slots(struct blob * B, int slot_beg, int slot_end) {
	int i;
	for (i = slot_beg; i < slot_end; ++i) {
		B->s[i].tag = TAG_FREE;
		B->s[i].id = i + 2;
	}
	
	B->s[slot_end - 1].id = 0;
	B->freeslot = slot_beg + 1;
}

static struct blob *
blob_new(int size, int cap) {
	struct blob * B = malloc(sizeof(*B));
	B->size = size;
	B->cap = cap;
	B->freelist = 0;	// empty list
	B->buffer = malloc(size * cap);
	B->s = malloc(cap * sizeof(*B->s));
	init_blob_slots(B, 0, cap);
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
		struct oldpage * p = malloc(sizeof(*p));
		p->next = B->old;
		p->page = B->buffer;
		B->old = p;

		int cap = B->cap;	
		B->cap *= 2;
		B->buffer = malloc(B->size * B->cap);
		memcpy(B->buffer, p->page, B->size * cap);
		B->s = realloc(B->s, B->cap * sizeof(*B->s));
		static int alloc_count = 0;
		alloc_count ++;
		init_blob_slots(B, cap, B->cap);
//		printf("...... alloc new blob %d,s = %d,c = %d, freeslot = %d .......\n",alloc_count,B->size,B->cap,B->freeslot);
	}
	//printf("freeslot = %d \n",B->freeslot);
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

static inline void
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

static inline int
get_type_size(int type) {
	const int sizes[LINEAR_TYPE_COUNT] = { 16, 4, 1, 4, 3 };
	assert(LINEAR_TYPE_MAT <= type && type < LINEAR_TYPE_COUNT);
	return sizes[type];
}

void
lastack_pushmatrix(struct lastack *LS, const float *mat) {
	if (LS->temp_matrix_top >= LS->temp_matrix_cap) {
		void * p = new_page(LS, LS->temp_mat);
		LS->temp_mat = malloc(LS->temp_matrix_cap * 2 * sizeof(float) * MATRIX);
		memcpy(LS->temp_mat, p, LS->temp_matrix_cap * sizeof(float) * MATRIX);
		LS->temp_matrix_cap *= 2;
	}
	memcpy(LS->temp_mat + LS->temp_matrix_top * MATRIX, mat, sizeof(float) * MATRIX);
	union stackid sid;
	sid.s.type = LINEAR_TYPE_MAT;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_matrix_top;
	push_id(LS, sid);
	++ LS->temp_matrix_top;
}

void
lastack_pushobject(struct lastack *LS, const float *v, int type) {
	if (type == LINEAR_TYPE_MAT) {
		lastack_pushmatrix(LS, v);
		return;
	}
	const int size = get_type_size(type);
	if (LS->temp_vector_top >= LS->temp_vector_cap) {
		void * p = new_page(LS, LS->temp_vec);
		LS->temp_vec = malloc(LS->temp_vector_cap * 2 * sizeof(float) * VECTOR4);
		memcpy(LS->temp_vec, p, LS->temp_vector_cap * sizeof(float) * VECTOR4);
		LS->temp_vector_cap *= 2;
	}
	memcpy(LS->temp_vec + LS->temp_vector_top * VECTOR4, v, sizeof(float) * size);
	union stackid sid;
	sid.s.type = type;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_vector_top;
	push_id(LS, sid);
	++ LS->temp_vector_top;
}

void
lastack_pushvec4(struct lastack *LS, const float *vec4) {
	lastack_pushobject(LS, vec4, LINEAR_TYPE_VEC4);
}

void
lastack_pushquat(struct lastack *LS, const float *v) {
	lastack_pushobject(LS, v, LINEAR_TYPE_QUAT);
}

void
lastack_pusheuler(struct lastack *LS, const float *v) {
	lastack_pushobject(LS, v, LINEAR_TYPE_EULER);
}

void
lastack_pushnumber(struct lastack *LS, float n) {
	lastack_pushobject(LS, &n, LINEAR_TYPE_NUM);
}

const float *
lastack_value(struct lastack *LS, int64_t ref, int *type) {
	union stackid sid;
	sid.i = ref;
	int id = sid.s.id;
	int ver = sid.s.version;
	void * address = NULL;
	if (type)
		*type = sid.s.type;
	if (sid.s.persistent) {
		if (sid.s.version == 0) {
			// constant
			int id = sid.s.id;
			if (id < 0 || id >= LINEAR_CONSTANT_COUNT)
				return NULL;
			struct constant * c = &c_constant_table[id];
			return c->ptr;
		}
		if (sid.s.type == LINEAR_TYPE_MAT) {
			address = blob_address( LS->per_mat , id, ver);
		} else {
			address = blob_address( LS->per_vec , id, ver);
		}
		return address;
	} else {
		if (ver != LS->version) {
			// version expired
			return NULL;
		}
		if (sid.s.type == LINEAR_TYPE_MAT) {
			if (id >= LS->temp_matrix_top) {
				return NULL;
			}
			return LS->temp_mat + id * MATRIX;
		} else {
			if (id >= LS->temp_vector_top) {
				return NULL;
			}
			return LS->temp_vec + id * VECTOR4;
		}
	}
}

int
lastack_pushref(struct lastack *LS, int64_t ref) {
	union stackid id;
	id.i = ref;
	// check alive
	const void *address = lastack_value(LS, id.i, NULL);
	if (address == NULL)
		return 1;
	push_id(LS, id);
	return 0;
}

int64_t
lastack_unmark(struct lastack *LS, int64_t markid) {
	union stackid id;
	id.i = markid;
	if (id.s.persistent && id.s.version != 0) {
		if (id.s.type != LINEAR_TYPE_MAT) {
			blob_dealloc(LS->per_vec, id.s.id, id.s.version);
		} else {
			blob_dealloc(LS->per_mat, id.s.id, id.s.version);
		}
	}
	switch (id.s.type) {
	case LINEAR_TYPE_VEC4:
		return lastack_constant(LINEAR_CONSTANT_IVEC);
	case LINEAR_TYPE_MAT:
		return lastack_constant(LINEAR_CONSTANT_IMAT);
	case LINEAR_CONSTANT_NUM:
		return lastack_constant(LINEAR_CONSTANT_NUM);
	case LINEAR_CONSTANT_QUAT:
		return lastack_constant(LINEAR_CONSTANT_QUAT);
	case LINEAR_TYPE_EULER:
		return lastack_constant(LINEAR_CONSTANT_EULER);
	default:
		assert(0 && "not support type");
		return lastack_constant(LINEAR_CONSTANT_IVEC);
	}
}

int64_t
lastack_mark(struct lastack *LS, int64_t tempid) {
	int t;
	const float *address = lastack_value(LS, tempid, &t);
	if (address == NULL) {
		//printf("--- mark address = null ---");
		return 0;
	}
	int id;
	union stackid sid;
	sid.s.version = LS->version;
	sid.s.type = t;
	if (t != LINEAR_TYPE_MAT) {
		id = blob_alloc(LS->per_vec, LS->version);
		void * dest = blob_address(LS->per_vec, id, LS->version);
		memcpy(dest, address, sizeof(float) * VECTOR4);
	} else {
		id = blob_alloc(LS->per_mat, LS->version);
		void * dest = blob_address(LS->per_mat, id, LS->version);
		memcpy(dest, address, sizeof(float) * MATRIX);
	}
	sid.s.id = id;
	if (sid.s.id != id) {
		//printf(" --- s.id(%d) != id(%d) --- \n ",sid.s.id,id);
		return 0;
	}
	sid.s.persistent = 1;
	return sid.i;
}

int
lastack_marked(int64_t id, int *type) {
	union stackid sid;
	sid.i = id;
	if (type) {
		*type = sid.s.type;
	}
	return sid.s.persistent;
}

int
lastack_sametype(int64_t id1, int64_t id2) {
	union stackid sid1,sid2;
	sid1.i = id1;
	sid2.i = id2;
	return sid1.s.type == sid2.s.type;
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
	if (LS->stack_top < index || index <= 0)
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
	LS->temp_vector_top = 0;
	LS->temp_matrix_top = 0;
}

static void
print_float(const float *address, int n) {
	int i;
	for (i=0;i<n-1;i++) {
		printf("%.3g ", address[i]);
	}
	printf("%.3g",address[i]);
}

static void
print_object(const float *address, int id, int type) {
	switch(type) {
	case LINEAR_TYPE_NONE:
		printf("(None");
		break;
	case LINEAR_TYPE_MAT:
		printf("(M%d: ",id);
		print_float(address, 16);
		break;
	case LINEAR_TYPE_VEC4:
		printf("(V%d: ",id);
		print_float(address, 4);
		break;	
	case LINEAR_TYPE_QUAT:
		printf("(Q%d: ",id);
		print_float(address, 4);
		break;
	case LINEAR_TYPE_NUM:
		printf("(N%d: ",id);
		print_float(address, 1);
		break;
	case LINEAR_TYPE_EULER:
		printf("(E%d: ",id);
		print_float(address, 3);
		break;
	default:
		printf("(Invalid");
		break;
	}
	printf(")");
}

void
lastack_print(struct lastack *LS) {
	printf("version = %d\n", LS->version);
	printf("stack %d/%d:\n", LS->stack_top, LS->stack_cap);
	int i;
	for (i=0;i<LS->stack_top;i++) {
		union stackid id = LS->stack[i];
		int type;
		const float *address = lastack_value(LS, id.i, &type);
		printf("\t[%d]", i);
		if (id.s.persistent) {
			printf("version = %d ", id.s.version);
		}
		print_object(address, id.s.id, type);
		printf("\n");
	}
	printf("Persistent Vector ");
	blob_print(LS->per_vec);
	printf("Persistent Matrix ");
	blob_print(LS->per_mat);
}

int
lastack_gettop(struct lastack *LS) {
	return LS->stack_top;
}

void
lastack_dump(struct lastack *LS, int from) {
	if (from < 0) {
		from = LS->stack_top + from;
		if (from < 0)
			from = 0;
	}
	int i;
	for (i=LS->stack_top-1;i>=from;i--) {
		union stackid id = LS->stack[i];
		int type;
		const float *address = lastack_value(LS, id.i, &type);
		print_object(address, id.s.id, type);
	}
	if (from > 0) {
		for (i=0;i<from;i++) {
			printf(".");
		}
	}
}

int 
lastack_type(struct lastack *LS, int64_t id) {
	union stackid sid;
	sid.i = id;
	return sid.s.type;
}

char *
lastack_idstring(int64_t id, char tmp[64]) {
	union stackid sid;
	sid.i = id;
	char flags[3] = { 0,0,0 };
	switch(sid.s.type) {
	case LINEAR_TYPE_MAT:
		flags[0] = 'M';
		break;
	case LINEAR_TYPE_VEC4:
		flags[0] = 'V';
		break;	
	case LINEAR_TYPE_QUAT:
		flags[0] = 'Q';
		break;
	case LINEAR_TYPE_NUM:
		flags[0] = 'N';
		break;
	case LINEAR_TYPE_EULER:
		flags[0] = 'E';
		break;
	default:
		flags[0] = '?';
		break;
	}
	if (sid.s.persistent) {
		flags[1] = 'P';
	}
	snprintf(tmp, 64, "id=%d version=%d %s",sid.s.id, sid.s.version, flags);
	return tmp;
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
	lastack_pushvector(LS, v, LINEAR_TYPE_VEC4);
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
