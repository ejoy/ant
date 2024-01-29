local ecs   = ...
local world = ecs.world
local w     = world.w

local common    = ecs.require "common"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local util      = ecs.require "util"
local PC        = util.proxy_creator()
local imesh     = ecs.require "ant.asset|mesh"
local ientity 	= ecs.require "ant.render|components.entity"
local imaterial = ecs.require "ant.asset|material"

local math3d    = require "math3d"

local plt_sys = common.test_system "point_light"

function plt_sys.init_world()
    local pl_pos = {
        {  1, 0, 1},
        { -1, 0,-1},
        
        {  1, 2, 1},
        { -1, 2,-1},

        {  3, 0, 3},
        { -3, 0, 3},
        {  3, 0,-3},
        {  3, 2,-3},
    }

    for _, p in ipairs(pl_pos) do
        PC:create_instance{
            prefab = "/pkg/ant.test.features/assets/entities/sphere_with_point_light.prefab",
            on_ready = function(pl)
                local root<close> = world:entity(pl.tag['*'][1], "scene:update")
                iom.set_position(root, p)

                local sphere<close> = world:entity(pl.tag['*'][4])
                imaterial.set_property(sphere, "u_basecolor_factor", math3d.vector(1.0, 0.0, 0.0, 1.0))
            end
        }
    end

    PC:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene 		= {
				s = {25, 1, 25},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state= "main_view",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
		}
	}

    PC:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb|mesh.prefab",
        on_ready = function (ce)
            local root<close> = world:entity(ce.tag['*'][1], "scene:update")
            iom.set_position(root, {0, 0, 0, 1})
        end
    }
end

function plt_sys:exit()
    PC:clear()
end