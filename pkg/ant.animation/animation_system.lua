local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr = import_package "ant.asset"
local ozz = require "ozz"

local m = ecs.system "animation_system"

function m:component_init()
	for e in w:select "INIT animation:update animation_changed?out" do
		local data = assetmgr.resource(e.animation)
		local skeleton = data.skeleton
		local status = {}
		for name, handle in pairs(data.animations) do
			status[name] = {
				handle = handle,
				sampling = ozz.SamplingJobContext(handle:num_tracks()),
				ratio = nil,
			}
		end
		e.animation = {
			skeleton = skeleton,
			status = status,
			locals = nil,
			models = ozz.MatrixVector(skeleton:num_joints()),
		}
		e.animation_changed = true
	end
end

local function sampling(ani)
	local skeleton = ani.skeleton
	for _, status in pairs(ani.status) do
		if status.ratio then
			--TODO: blend
			if not ani.locals then
				ani.locals = ozz.SoaTransformVector(skeleton:num_soa_joints())
			end
			ozz.SamplingJob(status.handle, status.sampling, ani.locals, status.ratio)
			ozz.LocalToModelJob(skeleton, ani.locals, ani.models)
			return
		end
	end
	ozz.LocalToModelJob(skeleton, nil, ani.models)
end

function m:animation_sample()
	for e in w:select "animation_changed animation:in" do
		sampling(e.animation)
	end
	w:clear "animation_changed"
end
