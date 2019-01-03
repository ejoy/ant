local ecs = ...
local world = ecs.world

ecs.import "render.camera.camera_component"

-- entity
ecs.import "editor.ecs.editor_component"

local bgfx  = require "bgfx"
local cu 	= require "render.components.util"
local mu  	= require "math.util"
local ms = require "math.stack"
local fs = require "filesystem"
local computil = require "render.components.util"

local general_editor_entites = ecs.system "general_editor_entites"

general_editor_entites.depend "camera_init"

--luacheck: ignore self
function general_editor_entites:init()
    local vdecl = bgfx.vertex_decl {
        { "POSITION", 3, "FLOAT" },
        { "COLOR0", 4, "UINT8", true }
    }

    do
		local axisid = world:new_entity(
			"rotation", "position", "scale", 
			"can_render", "editor",
			"mesh", "material",
			"name")
        local axis = world[axisid]

        mu.identify_transform(axis)

		axis.name = "axis-tips"
		
		axis.mesh.ref_path = ""	-- runtime mesh info
		axis.mesh.assetinfo = {
			handle = {
				groups = {
					{						
						vb = {
							decls = {
								vdecl
							},
							handles = {
								bgfx.create_vertex_buffer({"fffd",
								0.0, 0.0, 0.0, 0xff0000ff,  -- x-axis
								1.0, 0.0, 0.0, 0xff0000ff,
								0.0, 0.0, 0.0, 0xff00ff00,  -- y-axis
								0.0, 1.0, 0.0, 0xff00ff00,
								0.0, 0.0, 0.0, 0xffff0000,  -- z-axis
								0.0, 0.0, 1.0, 0xffff0000}, vdecl)
							},
						}
					},
				}
			}
		}
		
		cu.load_material(axis.material,{fs.path "line.material",})
    end

    do
		cu.create_gird_entity(world)
	end

	do
		local frustum_debug_eid = world:new_entity("position", "scale", "rotation",
		"can_render", "mesh", "material", 
		"name",
		"can_select")

		local frusutm_debug = world[frustum_debug_eid]
		frusutm_debug.name = "frustum_debug"

		local function create_frustum_points()
			local math3d_baselib = require "math3d.baselib"
			local mu = require "math.util"
			local camera = world:first_entity("main_camera")

			local view, proj = mu.view_proj_matrix(camera)
			local matVP = ms(proj, view, "*m")
			local corners = math3d_baselib.frustum_points(matVP)

			local green_color = 0xff00ff00
			for i=1, 8 do
				table.insert(corners, i*3+i, green_color)
			end

			table.insert(corners, 1, "fffd")

			return corners
		end

		local ib = {
			-- top
			1, 2, -- ltn, rtn
			1, 3, -- ltn, ltf							
			3, 4, -- ltf, rtf
			4, 2, -- rtf, rtn

			-- bottom
			1+4, 2+4, -- ltn, rtn
			1+4, 3+4, -- ltn, ltf							
			3+4, 4+4, -- ltf, rtf
			4+4, 2+4, -- rtf, rtn

			1, 5,
			2, 6,
			3, 7,
			4, 8,
		}

        frusutm_debug.mesh.assetinfo = computil.create_mesh_handle(vdecl, create_frustum_points(), ib)	
		cu.load_material(frusutm_debug.material,{ fs.path "line.material",})
	end
end