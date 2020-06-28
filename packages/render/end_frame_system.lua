local ecs = ...
local world = ecs.world

local math3d 	= require "math3d"

local end_frame_sys = ecs.system "end_frame_system"

function end_frame_sys:end_frame()
	for _, eid in world:each "scene_entity" do
		local rc = world[eid]._rendercache
		rc.worldmat = nil
		rc.viewmat = nil
		rc.projmat = nil
	end

	math3d.reset()
end
