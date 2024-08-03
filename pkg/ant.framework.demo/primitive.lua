local monitor = require "monitor"

local primitive = {}

function primitive.new(world, name, obj)
	local mat = obj.material
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	end
	world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {	s = obj.s or 1 },
			material 	= "/pkg/ant.resources/materials/primitive.material",
			visible_masks = "main_view|cast_shadow",
			visible     = mat.visible,
			cast_shadow = true,
			receive_shadow = true,
			mesh        = name .. ".primitive",
			on_ready = function (e)
				world.w:extend(e, "eid:in")
				obj.eid = e.eid
				obj.material = monitor.material(world, { e.eid })
				obj.material.visible = mat.visible ~= false
				obj.material.color = mat.color or 0xffffff
				obj.material.emissive = mat.emissive or 0
				monitor.new(obj)
			end
		}
	}
	return obj
end

return primitive