#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include <bee/utility/flatmap.h>
#include <glm/glm.hpp>
#include <glm/gtc/quaternion.hpp>
#include <cstdio>

extern "C" {
	#include "math3d.h"
	#include "math3dfunc.h"
}

struct math3d_checkpoint {
	math3d_checkpoint(struct math_context* math3d)
		: math3d(math3d) {
		cp = math_checkpoint(math3d);
	}
	~math3d_checkpoint() {
		math_recover(math3d, cp);
	}
	struct math_context* math3d;
	int cp;
};

static void
math3d_update(struct math_context* math3d, math_t& id, math_t const& m) {
	int r = math_unmark(math3d, id);
	assert(r >= 0);
	(void)r;
	id = math_mark(math3d, m);
}

static bool
worldmat_update(bee::flatmap<component::eid, math_t>& worldmats, struct math_context* math3d, component::scene& s, component::eid& id, struct ecs_world *w) {
	math_t mat = math3d_make_srt(math3d, s.s, s.r, s.t);
	if (!math_isnull(s.mat)) {
		mat = math3d_mul_matrix(math3d, mat, s.mat);
	}
	if (s.parent != 0) {
		auto parentmat = worldmats.find(s.parent);
		if (!parentmat) {
			if (w) {
				if ((component::eid)s.parent >= id)
					return false;
				auto e = ecs::find_entity(w->ecs, (component::eid)s.parent);
				if (e.invalid()) {
					return false;
				}
				component::scene *ps = e.component<component::scene>();
				if (ps == nullptr) {
					return false;
				}
				parentmat = &ps->worldmat;
				worldmats.insert_or_assign(s.parent, ps->worldmat);
			} else {
				return false;
			}
		}
		mat = math3d_mul_matrix(math3d, *parentmat, mat);
	}
	math3d_update(math3d, s.worldmat, mat);
	worldmats.insert_or_assign(id, s.worldmat);
	return true;
}

#define MUTABLE_TICK 128

static int
entity_init(lua_State *L) {
	auto w = getworld(L);

	for (auto& e : ecs::select<component::INIT, component::scene>(w->ecs)) {
		auto& s = e.get<component::scene>();
		s.movement = 0;
		e.enable_tag<component::scene_mutable>();
		e.enable_tag<component::scene_needchange>();
	}
	return 0;
}

static inline bool
is_constant(struct ecs_world *w, component::eid eid) {
	auto e = ecs::find_entity(w->ecs, eid);
	if (e.invalid()) {
		return false;
	}
	return !e.component<component::scene_mutable>();
}

static inline bool
is_changed(bee::flatset<component::eid> &changed, component::eid eid) {
	return changed.contains(eid);
}

static void
rebuild_mutable_set(struct ecs_world *w, bee::flatset<component::eid> &changed) {
	using namespace ecs::flags;
	for (auto& e : ecs::select< component::scene, component::scene_mutable(absent), component::eid>(w->ecs)) {
		auto& s = e.get<component::scene>();
		if (s.parent != 0 && is_changed(changed, s.parent)) {
			e.enable_tag<component::scene_mutable>();
			changed.insert(e.get<component::eid>());
		}
	}
}

static int
scene_changed(lua_State *L) {
	auto w = getworld(L);
	auto math3d = w->math3d->M;
	math3d_checkpoint cp(math3d);

	bee::flatset<component::eid> changed;

	// step.1
	auto selector = ecs::select<component::scene_needchange, component::eid>(w->ecs);
	auto it = selector.begin();
	if (it == selector.end()) {
		return 0;
	}
	bool need_rebuild_mutable_set = false;
	for (; it != selector.end(); ++it) {
		auto& e = *it;
		if (!e.component<component::scene_mutable>()) {
			need_rebuild_mutable_set = true;
			e.enable_tag<component::scene_mutable>();
		}
		auto eid = e.get<component::eid>();
		changed.insert(eid);
	}

	ecs::clear_type<component::scene_needchange>(w->ecs);

	if (need_rebuild_mutable_set) {
		rebuild_mutable_set(w, changed);
	}

	// step.2
	bee::flatmap<component::eid, math_t> worldmats;
	for (auto& e : ecs::select<component::scene_mutable, component::scene, component::eid>(w->ecs)) {
		auto& s = e.get<component::scene>();
		component::eid id = e.get<component::eid>();
		auto selfchanged = is_changed(changed, id);
		if (selfchanged || (s.parent != 0 && is_changed(changed, s.parent))) {
			e.enable_tag<component::scene_changed>();
			if (!worldmat_update(worldmats, math3d, s, id, w)) {
				return luaL_error(L, "entity(%d)'s parent(%d) cannot be found.", id, s.parent);
			}
			s.movement = w->frame;
			if (!selfchanged){
				changed.insert(id);
			}
		} else if (w->frame - s.movement > MUTABLE_TICK &&
			(s.parent == 0 || is_constant(w, s.parent))) {
			e.disable_tag<component::scene_mutable>();
		}
	}

	++w->frame;

	return 0;
}

static int
end_frame(lua_State *L) {
	auto w = getworld(L);
	ecs::clear_type<component::scene_changed>(w->ecs);
	return 0;
}

static int
scene_remove(lua_State *L) {
	auto w = getworld(L);

	auto selector = ecs::select<component::REMOVED, component::scene>(w->ecs);
	auto it = selector.begin();
	if (it == selector.end()) {
		return 0;
	}

	entity_propagate_tag(w->ecs, ecs::component_id<component::scene>, ecs::component_id<component::REMOVED>);

	return 0;
}

static int
bounding_update(lua_State *L){
	auto w = getworld(L);
	auto math3d = w->math3d->M;
	math3d_checkpoint cp(math3d);
	for (auto& e : ecs::select<component::scene_changed, component::bounding, component::scene>(w->ecs)){
		auto &b = e.get<component::bounding>();
		if (math_isnull(b.aabb))
			continue;
		const auto &s = e.get<component::scene>();
		const math_t aabb = math3d_aabb_transform(math3d, s.worldmat, b.aabb);
		math3d_update(math3d, b.scene_aabb, aabb);
	}
	return 0;
}

extern "C" int
luaopen_system_scene(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "entity_init", entity_init },
		{ "scene_changed", scene_changed },
		{ "end_frame", end_frame },
		{ "scene_remove", scene_remove },
		{ "bounding_update", bounding_update},
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
