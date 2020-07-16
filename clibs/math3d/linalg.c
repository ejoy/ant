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

static float c_ident_quat[4] = {
	0, 0, 0, 1,
};

struct constant {
	float * ptr;
	int size;
};

static struct constant c_constant_table[LINEAR_TYPE_COUNT] = {
	{ c_ident_mat, MATRIX },
	{ c_ident_vec, VECTOR4 },	
	{ c_ident_quat, VECTOR4 },
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
	if (cons < 0 || cons >= LINEAR_TYPE_COUNT)
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
	size_t oldpage_size;
};

#define TAG_FREE 0
#define TAG_USED 1

struct slot {
	uint32_t list : 31;
	uint32_t tag : 1;
	int version;
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
	size_t oldpage_size;
};

static inline void
init_blob_slots(struct blob * B, int slot_beg, int slot_end) {
	int i;
	for (i = slot_beg; i < slot_end; ++i) {
		B->s[i].tag = TAG_FREE;
		B->s[i].version = 0;
		B->s[i].list = i + 2;
	}
	
	B->s[slot_end - 1].list = 0;
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
	B->oldpage_size = 0;
	return B;
}

static size_t
blob_size(struct blob *B) {
	return sizeof(*B) + (B->size + sizeof(*B->s)) * B->cap + B->oldpage_size;
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
		B->oldpage_size += sizeof(*p) + B->size * cap;

		B->cap *= 2;
		B->buffer = malloc(B->size * B->cap);
		memcpy(B->buffer, p->page, B->size * cap);
		B->s = realloc(B->s, B->cap * sizeof(*B->s));
		static int alloc_count = 0;
		alloc_count ++;
		init_blob_slots(B, cap, B->cap);
	}
	int ret = SLOT_INDEX(B->freeslot);
	struct slot *s = &B->s[ret];
	B->freeslot = s->list;	// next free slot
	s->tag = TAG_USED;
	s->version = version;
	return ret;
}

static void *
blob_address(struct blob *B, int index, int version) {
	struct slot *s = &B->s[index];
	if (s->version != version)
		return NULL;
	return B->buffer + index * B->size;
}

static void
blob_dealloc(struct blob *B, int index, int version) {
	struct slot *s = &B->s[index];
	if (s->tag != TAG_USED || s->version != version)
		return;
	s->list = B->freelist;
	s->tag = TAG_FREE;
	B->freelist = index + 1;
}

static void
blob_flush(struct blob *B) {
	int slot = B->freelist;
	while (slot) {
		struct slot *s = &B->s[SLOT_INDEX(slot)];
		s->version = 0;
		if (SLOT_EMPTY(s->list)) {
			s->list = B->freeslot;
			B->freeslot = B->freelist;
			B->freelist = 0;
			break;
		}
		slot = s->list;
	}
	free_oldpage(B->old);
	B->old = NULL;
	B->oldpage_size = 0;
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
print_list(struct blob *B, const char * h, int list) {
	printf("%s ", h);
	while (!SLOT_EMPTY(list)) {
		int index = SLOT_INDEX(list);
		struct slot *s = &B->s[index];
		printf("%d,", SLOT_INDEX(list));
		list = s->list;
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
	print_list(B, "FREE :", B->freeslot);
	print_list(B, "WILLFREE :", B->freelist);
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
	LS->oldpage_size = 0;
	return LS;
}

size_t
lastack_size(struct lastack *LS) {
	return sizeof(*LS)
		+ LS->temp_vector_cap * VECTOR4 * sizeof(float)
		+ LS->temp_matrix_cap * MATRIX * sizeof(float)
		+ LS->stack_cap * sizeof(*LS->stack)
		+ blob_size(LS->per_vec)
		+ blob_size(LS->per_mat);
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
new_page(struct lastack *LS, void *page, size_t page_size) {
	struct oldpage * p = malloc(sizeof(*p));
	p->next = LS->old;
	p->page = page;
	LS->old = p;
	LS->oldpage_size += page_size + sizeof(*p);
	return page;
}

int
lastack_typesize(int type) {
	const int sizes[LINEAR_TYPE_COUNT] = { 16, 4, 4 };
//	assert(LINEAR_TYPE_MAT <= type && type < LINEAR_TYPE_COUNT);
	return sizes[type];
}

const char *
lastack_typename(int t) {
	static const char * type_names[] = {
		"mat",
		"v4",
		"quat",
	};
	if (t < 0 || t >= sizeof(type_names)/sizeof(type_names[0]))
		return "unknown";
	return type_names[t];
}


static float *
check_matrix_pool(struct lastack *LS) {
	if (LS->temp_matrix_top >= LS->temp_matrix_cap) {
		size_t sz = LS->temp_matrix_cap * sizeof(float) * MATRIX;
		void * p = new_page(LS, LS->temp_mat, sz);
		LS->temp_mat = malloc(sz * 2);
		memcpy(LS->temp_mat, p, sz);
		LS->temp_matrix_cap *= 2;
	}
	return LS->temp_mat + LS->temp_matrix_top * MATRIX;
}

static float *
check_matrix_pool_n(struct lastack *LS, int n) {
	if (LS->temp_matrix_top + n > LS->temp_matrix_cap) {
		int newcap = LS->temp_matrix_cap * 2;
		while (LS->temp_matrix_top + n > newcap) {
			newcap *= 2;
		}
		size_t sz = LS->temp_matrix_top * sizeof(float) * MATRIX;
		void * p = new_page(LS, LS->temp_mat, sz);
		LS->temp_mat = malloc(newcap * sizeof(float) * MATRIX);
		memcpy(LS->temp_mat, p, sz);
		LS->temp_matrix_cap = newcap;
	}
	return LS->temp_mat + LS->temp_matrix_top * MATRIX;
}

float *
lastack_allocmatrix(struct lastack *LS) {
	float * pmat = check_matrix_pool(LS);
	union stackid sid;
	sid.s.type = LINEAR_TYPE_MAT;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_matrix_top;
	push_id(LS, sid);
	++ LS->temp_matrix_top;
	return pmat;
}

float *
lastack_allocmatrixn(struct lastack *LS, int n) {
	float * pmat = check_matrix_pool_n(LS, n);
	union stackid sid;
	int i;
	for (i=0;i<n;i++) {
		sid.s.type = LINEAR_TYPE_MAT;
		sid.s.persistent = 0;
		sid.s.version = LS->version;
		sid.s.id = LS->temp_matrix_top;
		push_id(LS, sid);
		++ LS->temp_matrix_top;
	}
	return pmat;
}

void
lastack_pushmatrix(struct lastack *LS, const float *mat) {
	float * pmat = lastack_allocmatrix(LS);
	memcpy(pmat, mat, sizeof(float) * MATRIX);
}

void
lastack_pushsrt(struct lastack *LS, const float *s, const float *r, const float *t) {
#define NOTIDENTITY (~0)
	float * mat = check_matrix_pool(LS);
	uint32_t * mark = (uint32_t *)&mat[3*4];
	// scale
	float *scale = &mat[0];
	if (s == NULL) {
		scale[0] = 1;
		scale[1] = 1;
		scale[2] = 1;
		scale[3] = 0;
		mark[0] = 0;
	} else {
		float sx = s[0];
		float sy = s[1];
		float sz = s[2];
		scale[0] = sx;
		scale[1] = sy;
		scale[2] = sz;
		scale[3] = 0;
		if (sx == 1 && sy == 1 && sz == 1) {
			mark[0] = NOTIDENTITY;
		}
	}
	// rotation
	float *rotation = &mat[4*1];
	if (r == NULL || (r[0] == 0 && r[1] == 0 && r[2] == 0 && r[3] == 1)) {
		rotation[0] = 0;
		rotation[1] = 0;
		rotation[2] = 0;
		rotation[3] = 1;
		mark[1] = 0;
	} else {
		rotation[0] = r[0];
		rotation[1] = r[1];
		rotation[2] = r[2];
		rotation[3] = r[3];
		mark[1] = NOTIDENTITY;
	}
	// translate
	float *translate = &mat[4*2];
	if (t == NULL || (t[0] == 0 && t[1] == 0 && t[2] == 0)) {
		translate[0] = 0;
		translate[1] = 0;
		translate[2] = 0;
		translate[3] = 1;
		mark[2] = 0;
	} else {
		translate[0] = t[0];
		translate[1] = t[1];
		translate[2] = t[2];
		translate[3] = 1;
		mark[2] = NOTIDENTITY;
	}
	// mark identity
	if (mark[0] == 0 && mark[1] == 0 && mark[2] == 0) {
		mark[3] = 0;
	} else {
		mark[3] = NOTIDENTITY;
	}
	union stackid sid;
	sid.s.type = LINEAR_TYPE_MAT;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_matrix_top;
	push_id(LS, sid);
	++ LS->temp_matrix_top;
}

static inline float *
alloc_float4(struct lastack *LS, int type) {
	assert(type >= LINEAR_TYPE_VEC4 && type <= LINEAR_TYPE_QUAT);
	if (LS->temp_vector_top >= LS->temp_vector_cap) {
		size_t sz = LS->temp_vector_cap * sizeof(float) * VECTOR4;
		void * p = new_page(LS, LS->temp_vec, sz);
		LS->temp_vec = malloc(sz * 2);
		memcpy(LS->temp_vec, p, sz);
		LS->temp_vector_cap *= 2;
	}

	float * result = LS->temp_vec + LS->temp_vector_top * VECTOR4;
	union stackid sid;
	sid.s.type = type;
	sid.s.persistent = 0;
	sid.s.version = LS->version;
	sid.s.id = LS->temp_vector_top;
	push_id(LS, sid);
	++ LS->temp_vector_top;
	return result;
}

void
lastack_preallocfloat4(struct lastack *LS, int n) {
	if (LS->temp_vector_top + n > LS->temp_vector_cap) {
		int newcap = LS->temp_vector_cap * 2;
		while (LS->temp_vector_top + n > newcap) {
			newcap *= 2;
		}
		size_t sz = LS->temp_vector_top * sizeof(float) * VECTOR4;
		void * p = new_page(LS, LS->temp_vec, sz);
		LS->temp_vec = malloc(newcap * sizeof(float) * VECTOR4);
		memcpy(LS->temp_vec, p, sz);
		LS->temp_vector_cap = newcap;
	}
}

void
lastack_pushobject(struct lastack *LS, const float *v, int type) {
	if (type == LINEAR_TYPE_MAT) {
		lastack_pushmatrix(LS, v);
		return;
	}
	float * buf = alloc_float4(LS, type);
	const int size = lastack_typesize(type);
	memcpy(buf, v, sizeof(float) * size);
}

void
lastack_pushvec4(struct lastack *LS, const float *vec4) {
	float * buf = alloc_float4(LS, LINEAR_TYPE_VEC4);
	memcpy(buf, vec4, sizeof(float) * 4);
}

float *
lastack_allocvec4(struct lastack *LS) {
	return alloc_float4(LS, LINEAR_TYPE_VEC4);
}

void
lastack_pushquat(struct lastack *LS, const float *v) {
	float * buf = alloc_float4(LS, LINEAR_TYPE_QUAT);
	memcpy(buf, v, sizeof(float) * 4);
}

float *
lastack_allocquat(struct lastack *LS) {
	return alloc_float4(LS, LINEAR_TYPE_QUAT);
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
			if (id < 0 || id >= LINEAR_TYPE_COUNT)
				return NULL;
			struct constant * c = &c_constant_table[id];
			return c->ptr;
		}
		if (lastack_typesize(sid.s.type) == MATRIX) {
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
		if (lastack_typesize(sid.s.type) == MATRIX) {
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

void
lastack_unmark(struct lastack *LS, int64_t markid) {
	union stackid id;
	id.i = markid;
	if (id.s.persistent && id.s.version != 0) {
		if (lastack_typesize(id.s.type) != MATRIX) {
			blob_dealloc(LS->per_vec, id.s.id, id.s.version);
		} else {
			blob_dealloc(LS->per_mat, id.s.id, id.s.version);
		}
	}
}

int
lastack_isconstant(int64_t markid) {
	union stackid id;
	id.i = markid;
	return (id.s.persistent && id.s.version == 0);
}

int64_t
lastack_mark(struct lastack *LS, int64_t tempid) {
	if (lastack_isconstant(tempid))
		return tempid;
	int t;
	const float *address = lastack_value(LS, tempid, &t);
	if (address == NULL) {
		return 0;
	}
	int id;
	union stackid sid;
	sid.s.version = LS->version;
	sid.s.type = t;
	if (lastack_typesize(t) != MATRIX) {
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
	LS->oldpage_size = 0;
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
