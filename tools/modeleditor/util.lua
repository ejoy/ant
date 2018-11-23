local util = {}; util.__index = util

local geo = require "editor.ecs.render.geometry"


function util.bones(ske)
	assert(type(ske) == "userdata")

	local vb, ib = geo.cone(3, 1, 0.5, true, true)
	

end

function util.create_aabb_descs(mesh, materialfile)
	local descs = {}
	local _, ib = geo.box_from_aabb(nil, true, true)
	for _, g in ipairs(mesh.assetinfo.handle.groups) do
		local bounding = g.bounding
		local aabb = assert(bounding.aabb)
		
		local vb = geo.box_from_aabb(aabb)
		table.insert(descs, {
			vb = vb,
			ib = ib,
			material = materialfile,
		})
	end
	return descs
end

return util