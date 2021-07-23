local ecs = ...
local world = ecs.world

local math3d 	= require "math3d"
local start_frame_sys = ecs.system "start_frame_system"

function start_frame_sys:start_frame()
	for _, eid in world:each "scene_entity" do
		local rc = world[eid]._rendercache
		rc.worldmat = nil
		rc.viewmat = nil
		rc.projmat = nil
		rc.viewprojmat = nil
	end
	math3d.reset()
end
