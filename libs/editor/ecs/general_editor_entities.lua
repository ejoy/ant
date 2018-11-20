local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.camera.camera_component"

-- entity
ecs.import "editor.ecs.editor_component"

local cu 	= require "render.components.util"
local bgfx  = require "bgfx"
local mu  	= require "math.util"

local general_editor_entites = ecs.system "general_editor_entites"

general_editor_entites.singleton "math_stack"
general_editor_entites.depend "camera_init"

function general_editor_entites:init()
    local ms = self.math_stack

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

        mu.identify_transform(ms, axis)

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
		
		cu.load_material(axis.material,{"line.material",})
    end

    do
		local gridid = world:new_entity("rotation", "position", "scale", 
		"can_render", "mesh", "material", "editor",
		"name")
        local grid = world[gridid]
        grid.name = "grid"
        mu.identify_transform(ms, grid)        

        local function create_grid_line_points(w, h, unit)
            local t = {"fffd"}
            local function add_point(x, z, clr)
                table.insert(t, x)
                table.insert(t, 0)
                table.insert(t, z)
                table.insert(t, clr)
            end

            local w_len = w * unit
            local hw_len = w_len * 0.5

            local h_len = h * unit
            local hh_len = h_len * 0.5

            local color = 0x88c0c0c0

            -- center lines
            add_point(-hh_len, 0, 0x8800ff)
            add_point(hh_len, 0, 0x880000ff)

            add_point(0, -hw_len, 0x88ff0000)
            add_point(0, hw_len, 0x88ff0000)

            -- column lines
            for i=0, w do
                local x = -hw_len + i * unit
                add_point(x, -hh_len, color)
                add_point(x, hh_len, color)                
            end

            -- row lines
            for i=0, h do
                local y = -hh_len + i * unit
                add_point(-hw_len, y, color)
                add_point(hw_len, y, color)
            end
            return t
        end

		grid.mesh.ref_path = ""
        grid.mesh.assetinfo = {
			handle = {
				groups = {
					{
						vb = {
							decls = {
								vdecl
							},
							handles = {
								bgfx.create_vertex_buffer(
									create_grid_line_points(64, 64, 1),
									vdecl)
							}
						}
					}
				}
			}
		}

		cu.load_material(grid.material,{"line.material",})
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

			local view, proj = mu.view_proj_matrix(ms, camera)
			local matVP = ms(view, proj, "*m")
			local corners = math3d_baselib.frustum_points(matVP)

			local green_color = 0xff00ff00
			for i=1, 8 do
				table.insert(corners, i*3+i, green_color)
			end

			table.insert(corners, 1, "fffd")

			return corners
		end

		frusutm_debug.mesh.ref_path = ""
        frusutm_debug.mesh.assetinfo = {
			handle = {
				groups = {
					{
						vdecl = vdecl,
						vb = {
							decls = {
								vdecl
							},
							handles = {
								bgfx.create_vertex_buffer(
								create_frustum_points(),
								vdecl),
							}
						},
						ib = {
							handle = bgfx.create_index_buffer {
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
							},	
						}
					}
				}
			}
		}
	
		cu.load_material(frusutm_debug.material,{"line.material",})
	end
end