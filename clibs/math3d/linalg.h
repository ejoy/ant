#ifndef linear_algebra_h
#define linear_algebra_h

#include <stdint.h>

#define LINEAR_CONSTANT_IVEC 0
#define LINEAR_CONSTANT_IMAT 1
#define LINEAR_CONSTANT_NUM 2

struct lastack;

int64_t lastack_constant(int cons);
int lastack_marked(int64_t id, int *size);

struct lastack * lastack_new();
void lastack_delete(struct lastack *LS);
void lastack_pushvector(struct lastack *LS, float *vec4);
void lastack_pushmatrix(struct lastack *LS, float *mat);
float * lastack_value(struct lastack *LS, int64_t id, int *size);
int lastack_pushref(struct lastack *LS, int64_t id);
int64_t lastack_mark(struct lastack *LS);
int64_t lastack_pop(struct lastack *LS);
int64_t lastack_top(struct lastack *LS);
int64_t lastack_dup(struct lastack *LS, int index);
int64_t lastack_swap(struct lastack *LS);
void lastack_reset(struct lastack *LS);
void lastack_print(struct lastack *LS);	// for debug

#endif
