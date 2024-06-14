local ecs = ...
local world = ecs.world
local w = world.w
local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local icamera_ctrl = ecs.require "camera_ctrl"

local font = import_package "ant.font"
font.import "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf"

local m = ecs.system "main_system"

function m:init_world()
    iRmlUi.open("canvas", "/asset/start.html")
    iRmlUi.onMessage("click", function (msg)
        print(msg)
    end)

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
			mesh        = "plane.primitive",
			on_ready = function()
			end
		}
	}
	
	icamera_ctrl.distance = 10
end

