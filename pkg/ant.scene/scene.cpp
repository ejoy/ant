#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include "flatmap.h"
#include <glm/glm.hpp>
#include <glm/gtc/quaternion.hpp>

extern "C" {
	#include "math3d.h"
	#include "math3dfunc.h"
}

static void
math_update(struct math_context* math3d, math_t& id, math_t const& m) {
	math_unmark(math3d, id);
	id = math_mark(math3d, m);
}

static bool
worldmat_update(flatmap<ecs::eid, math_t>& worldmats, struct math_context* math3d, ecs::scene& s, ecs::eid& id) {
	math_t mat = math3d_make_srt(math3d, s.s, s.r, s.t);
	if (!math_isnull(s.mat)) {
		mat = math3d_mul_matrix(math3d, mat, s.mat);
	}
	if (s.parent != 0) {
		auto parentmat = worldmats.find(s.parent);
		if (!parentmat) {
			return false;
		}
		mat = math3d_mul_matrix(math3d, *parentmat, mat);
	}
	math_update(math3d, s.worldmat, mat);
	worldmats.insert_or_assign(id, s.worldmat);
	return true;
}

static int
entity_init(lua_State *L) {
	auto w = getworld(L);

	using namespace ecs_api::flags;
	for (auto& e : ecs_api::select<ecs::INIT, ecs::scene, ecs::scene_update_once(absent)>(w->ecs)) {
		e.enable_tag<ecs::scene_needchange>();
	}
	return 0;
}

static int
scene_changed(lua_State *L) {
	auto w = getworld(L);
	auto math3d = w->math3d->M;

	size_t UpdateOnceCount = ecs_api::count<ecs::scene_update_once>(w->ecs);
	if (UpdateOnceCount > 0) {
		flatmap<ecs::eid, math_t> worldmats;
		worldmats.reserve(UpdateOnceCount);
		for (auto& e : ecs_api::select<ecs::scene_update_once, ecs::scene, ecs::eid>(w->ecs)) {
			auto& s = e.get<ecs::scene>();
			auto id = e.get<ecs::eid>();
			e.disable_tag<ecs::scene_update>();
			e.enable_tag<ecs::scene_changed>();
			if (!worldmat_update(worldmats, math3d, s, id)) {
				return luaL_error(L, "entity(%d)'s parent(%d) cannot be found.", id, s.parent);
			}
		}
		ecs_api::clear_type<ecs::scene_update_once>(w->ecs);
	}

	// step.1
	auto selector = ecs_api::select<ecs::scene_needchange, ecs::scene_update, ecs::scene>(w->ecs);
	auto it = selector.begin();
	if (it == selector.end()) {
		return 0;
	}
	flatset<ecs::eid> parents;
	for (; it != selector.end(); ++it) {
		auto& e = *it;
		auto& s = e.get<ecs::scene>();
		if (s.parent != 0) {
			parents.insert(s.parent);
		}
		e.enable_tag<ecs::scene_changed>();
		e.disable_tag<ecs::scene_needchange>();
	}

	// step.2
	flatmap<ecs::eid, math_t> worldmats;
	flatset<ecs::eid> change;
	for (auto& e : ecs_api::select<ecs::scene_update, ecs::eid>(w->ecs)) {
		auto id = e.get<ecs::eid>();
		if (parents.contains(id)) {
			auto s = e.sibling<ecs::scene>();
			if (s) {
				worldmats.insert_or_assign(id, s->worldmat);
			}
		}
		if (e.sibling<ecs::scene_changed>()) {
			change.insert(id);
		}
		else {
			auto s = e.sibling<ecs::scene>();
			if (s && s->parent != 0) {
				if (change.contains(s->parent)) {
					change.insert(id);
					e.enable_tag<ecs::scene_changed>();
				}
			}
		}
	}

	// step.3
	for (auto& e : ecs_api::select<ecs::scene_changed, ecs::scene_update, ecs::scene, ecs::eid>(w->ecs)) {
		auto& s = e.get<ecs::scene>();
		auto id = e.get<ecs::eid>();
		if (!worldmat_update(worldmats, math3d, s, id)) {
			return luaL_error(L, "entity(%d)'s parent(%d) cannot be found.", id, s.parent);
		}
	}

	return 0;
}

static int
scene_remove(lua_State *L) {
	auto w = getworld(L);
	ecs_api::clear_type<ecs::scene_changed>(w->ecs);
	
	flatset<ecs::eid> removed;
	for (auto& e : ecs_api::select<ecs::REMOVED, ecs::scene, ecs::eid>(w->ecs)) {
		auto id = e.get<ecs::eid>();
		removed.insert(id);
	}
	if (removed.empty()) {
		return 0;
	}
	for (auto& e : ecs_api::select<ecs::scene>(w->ecs)) {
		auto& s = e.get<ecs::scene>();
		if (s.parent != 0 && removed.contains(s.parent)) {
			auto id = e.sibling<ecs::eid>();
			removed.insert(id);
			e.remove();
		}
	}
	return 0;
}

static int
bounding_update(lua_State *L){
	auto w = getworld(L);
	auto math3d = w->math3d->M;

	for (auto& e : ecs_api::select<ecs::scene_changed, ecs::bounding, ecs::scene>(w->ecs)){
		auto &b = e.get<ecs::bounding>();
		if (math_isnull(b.aabb))
			continue;
		const auto &s = e.get<ecs::scene>();
		const math_t aabb = math3d_aabb_transform(math3d, s.worldmat, b.aabb);
		math_update(math3d, b.scene_aabb, aabb);
	}
	return 0;
}

extern "C" int
luaopen_system_scene(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "entity_init", entity_init },
		{ "scene_changed", scene_changed },
		{ "scene_remove", scene_remove },
		{ "bounding_update", bounding_update},
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
