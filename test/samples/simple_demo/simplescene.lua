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
		position = {0, 0, 0, 1}, 
		scale = {1, 1, 1, 0}, 
		rotation = {0, 0 , 0, 0},
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "bunny.mesh"},
		},
		material = {
			content = {
				{
					ref_path = {package="ant.resources", filename=fs.path "bunny.material"},
				}
			}
		},
		can_render = true,
		name = "demo_bunny",		
		main_viewtag = true,
	}

	camerautil.focus_selected_obj(world, bunnyeid)
end