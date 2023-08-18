#ifndef _MATERIAL_H_
#define _MATERIAL_H_

#include <bgfx/c99/bgfx.h>

struct material_instance;
struct ecs_world;
struct lua_State;
void apply_material_instance(struct lua_State *L, struct material_instance *mi, struct ecs_world *w);
bgfx_program_handle_t material_prog(struct lua_State *L, struct material_instance *mi);
#endif //_MATERIAL_H_