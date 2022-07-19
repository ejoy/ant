#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include "math3d.h"
#include "lua.hpp"

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
// static inline void
// update_transform(struct ecs_world* w, const ecs::render_obj *ro){
// 	if (ro->matnum > 1){
// 		BGFX(set_transform)(ro->worldmat, ro->matnum);
// 	} else {
// 		int type;
// 		const float* m = math3d_value(w->math3d, ro->worldmat, &type);
// 		BGFX(set_transform)(m, 1);
// 	}
// }

static inline void
update_material(struct ecs_world* w){

}

static inline void
update_mesh(){

}

static inline void
submit_draw(){

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