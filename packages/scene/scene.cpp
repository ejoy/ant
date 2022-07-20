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

static inline math_t
to_math_t(int64_t id){
	return math_t{uint64_t(id)};
}

static int
scene_changed(lua_State *L) {
	auto w = getworld(L, 1);
	ecs_api::context ecs {w->ecs};
	auto math3d = w->math3d;

	// step.1
	auto selector = ecs.select<ecs::scene_needchange, ecs::scene_update, ecs::scene>();
	auto it = selector.begin();
	if (it == selector.end()) {
		return 0;
	}
	flatset<int64_t> parents;
	for (; it != selector.end(); ++it) {
		auto& e = *it;
		auto& s = e.get<ecs::scene>();
		if (s.parent != 0) {
			parents.insert(s.parent);
		}
		e.enable_tag<ecs::scene_changed>(ecs);
		e.disable_tag<ecs::scene_needchange>(ecs);
	}

	// step.2
	flatmap<int64_t, math_t> worldmats;
	flatset<int64_t> change;
	for (auto& e : ecs.select<ecs::scene_update, ecs::id>(L)) {
		auto& id = e.get<ecs::id>();
		if (parents.contains(id)) {
			auto s = e.sibling<ecs::scene>(ecs);
			if (s) {
				worldmats.insert_or_assign(id, to_math_t(s->worldmat));
			}
		}
		if (e.sibling<ecs::scene_changed>(ecs)) {
			change.insert(id);
		}
		else {
			auto s = e.sibling<ecs::scene>(ecs);
			if (s && s->parent != 0) {
				if (change.contains(s->parent)) {
					change.insert(id);
					e.enable_tag<ecs::scene_changed>(ecs);
				}
			}
		}
	}

	// step.3
	for (auto& e : ecs.select<ecs::scene_changed, ecs::scene_update, ecs::scene, ecs::id>(L)) {
		auto& id = e.get<ecs::id>();
		auto& s = e.get<ecs::scene>();
		
		auto mat = math3d::pushsrt(math3d, s.s, s.r, s.t);
		if (!mat) {
			return luaL_error(L, "Unexpected Error.");
		}
		auto locmat = math3d::getvalue(math3d, s.mat, LINEAR_TYPE_MAT);
		if (locmat) {
			math3d_mul_matrix(math3d, mat, locmat, mat);
		}
		if (s.parent != 0) {
			auto parentmat = worldmats.find(s.parent);
			if (!parentmat) {
				return luaL_error(L, "Unexpected Error.");
			}
			wm = math3d_mul_matrix(math3d->MC, *parentmat, wm);
		}

		wm = math_mark(math3d->MC, wm);
		s.worldmat = wm.idx;
		worldmats.insert_or_assign(id, wm);

		auto aabb = to_math_t(s.aabb);
		if (!math_isnull(aabb)){
			aabb = math3d_aabb_transform(math3d->MC, wm, aabb);
			aabb = math_mark(math3d->MC, aabb);
			s.scene_aabb = aabb.idx;
		}
	}

	return 0;
}

static int
scene_remove(lua_State *L) {
	auto w = getworld(L, 1);
	ecs_api::context ecs {w->ecs};
	ecs.clear_type<ecs::scene_changed>();
	
	flatset<int64_t> removed;
	for (auto& e : ecs.select<ecs::REMOVED, ecs::scene, ecs::id>()) {
		auto& id = e.get<ecs::id>();
		removed.insert(id);
	}
	if (removed.empty()) {
		return 0;
	}
	for (auto& e : ecs.select<ecs::scene>(L)) {
		auto& s = e.get<ecs::scene>();
		if (s.parent != 0 && removed.contains(s.parent)) {
			auto& id = e.sibling<ecs::id>(ecs, L);
			removed.insert(id);
			e.remove(ecs);
		}
	}
	return 0;
}

extern "C" int
luaopen_system_scene(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "scene_changed", scene_changed },
		{ "scene_remove", scene_remove },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

/*
testscene.lua

local scene = require "scene.core"

local ecs = require "ecs"

local w = ecs.world()

w:register {
	name = "scene",
	"parent:int64",
}

w:register {
	name = "entityid",
	type = "int64",
}

w:register {
	name = "change"
}

local context = w:context {
	"scene_update",
	"scene",
	"id",
	"scene_changed"
}



--[[
    1
   / \
  2   3
 / \
4   5
]]

w:new {
	entityid = 1,
	scene = {
		parent = 0,
	}
}


w:new {
	entityid = 2,
	scene = {
		parent = 1,
	}
}

w:new {
	entityid = 3,
	scene = {
		parent = 1,
	}
}

w:new {
	entityid = 4,
	scene = {
		parent = 2,
	}
}

w:new {
	entityid = 5,
	scene = {
		parent = 2,
	}
}

local function keys(t)
	local r =  {}
	for _, key in ipairs(t) do
		r[key] = true
	end
	return r
end

local changeset = keys { 2, 3 }

for v in w:select "entityid:in scene:in change?out" do
	if changeset[v.entityid] then
		v.change = true
	end
end

local function print_changes()
	for v in w:select "change entityid:in" do
		print(v.entityid, "CHANGE")
	end
end

print_changes()

print "Update"

scene.update_changes(context)

print_changes()

*/
