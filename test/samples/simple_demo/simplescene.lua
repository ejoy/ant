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
local camerautil = require "render.camera.util"

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

	local function create_grid(w, h, unit)
		local vb = {"fffd"}
		local ib = {}
		local function add_point(x, z, clr)
			table.insert(vb, x)
			table.insert(vb, 0)
			table.insert(vb, z)
			table.insert(vb, clr)
		end

		local w_len = w * unit
		local hw_len = w_len * 0.5

		local h_len = h * unit
		local hh_len = h_len * 0.5

		local color = 0x88c0c0c0

		local function add_line(x0, z0, x1, z1, color)
			add_point(x0, z0, color)
			add_point(x1, z1, color)
			-- call 2 times
			table.insert(ib, #ib)
			table.insert(ib, #ib)
		end

		-- center lines
		add_line(-hh_len, 0, hh_len, 0, 0x880000ff)		
		add_line(0, -hw_len, 0, hw_len, 0x88ff0000)		

		-- column lines
		for i=0, w do
			local x = -hw_len + i * unit
			add_line(x, -hh_len, x, hh_len, color)			              
		end

		-- row lines
		for i=0, h do
			local y = -hh_len + i * unit
			add_line(-hw_len, y, hw_len, y, color)			
		end
		return vb, ib
	end

	local vb, ib = create_grid(64, 64, 1)

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
								vb,
								vdecl)
						}
					},
					ib = {
						handle = bgfx.create_index_buffer(ib)
					}

				}
			}
		}
	}

	computil.load_material(grid.material,{"line.material",})
end

function simplescene:init()
	create_grid_entity()

	local bunnyeid = world:new_entity(
		"position", "scale", "rotation",
		"mesh", "material", "can_render",
		"name"
	)

	local bunny = world[bunnyeid]
	bunny.name = "demo_bunny"

	mu.identify_transform(bunny)

	computil.load_mesh(bunny.mesh, "engine/assets/depiction/bunny.mesh")
	computil.load_material(bunny.material, {"depiction/bunny.material"})

	camerautil.focus_selected_obj(world, bunnyeid)
end