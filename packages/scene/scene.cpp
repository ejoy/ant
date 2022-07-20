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

namespace math3d {
	static const float* getvalue(struct lastack *LS, int64_t id, int type) {
		int t;
		const float* res = lastack_value(LS, id, &t);
		if (t != type) {
			return NULL;
		}
		return res;
	}

	static float* pushsrt(struct lastack *LS, int64_t s, int64_t r, int64_t t) {
		const float* scale = getvalue(LS, s, LINEAR_TYPE_VEC4);
		const float* rot = getvalue(LS, r, LINEAR_TYPE_QUAT);
		const float* translate = getvalue(LS, t, LINEAR_TYPE_VEC4);
		if (!scale || !rot || !translate) {
			return NULL;
		}
		float* mat = lastack_allocmatrix(LS);
		glm::mat4x4& srt = *(glm::mat4x4*)mat;
		srt = glm::mat4x4(1);
		srt[0][0] = scale[0];
		srt[1][1] = scale[1];
		srt[2][2] = scale[2];
		srt = glm::mat4x4(*(const glm::quat*)rot) * srt;
		srt[3][0] = translate[0];
		srt[3][1] = translate[1];
		srt[3][2] = translate[2];
		srt[3][3] = 1;
		return mat;
	}

	static void pop_then_mark(struct lastack *LS, int64_t& id) {
		lastack_unmark(LS, id);
		id = lastack_mark(LS, lastack_pop(LS));
	}
}

static int
scene_changed(lua_State *L) {
	auto w = getworld(L, 1);
	ecs_api::context ecs {w->ecs};
	auto math3d = w->math3d->LS;

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
		ecs.enable_tag<ecs::scene_changed>(e);
		ecs.disable_tag<ecs::scene_needchange>(e);
	}

	// step.2
	flatmap<int64_t, int64_t> worldmats;
	flatset<int64_t> change;
	for (auto& e : ecs.select<ecs::scene_update, ecs::id>(L)) {
		auto& id = e.get<ecs::id>();
		if (parents.contains(id)) {
			auto s = ecs.sibling<ecs::scene>(e);
			if (s) {
				worldmats.insert_or_assign(id, s->worldmat);
			}
		}
		if (ecs.sibling<ecs::scene_changed>(e)) {
			change.insert(id);
		}
		else {
			auto s = ecs.sibling<ecs::scene>(e);
			if (s && s->parent != 0) {
				if (change.contains(s->parent)) {
					change.insert(id);
					ecs.enable_tag<ecs::scene_changed>(e);
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
			math3d_mul_matrix(math3d, locmat, mat, mat);
		}
		if (s.parent != 0) {
			auto parentmatid = worldmats.find(s.parent);
			if (!parentmatid) {
				return luaL_error(L, "Unexpected Error.");
			}
			auto parentmat = math3d::getvalue(math3d, *parentmatid, LINEAR_TYPE_MAT);
			assert(parentmat);
			math3d_mul_matrix(math3d, parentmat, mat, mat);
		}
		math3d::pop_then_mark(math3d, s.worldmat);
		worldmats.insert_or_assign(id, s.worldmat);

		int type;
		const float* aabb = lastack_value(math3d, s.aabb, &type);
		if (type != LINEAR_TYPE_NULL) {
			if (type != LINEAR_TYPE_MAT) {
				return luaL_error(L, "Unexpected Error.");
			}
			math3d_aabb_transform(math3d, mat, aabb, lastack_allocmatrix(math3d));
			math3d::pop_then_mark(math3d, s.scene_aabb);
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
			auto id = ecs.sibling<ecs::id>(e);
			removed.insert(*id);
			ecs.remove(e);
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
