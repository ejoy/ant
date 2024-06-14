local ecs = ...
local world = ecs.world
local w = world.w
local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local icamera_ctrl = ecs.require "camera_ctrl"
local imaterial = ecs.require "ant.render|material"
local assetmgr = import_package "ant.asset"

local font = import_package "ant.font"
font.import "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf"

local m = ecs.system "main_system"

function m:init_world()
    iRmlUi.open("canvas", "/asset/start.html")
    world:create_instance {
        prefab = "/asset/light.prefab"
    }
	world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {
				s = {10, 10, 10},
            },
			material 	= "/asset/canvas.material",
			visible     = true,
			-- rect (0,0,0.8,0.8) of canvas
			mesh        = "plane(0,0,0.8,0.8).primitive",
		}
	}
	
	icamera_ctrl.distance = 20
end

