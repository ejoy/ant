local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local math3d = require "math3d"

local gt = ecs.transform "generate_transform"
local function set_world_matrix(rc)
	bgfx.set_transform(rc.worldmat)
end

function gt.process_entity(e)
    e._rendercache.set_transform= set_world_matrix
	e._rendercache.srt			= math3d.ref(math3d.matrix(e.transform))
end