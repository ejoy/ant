#ifndef RENDER_MATERIAL_H
#define RENDER_MATERIAL_H

#include <stdint.h>

#define RENDER_MATERIAL_TYPE_MAX 64

struct render_material;

struct render_material * render_material_create();
void render_material_release(struct render_material *R);
void render_material_fetch(struct render_material *R, int index, uint64_t mask, void *mat[]);
int render_material_newtype(struct render_material *R);
size_t render_material_memsize(struct render_material *R);
int render_material_alloc(struct render_material *R);
void render_material_dealloc(struct render_material *R, int index);
void render_material_set(struct render_material *R, int index, int type, void *mat);

#endif
