local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()

local irl       = ecs.require "ant.render|render_layer.render_layer"
local imesh     = ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.render|material"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local math3d    = require "math3d"

local rlt_sys = common.test_system "render_layer"

function rlt_sys.init_world()
    irl.add_layers(irl.layeridx "background", "mineral", "translucent_plane", "translucent_plane1")
    PC:add_instance(util.create_instance("/pkg/ant.resources.binary/meshes/Duck.glb/mesh.prefab", function (e)
        local ee <close> = world:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, -2, 0))
        iom.set_scale(ee, 3)
        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = world:entity(eid, "render_layer?update render_object?update")
            if ee.render_layer and ee.render_object then
                irl.set_layer(ee, "mineral")
            end
        end
    end))

    PC:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "plane.primitive",
            scene = {t = {-10, 0, 0}, s = 10},
            material = "/pkg/ant.test.features/assets/render_layer_test.material",
            render_layer = "translucent_plane",
            visible     = true,
        }
    }

    PC:add_instance(util.create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb/mesh.prefab", function (e)
        local ee <close> = world:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, 0, -1))

        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = world:entity(eid, "render_layer?update render_object?update")
            if ee.render_layer and ee.render_object then
                irl.set_layer(ee, "translucent_plane1")
            end
        end
    end))
end

function rlt_sys:exit()
    PC:clear()
end