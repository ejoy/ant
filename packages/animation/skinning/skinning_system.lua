local ecs = ...
local world = ecs.world
local schema = ecs.schema

local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
schema:typedef("skinning_mesh", "resource")

-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

function skinning_sys:update()
	for _, eid in world:each("skinning_mesh") do
		local e = world[eid]
		local mesh = assert(e.mesh).assetinfo.handle

		local sm = assert(e.skinning_mesh).assetinfo.handle				
		local aniresult = assert(e.animation).aniresult
		
		-- update data include : position, normal, tangent
		animodule.skinning(sm, aniresult)

		-- update mesh dynamic buffer
		assert(1 == #mesh.groups)
		local g = mesh.groups[1]
		local vb = g.vb		
		local buffer, size = sm:buffer("dynamic")
		local h = vb.handles[1]
		bgfx.update(h, 0, {"!", buffer, size})
	end
end