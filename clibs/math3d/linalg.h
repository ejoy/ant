#ifndef linear_algebra_h
#define linear_algebra_h

#include <stddef.h>
#include <stdint.h>

enum LinearType {
	LINEAR_TYPE_NONE = -1,
	LINEAR_TYPE_MAT = 0,
	LINEAR_TYPE_VEC4,	
	LINEAR_TYPE_QUAT,
	LINEAR_TYPE_COUNT,
};

#define	LINEAR_TYPE_BITS_NUM 3

struct lastack;

int64_t lastack_constant(int cons);
int lastack_isconstant(int64_t id);
int lastack_marked(int64_t id, int *type);
int lastack_sametype(int64_t id1, int64_t id2);
char * lastack_idstring(int64_t id, char tmp[64]);	// for debug
int lastack_typesize(int type);
const char * lastack_typename(int type);

struct lastack * lastack_new();
void lastack_delete(struct lastack *LS);
void lastack_pushobject(struct lastack *LS, const float *v, int type);
void lastack_pushvec4(struct lastack *LS, const float *v);
void lastack_pushquat(struct lastack *LS, const float *v);
void lastack_pushmatrix(struct lastack *LS, const float *mat);
void lastack_preallocfloat4(struct lastack *LS, int n);
float * lastack_allocvec4(struct lastack *LS);
float * lastack_allocquat(struct lastack *LS);
float * lastack_allocmatrix(struct lastack *LS);
float * lastack_allocmatrixn(struct lastack *LS, int n);
void lastack_pushsrt(struct lastack *LS, const float *s, const float *r, const float *t);
const float * lastack_value(struct lastack *LS, int64_t id, int *type);
int lastack_pushref(struct lastack *LS, int64_t id);
int64_t lastack_mark(struct lastack *LS, int64_t tempid);
void lastack_unmark(struct lastack *LS, int64_t markid);
int64_t lastack_pop(struct lastack *LS);
int64_t lastack_top(struct lastack *LS);
int64_t lastack_dup(struct lastack *LS, int index);
int64_t lastack_swap(struct lastack *LS);
void lastack_reset(struct lastack *LS);
void lastack_print(struct lastack *LS);	// for debug, dump all stack
int lastack_gettop(struct lastack *LS); // for debug, get stack length
void lastack_dump(struct lastack *LS, int from); // for debug, dump top values
int lastack_type(struct lastack *LS, int64_t id);
size_t lastack_size(struct lastack *LS);

static inline int lastack_is_vec_type(int type) {
	return (type == LINEAR_TYPE_VEC4) ? 1 : 0;
}

#endif
