#ifndef MATERIAL_ARENA_H
#define MATERIAL_ARENA_H

#include <bgfx/c99/bgfx.h>
#include <stdint.h>
#include "mathid.h"

#define MATERIAL_SYSTEM_ATTRIB_CHUNK 2
#define INVALID_ATTRIB 0xffff

#define ATTRIB_UNIFORM 0
#define ATTRIB_UNIFORM_INSTANCE 1
#define ATTRIB_SAMPLER 2
#define ATTRIB_IMAGE   3
#define ATTRIB_BUFFER  4
#define ATTRIB_NONE    5

typedef uint16_t attrib_id;
typedef uint16_t name_id;

struct attrib_arena;

size_t attrib_arena_size();
void attrib_arena_init(struct attrib_arena *A);
const char * attrib_arena_init_uniform(struct attrib_arena *A, int id, bgfx_uniform_handle_t h, const float *v, int n, int elem);
const char * attrib_arena_init_sampler(struct attrib_arena *A, int id, bgfx_uniform_handle_t h, uint32_t handle, uint8_t stage);
const char * attrib_arena_init_image(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access, uint8_t mip);
const char * attrib_arena_init_buffer(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access);
attrib_id attrib_arena_new(struct attrib_arena *A, attrib_id prev, name_id key);
attrib_id attrib_arena_delete(struct attrib_arena *A, attrib_id prev, attrib_id current);
attrib_id attrib_arena_clone(struct attrib_arena *A, attrib_id prev, attrib_id head, attrib_id node);
attrib_id attrib_arena_find(struct attrib_arena *A, attrib_id head, name_id key, attrib_id *prev);
math_t attrib_arena_remove(struct attrib_arena *A, attrib_id *prev);
void attrib_arena_set_uniform(struct attrib_arena *A, int id, const float *v);
math_t attrib_arena_set_uniform_instance(struct attrib_arena *A, int id, math_t m);
void attrib_arena_set_handle(struct attrib_arena *A, int id, uint32_t handle);
void attrib_arena_set_sampler(struct attrib_arena *A, int id, uint32_t handle, int stage);
void attrib_arena_set_resource(struct attrib_arena *A, int id, uint32_t handle, uint8_t stage, bgfx_access_t access, uint8_t mip);
int attrib_arena_type(struct attrib_arena *A, int id);

struct attrib_arena_apply_context {
	struct bgfx_interface_vtbl *bgfx;
	bgfx_encoder_t *encoder;
	struct math_context *math3d;
	const float * (*math_value)(struct math_context *, math_t id);
	int (*math_size)(struct math_context *ctx, math_t id);
	bgfx_texture_handle_t (*texture_get)(int id);
};

const char * attrib_arena_apply(struct attrib_arena *A, int id, struct attrib_arena_apply_context *ctx);
const char * attrib_arena_apply_list(struct attrib_arena *A, attrib_id head, attrib_id patch, struct attrib_arena_apply_context *ctx);
const char * attrib_arena_apply_global(struct attrib_arena *A, uint64_t mask, int base, struct attrib_arena_apply_context *ctx);

#endif
