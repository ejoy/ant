local ecs = ...
local world = ecs.world

local ms = require "math.stack"

local physic_sys = ecs.system "physic_system"
physic_sys.dependby "primitive_filter"

function physic_sys:update()
	local phy_world = world.args.physic_world
	-- phy_world:step()

	for _, eid in world:each("rigid_body") do
		local e = world[eid]

		local meshcomp = e.mesh
		local mesh = meshcomp.assetinfo.handle
		local sphere = mesh.groups.bounding.sphere
		local center = ms({type="srt", s=e.scale, r=e.rotation, t=e.position}, sphere.center, "*T")		
		local to = {0, center.y - sphere.radius, 0}
		local hitted, result = phy_world:raycast(center, to)
		if hitted then			
			local hitpt = result.hit_pt_in_WS
			ms(e.position, hitpt, "=")
		end
	end
end