local monitor = require "monitor"

local primitive = {}

local function remove_primitive(world, self)
	world:remove_entity(self.eid)
end

function primitive.new(world, name, obj)
	local mat = obj.material
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	end
	local eid; eid = world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {},
			material 	= "/pkg/ant.resources/materials/primitive.material",
			visible_masks = "main_view|cast_shadow",
			visible     = mat.visible,
			cast_shadow = true,
			receive_shadow = true,
			mesh        = name .. ".primitive",
			on_ready = function ()
				obj.eid = eid
				obj.material = monitor.material(world, { eid })
				obj.material.visible = mat.visible ~= false
				obj.material.color = mat.color or 0xffffff
				monitor.new(obj, remove_primitive)
			end
		}
	}
	return obj
end

return primitive