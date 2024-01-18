local ecs = ...
local world = ecs.world

local common = ecs.require "common"
local util      = ecs.require "util"
local PC        = util.proxy_creator()

local pbr_test_sys = common.test_system "pbr"

local imaterial = ecs.require "ant.asset|material"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local math3d    = require "math3d"

local function create_pbr_entity(pos, color, metallic, roughness)
    PC:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/sphere.glb|mesh.prefab",
        on_ready = function (e)
            local root<close> = world:entity(e.tag['*'][1], "scene:update")
            iom.set_position(root, pos)

            local sphere<close> = world:entity(e.tag['*'][2])
            imaterial.set_property(sphere, "u_basecolor_factor",    math3d.vector(color))
            imaterial.set_property(sphere, "u_pbr_factor",          math3d.vector(metallic, roughness, 0.0, 1.0))
        end
    }
end

local function pbr_spheres()
    local num_samples = 4
    local metallic_step = 1.0 / num_samples
    local roughness_step = 1.0 / num_samples
    local basecolor = {0.8, 0.2, 0.2, 1.0}
    local movestep = 2
    local x = 0.0

    for row=1, num_samples do
        local metallic = row * metallic_step
        local z = 0.0
        for col=1, num_samples do
            local roughness = col * roughness_step
            create_pbr_entity(math3d.vector(x, 0.0, z, 1.0), basecolor, metallic, roughness)

            z = z + movestep
        end
        x = x + movestep
    end
end

function pbr_test_sys:init()
    pbr_spheres()
end

function pbr_test_sys:exit()
    PC:clear()
end
