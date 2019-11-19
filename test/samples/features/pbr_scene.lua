local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local fs = require "filesystem"

local pbr_scene = {}

local feature_path = fs.path "/pkg/ant.test.features/assets/pbr_test.pbrm"
local pbr_materialpath = feature_path / "assets/pbr_test.pbrm"
local sphere_meshpath = feature_path / "assets/sphere.mesh"

local function create_pbr_entity(world, 
    name, transform, meshpath,
    color, metallic, roughness)

    return world:create_entity {
        name = name,
        transform = transform,
        material = computil.assign_material(
            pbr_materialpath,
            {
                uniforms = {
                    u_basecolor_factor = {
                        type="color", name = "base color",
                        value = color,
                    },
                    u_metallic_roughness_factor = {
                        type="v4", name = "metallic roughness",
                        value = {0.0, metallic, roughness, 0.0},
                    },
                    u_emissive_factor = {
                        type="color", name = "emissive",
                        value = {0.0, 0.0 ,0.0 ,0.0},
                    }
                }
            }
        ),
        rendermesh = {},
        mesh = {ref_path = meshpath,},
        can_render = true,
        can_select = true,
    }
end

function pbr_scene.create_scene(world)

    local num_samples = 10
    local metallic_step = 1.0 / num_samples
    local roughness_step = 1.0 / num_samples

    local basecolor = {0.8, 0.2, 0.2, 1.0}

    local x, y = 0.0, 0.0
    for row=1, num_samples do
        local metallic = row * metallic_step
        for col=1, num_samples do
            local roughness = col * roughness_step
            create_pbr_entity( world, "sphere",
            mu.translate_mat {},
            sphere_meshpath,
            basecolor,
            metallic, roughness)

            y = y + 1.0
        end

        x = x + 1.0
    end
end 

return pbr_scene 
