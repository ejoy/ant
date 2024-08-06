local ltask = require "ltask"
local monitor = require "monitor"
local assetmgr = import_package "ant.asset"
local math3d = require "math3d"

local sprite2d = {}

local function remove_sprite2d(world, self)
	world:remove_entity(self.eid)
end

local base_scale = 1 / 128

function sprite2d.base(size)
	base_scale = 1 / size
end

local unmark = math3d.unmark
local marked_v = math3d.marked_vector

function sprite2d.new(world, texture, obj)
	local mat = obj.material
	if mat == nil then
		mat = { visible = true }
		obj.material = mat
	end
	
	ltask.fork(function()
		-- load texture first
		local texture_info = assetmgr.resource(texture)
		local info = assert(texture_info.texinfo)
		local mesh, width, height, dx, dy
		local atlas = info.atlas
		if atlas then
			width = atlas.w
			height = atlas.h
			local inv_w = 1 / info.width
			local inv_h = 1 / info.height
			local u0 = atlas.x * inv_w
			local v0 = atlas.y * inv_h
			local u1 = atlas.dw * inv_w + u0
			local v1 = atlas.dh * inv_h + v0
			mesh = ("quad(%g,%g,%g,%g).primitive"):format(u0,v0,u1,v1)
			dx = atlas.dx * base_scale
			dy = atlas.dy * base_scale
		else
			mesh = "quad.primitive"
			width = info.width
			height = info.height
			dx = 0
			dy = 0
		end
		
		local scale_x = width * base_scale
		local scale_y = height * base_scale
		
		-- root entity
		local root_id = world:create_entity {
			policy = { "ant.scene|scene_object"},
			data = { scene = {}	},
		}
		-- sprite entity
		local eid; eid = world:create_entity {
			policy = {	"ant.render|render" },
			data = {
				scene = {
					parent = root_id,
					s = { scale_x, scale_y, 1},
					t = { dx, dy, 0 },
				},
				material 	= "/pkg/ant.resources/materials/sprite2d.material",
				visible_masks = "main_view|cast_shadow",
				visible     = mat.visible,
				cast_shadow = true,
				render_layer = "translucent",
				mesh        = mesh,
				on_ready = function (e)
					obj.eid = root_id
					entity_id = eid
					obj.material = monitor.material(world, { eid })
					obj.material.visible = mat.visible ~= false
					obj.material.color = mat.color or 0xffffff
					
					world.w:extend(e, "filter_material:in")
					local mi = e.filter_material
					local tid = texture_info.id
					mi[0].s_basecolor = tid
					mi.SHADOW_MATERIAL.s_alphamask = tid
					monitor.new(obj, remove_sprite2d)
				end
			}
		}
	end)
	
	return obj
end

return sprite2d