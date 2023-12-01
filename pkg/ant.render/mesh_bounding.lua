local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant

local b = ecs.system "mesh_bounding_system"

local function init_bounding(bounding, bb)
    if bb and bb.aabb ~= mc.NULL then
		local aabb = bb.aabb
		math3d.unmark(bounding.aabb)
        bounding.aabb = math3d.marked_aabb(aabb[1], aabb[2])
		math3d.unmark(bounding.scene_aabb)
        bounding.scene_aabb = math3d.marked_aabb(math3d.array_index(bounding.aabb, 1), math3d.array_index(bounding.aabb, 2))
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