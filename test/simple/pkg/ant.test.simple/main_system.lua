local ecs = ...
local world = ecs.world
local w = world.w

local icamera = ecs.require "ant.camera|camera"
local math3d = require "math3d"
local widget = ecs.require "widget"

local m = ecs.system "main_system"

local prefab

local imesh = ecs.require "ant.asset|mesh"
local ientity = ecs.require "ant.entity|entity"

function m:init_world()
    world:create_instance {
        prefab = "/pkg/ant.test.simple/resource/light.prefab"
    }

    world:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene 		= {
				s = {250, 1, 250},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible     = true,
			mesh_result	= imesh.init_mesh(ientity.plane_mesh(), true),
            owned_mesh_buffer = true,
		}
	}

    prefab = world:create_instance {
        prefab = "/pkg/ant.test.simple/resource/miner/miner.gltf|mesh.prefab",
        on_ready = function ()
            local main_queue = w:first "main_queue camera_ref:in"
            local main_camera <close> = world:entity(main_queue.camera_ref, "camera:in")
            local dir = math3d.vector(0, -1, 1)
            if not icamera.focus_prefab(main_camera, prefab.tag['*'], dir) then
                error "aabb not found"
            end
        end
    }
end

function m:data_changed()
    widget.AnimationView(prefab.tag)
end
