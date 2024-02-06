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

struct cullqueue_info{
	math_t	mid;
	int 	Qidx;
};

struct cullqueue_cache {
	uint16_t count = 0;
	struct cullqueue_info cq[MAX_VISIBLE_QUEUE];
	struct ecs_world *w;
	cullqueue_cache(struct ecs_world *w_) : w(w_){}
	~cullqueue_cache(){
		clear();
	}

	bool empty() const {
		return count == 0;
	}

	struct cullqueue_info& find_cullqueue(math_t mid) {
		for (uint16_t ii=0; ii<count; ++ii){
			if (cq[ii].mid.idx == mid.idx){
				return cq[ii];
			}
		}
		assert(count < MAX_VISIBLE_QUEUE);
		struct cullqueue_info& q = cq[count++];
		q.mid = mid;
		q.Qidx = queue_alloc(w->Q);

		return q;
	}

	void clear(){
		for (uint16_t ii=0; ii<count; ++ii){
			queue_dealloc(w->Q, cq[ii].Qidx);
		}
	}

	void add_queue(math_t mid, uint8_t queue_index){
		struct cullqueue_info& q = find_cullqueue(mid);
		queue_set(w->Q, q.Qidx, queue_index, true);
	}
};

struct cull_cached {
	cull_cached(struct ecs_context* ctx) : render_obj(ctx), hitch_obj(ctx){}
	ecs::cached_context<component::render_object_visible, component::render_object, component::bounding> render_obj;
	ecs::cached_context<component::hitch_visible, component::hitch, component::bounding> hitch_obj;
}; 

template<typename ObjType>
struct cull_operation{
	template<typename EntityType>
	static void cull(struct ecs_world*w, EntityType &e, struct cullqueue_cache *cc){
		const auto &b = e.template get<component::bounding>();

		if (!math_isnull(b.scene_aabb)){
			auto &o = e.template get<ObjType>();
			for (uint8_t ii=0; ii<cc->count; ++ii){
				struct cullqueue_info& q = cc->cq[ii];
				const bool isculled = math3d_frustum_intersect_aabb(w->math3d->M, q.mid, b.scene_aabb) < 0;
				queue_set_by_index(w->Q, o.cull_idx, q.Qidx, isculled);
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

static int
lcull(lua_State *L) {
	auto w = getworld(L);

	cullqueue_cache cqc(w);

	for (auto& i : ecs::array<component::cull_args>(w->ecs)){
		cqc.add_queue(i.frustum_planes, i.queue_index);
	}

	if (!cqc.empty()){
		for (auto e : ecs::cached_select(w->cull_cached->render_obj)) {
			cull_operation<component::render_object>::cull(w, e, &cqc);
		}

		for (auto& e : ecs::cached_select(w->cull_cached->hitch_obj)) {
			cull_operation<component::hitch>::cull(w, e, &cqc);
		}
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
