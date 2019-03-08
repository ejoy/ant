local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local computil = renderpkg.components
local camerautil = renderpkg.camera

local fs = require "filesystem"

local simplescene = ecs.system "simple_scene"

simplescene.depend "camera_init"
simplescene.depend "constant_init_sys"
simplescene.dependby "message_system"
simplescene.dependby "final_filter"
simplescene.dependby "entity_rendering"

function simplescene:init()
	computil.create_grid_entity(world)

	local bunnyeid = world:create_entity {
		transform = {			
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		mesh = {
			ref_path = fs.path "//ant.resources/bunny.mesh",
		},
		material = {
			content = {
				{
					ref_path = fs.path "//ant.resources/bunny.material",
				}
			}
		},
		can_render = true,
		name = "demo_bunny",		
		main_viewtag = true,
	}

	camerautil.focus_selected_obj(world, bunnyeid)
end