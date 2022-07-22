#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include "math3d.h"
#include "lua.hpp"

#include "material.h"
//#include "mesh.h"

#include "lua2struct.h"
#include "luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>

enum filter_stages : uint16_t {
	FS_foreground	= 0x01,
	FS_opaticy		= 0x02,
	FS_background	= 0x04,
	FS_trancluent	= 0x08,
	FS_decal_stage	= 0x10,
	FS_ui_stage		= 0x20,
	FS_count		= 6,
};

static inline bool
entity_visible(struct ecs_world* w, cid_t vs_id, int index, const ecs::render_args2 &ra){
	return entity_sibling(w->ecs, vs_id, index, (cid_t)ra.visible_id) &&
	!entity_sibling(w->ecs, vs_id, index, (cid_t)ra.cull_id);
}
#define BGFX(_API)	w->bgfx->##_API

struct material_instance;

struct queue_materials {
	enum queue_material_type : uint8_t {
		QMT_mainqueue = 0,
		QMT_predepth,
		QMT_scenedepth,
		QMT_pickup,
		QMT_csm1,
		QMT_csm2,
		QMT_csm3,
		QMT_csm4,
		QMT_count,
	};
	union {
		struct {
			struct material_instance* mq;
			struct material_instance* predepth;
			struct material_instance* scenedepth;
			struct material_instance* pickup;
			struct material_instance* csm1;
			struct material_instance* csm2;
			struct material_instance* csm3;
			struct material_instance* csm4;
		};

		struct material_instance* materials[QMT_count];
	};

};

//TODO: we should cache transform update by entity id
static inline void
update_transform(struct ecs_world* w, math_t wm){
	const float * v = math_value(w->math3d->MC, wm);
	const int num = math_size(w->math3d->MC, wm);
	BGFX(set_transform)(v, num);
}

static inline void
update_material(struct ecs_world* w, queue_materials *qm, queue_materials::queue_material_type qmt){
	//auto mi = qm.materials[qmt];
	// struct material_context ctx{};
	// material_apply(&ctx, mi);
}

static inline void
update_mesh(struct ecs_world* w, struct mesh* m){
	//struct mesh_context ctx = {};
	//mesh_apply(m);
}

static inline void
submit_draw(struct ecs_world* w, bgfx_view_id_t viewid, const ecs::render_obj &ro){
	
	w->bgfx->submit(viewid, {ro.prog}, ro.depth, ro.flags);
}

static int
lsubmit(lua_State *L){
	auto w = getworld(L, 1);
	ecs_api::context ecs {w->ecs};

	for (auto a : ecs.select<ecs::render_args2>()){
		const auto& ra = a.get<ecs::render_args2>();

		const cid_t vs_id = ecs_api::component<ecs::view_visible>::id;
		for (int i=0; entity_iter(w->ecs, vs_id, i); ++i){
			if (entity_visible(w, vs_id, i, ra))
				auto ro = (ecs::render_obj*)entity_sibling(w->ecs, vs_id, i, ecs_api::component<ecs::render_obj>::id);
				// if (ro == nullptr)
				// 	continue;

				//update_transform(w, vs_id, i, ro);


		}
	}
	return 0;
}

extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit", lsubmit},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}