local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
local skinning_mesh = ecs.component "skinning_mesh" {
	ref_path = {
		type = "userdata",
		default = "",
	}
}

-- skinning system
local skinning_sys = ecs.system "skinning_system"
skinning_sys.singleton "math_stack"

function skinning_sys:update()
	for _, eid in world:each("skinning_mesh") do
		local e = world[eid]
		local mesh = assert(e.mesh).assetinfo.handle

		local sm = assert(e.skinning_mesh).assetinfo.handle
		local ske = assert(e.skeleton).assetinfo.handle
		local ani = assert(e.animation).assetinfo.handle

		-- update data include : position, normal, tangent
		local updatedata = animodule.skinning(sm, ani, ske)

		-- update mesh dynamic buffer
		assert(#updatedata == #mesh.groups)
		for idx, g in ipairs(mesh.groups) do
			local ud = updatedata[ud]
			local vb = g.vb
			assert(#vb.handles == #ud.vb)
			for ih, h in ipairs(vb.handles) do
				local info = ud.vb[ih]
				bgfx.update(h, info.start, info.data)
			end

			local ib = g.ib
			if ib then
				local info = ud.ib
				bgfx.update(ib.handle, info.start, info.data)
			end
			
		end
	end
end