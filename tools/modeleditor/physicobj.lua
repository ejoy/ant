local physicobj = {}; physicobj.__index = {}

local bu = require "bullet.lua.util"
local bgfx = require "bgfx"

local plane_obj_user_idx = 2

local comp_util = require "render.components.util"

function physicobj.create_plane_entity(world)
	local eid = world:new_entity("position", "rotation", "scale",
		"mesh", "material",
		"rigid_body",
		"name", "can_render")

	local plane = world[eid]
	local function create_plane_mesh_info()
		local decl = bgfx.vertex_decl {
			{ "POSITION", 3, "FLOAT" },
            { "NORMAL", 3, "FLOAT" },
            { "COLOR0", 4, "UINT8", true },
		}
		local unit = 5
		local half_unit = unit * 0.5
		return {
			handle = {
				groups = {
					{
						bounding = {
							aabb = {
								min = {},
								max = {},
							},
							sphere = {
								center = {},
								radius = 1,
							}
						},
						vb = {
							decls = {decl},
							handles = {
								bgfx.create_vertex_buffer(
									{
										"ffffffd",
										-half_unit, 0, half_unit,
										0, 1, 0,
										0xff080808,

										half_unit, 0, half_unit,
										0, 0, 0,
										0xff080808,

										half_unit, 0, -half_unit,
										0, 0, 0,
										0xff080808,
									},
									decl)
							}
						},					
					}
				}
			}
		}
	end

	plane.mesh.assetinfo = create_plane_mesh_info()

	local smaplemaerial = "skin_model_sample.material"
	comp_util.load_material(plane.material,{smaplemaerial})

	-- rigid_body
	local rigid_body = plane.rigid_body
	local shape = {type="plane", nx=0, ny=1, nz=0, distance=10}

	local physic_world = world.args.physic_world
	shape.handle = bu.create_shape(physic_world, shape.type, shape)
	table.insert(rigid_body.shapes, shape)

	rigid_body.obj.handle = physic_world:new_obj(shape.handle, plane_obj_user_idx, {0, 0, 0}, {0, 0, 0, 1})
	rigid_body.obj.useridx = plane_obj_user_idx
end

return physicobj