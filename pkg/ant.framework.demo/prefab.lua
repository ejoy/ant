local monitor = require "monitor"

local prefab = {}

local function remove_prefab(world, self)
	world:remove_instance(self.inst)
end

function prefab.new(world, name, obj)
	local mat = obj.material
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	end
	world:create_instance {
		prefab = name,
		on_ready = function (inst)
			local eid_list = inst.tag["*"]
			local eid = eid_list[1]
			obj.eid = eid
			obj.inst = inst
			local mat = obj.material
			obj.material = monitor.material(world, eid_list)
			obj.material.visible = mat.visible ~= false
			obj.material.color = mat.color or 0xffffff
			monitor.new(obj, remove_prefab)
		end,
	}
	
	return obj
end

return prefab