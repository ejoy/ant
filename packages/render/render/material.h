#ifndef _MATERIAL_H_
#define _MATERIAL_H_

struct material_instance;
struct ecs_world;
struct lua_State;
void apply_material_instance(struct lua_State *L, struct material_instance *mi, struct ecs_world *w, int texture_index);

#endif //_MATERIAL_H_