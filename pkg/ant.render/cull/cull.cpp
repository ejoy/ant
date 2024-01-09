#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include "../render/queue.h"

#include <cassert>
#include <cstring>
#include <memory>
#include <unordered_map>
#include <vector>
#include <algorithm>


using tags = std::vector<int>;
using cull_infos = std::unordered_map<uint64_t, tags>;

struct cullinfo{
	math_t	mid;
	uint8_t n;
	uint8_t	queue_indices[256];
};

struct cull_cached {
	cull_cached(struct ecs_context* ctx) : render_obj(ctx), hitch_obj(ctx){}
	ecs::cached_context<component::render_object_visible, component::render_object, component::bounding> render_obj;
	ecs::cached_context<component::hitch_visible, component::hitch, component::bounding> hitch_obj;
}; 

static inline void
set_mark(int64_t &s, uint64_t m, bool set){
	s = set ? (s|m) : (s&(~m));
}

template<typename ObjType>
struct cull_operation{
	template<typename EntityType>
	static void cull(struct ecs_world*w, EntityType &e, struct cullinfo *ci, uint8_t c){
		const auto &b = e.template get<component::bounding>();

		if (!math_isnull(b.scene_aabb)){
			auto &o = e.template get<ObjType>();
			for (uint8_t ii=0; ii<c; ++ii){
				const bool isculled = math3d_frustum_intersect_aabb(w->math3d->M, ci[ii].mid, b.scene_aabb) < 0;
				for (uint8_t iq=0; iq<ci[ii].n; ++iq){
					queue_set(w->Q, o.cull_idx, ci[ii].queue_indices[iq], isculled);
				}
				//set_mark(o.cull_masks, ci[ii].masks, isculled);
			}
		}
	}
};

static int
linit(lua_State *L) {
	auto w = getworld(L);
	w->cull_cached = new struct cull_cached(w->ecs);
	return 0;
}

static int
lexit(lua_State *L) {
	auto w = getworld(L);
	delete w->cull_cached;
	return 0;
}

constexpr uint8_t MAX_QUEUE_COUNT = 64;

static int
lcull(lua_State *L) {
	auto w = getworld(L);

	uint8_t c = 0;
	struct cullinfo ci[MAX_QUEUE_COUNT];

	auto add_cull_info = [&ci, &c](math_t mid, uint8_t queue_index){
		assert(c < MAX_QUEUE_COUNT);

		uint8_t idx = MAX_QUEUE_COUNT;
		for (uint8_t ii=0; ii<c; ++ii){
			if (ci[ii].mid.idx == mid.idx){
				idx = ii;
				break;
			}
		}
		if (idx == MAX_QUEUE_COUNT){
			struct cullinfo i;
			i.mid = mid;
			i.queue_indices[0] = queue_index;
			i.n = 1;
			ci[c++] = i;
		} else {
			auto &i = ci[idx];
			assert(i.n < 256);
			i.queue_indices[i.n++] = queue_index;
		}
	};

	for (auto& i : ecs::array<component::cull_args>(w->ecs)){
		add_cull_info(i.frustum_planes, i.queue_index);
	}

	if (0 == c)
		return 0;

	for (auto e : ecs::cached_select(w->cull_cached->render_obj)) {
		cull_operation<component::render_object>::cull(w, e, ci, c);
	}

	for (auto& e : ecs::cached_select(w->cull_cached->hitch_obj)) {
		cull_operation<component::hitch>::cull(w, e, ci, c);
	}

	return 0;
}

extern "C" int
luaopen_system_cull(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "exit", lexit },
		{ "cull", lcull },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
