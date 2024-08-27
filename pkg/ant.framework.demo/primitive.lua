local monitor = require "monitor"

local primitive = {}

local function remove_primitive(world, self)
	world:remove_entity(self.eid)
end

function primitive.new(world, name, obj)
	local mat = obj.material
	local trans
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	elseif mat.color then
		trans = (mat.color >> 24) > 0
	end
	local render_layer
	local material = "/pkg/ant.resources/materials/primitive.material"
	if trans then
		render_layer = "translucent"
		material = "/pkg/ant.resources/materials/primitive_translucent.material"
	end
	local eid; eid = world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene = {},
			render_layer = render_layer,
			material = material,
			visible_masks = "main_view|cast_shadow",
			visible = mat.visible,
			cast_shadow = true,
			receive_shadow = true,
			mesh = name .. ".primitive",
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