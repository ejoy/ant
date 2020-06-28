local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local bgfx = require "bgfx"
local gt = ecs.transform "generate_transform"
local function set_world_matrix(rc)
	bgfx.set_transform(rc.worldmat)
end

function gt.process_entity(e)
    e._rendercache.set_transform= set_world_matrix
	e._rendercache.srt			= math3d.ref(math3d.matrix(e.transform))
end

local it = ecs.interface "itransform"
function it.worldmat(eid)
	return world[eid]._rendercache.worldmat
end

function it.srt(eid)
    return world[eid]._rendercache.srt
end

function it.set(eid, s, r, t)
    world[eid]._rendercache.srt.m = {s=s, r=r, t=t}
end

function it.set_srt(eid, srt)
    world[eid]._rendercache.srt.m = srt
end