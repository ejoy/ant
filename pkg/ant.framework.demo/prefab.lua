local monitor = require "monitor"

local prefab = {}

function prefab.new(world, name, obj)
	local mat = obj.material
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	end
	world:create_instance {
		prefab = name .. "/mesh.prefab",
		on_ready = function (inst)
			local eid_list = inst.tag["*"]
			local eid = eid_list[1]
			obj.eid = eid
			local mat = obj.material
			obj.material = monitor.material(world, eid_list)
			obj.material.visible = mat.visible ~= false
			obj.material.color = mat.color or 0xffffff
			obj.material.emissive = mat.emissive or 0
			monitor.new(obj)
		end,
	}
	
	return obj
end

return prefab