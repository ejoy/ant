local ecs = ...
local world = ecs.world

ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"

ecs.import "scene.filter.filter_system"

ecs.import "inputmgr.message_system"

local computil = require "render.components.util"
local bgfx = require "bgfx"
local mu = require "math.util"
local ms = require "math.stack"

local simplescene = ecs.system "simple_scene"

simplescene.depend "camera_init"

local function create_grid_entity()
	local vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true }
	}

	local gridid = world:new_entity(
		"rotation", "position", "scale", 
		"can_render", "mesh", "material", 
		--"editor",
		"name")
	local grid = world[gridid]
	grid.name = "grid"
	mu.identify_transform(grid)        

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

	computil.load_material(grid.material,{"line.material",})
end

function simplescene:init()
	local bunnyeid = world:new_entity(
		"position", "scale", "rotation",
		"mesh", "material", "can_render",
		"name"
	)

	local bunny = world[bunnyeid]
	bunny.name = "demo_bunny"

	ms(bunny.position, 	{0, 0, 0, 1}, 	"=")
	ms(bunny.scale, 	{1, 1, 1}, 		"=")
	ms(bunny.rotation, 	{0, 0, 0}, 		"=")

	computil.load_mesh(bunny.mesh, "engine/assets/depiction/bunny.mesh")
	computil.load_material(bunny.material, {"depiction/bunny.material"})

	world:change_component(bunnyeid, "focus_selected_obj")
	world:notify()

	create_grid_entity()

	local camera = world:first_entity("main_camera")
	ms(camera.rotation, {25, 45, 0}, "=")
end