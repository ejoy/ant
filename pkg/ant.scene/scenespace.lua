local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant

local b = ecs.system "bounding_system"

local function init_bounding(bounding, bb)
    if bb and bb.aabb ~= mc.NULL then
		local aabb = bb.aabb
		local aabbmin, aabbmax = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
		-- copy 2 aabb
		math3d.unmark(bounding.aabb)
        bounding.aabb = math3d.mark(math3d.aabb(aabbmin, aabbmax))
		math3d.unmark(bounding.scene_aabb)
        bounding.scene_aabb = math3d.mark(math3d.aabb(aabbmin, aabbmax))
    end
end

function b:entity_init()
	for e in w:select "INIT bounding:update mesh?in simplemesh?in" do
		local m = e.mesh or e.simplemesh
		if m then
			init_bounding(e.bounding, m.bounding)
		end
	end
end

local sceneupdate_sys = ecs.system "scene_update_system"
function sceneupdate_sys:init()
	ecs.group(0):enable "scene_update"
	ecs.group_flush()
end

local g_sys = ecs.system "group_system"
function g_sys:start_frame()
	ecs.group_flush()
end
