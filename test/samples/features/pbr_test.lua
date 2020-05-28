local ecs = ...
local world = ecs.world
local fs = require "filesystem"

local assetmgr = import_package "ant.asset"

local pbr_test_sys = ecs.system "pbr_test_system"

local feature_path = fs.path "/pkg/ant.test.features"
local pbr_material = world.component:resource((feature_path / "assets/pbr_test.pbrm"):string())
local sphere_mesh = world.component:resource("/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/pSphere1_P1.meshbin")

local function create_pbr_entity(world, 
    name, transform, 
    color, metallic, roughness)

    local eid = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            "ant.general|name",
            "ant.objcontroller|select",
        },
        data = {
            name = name,
            transform = transform,
            material = pbr_material,
            mesh = sphere_mesh,
            can_render = true,
            can_select = true,
            scene_entity = true,
        }
    }

    local e = world[eid]

    local m = assetmgr.patch(e.material, {properties={uniforms={}}})
    e.material = m

    local u = m.properties.uniforms
    for k, v in pairs{
        u_basecolor_factor = color,
        u_metallic_roughness_factor  = {0.0, roughness, metallic, 0.0},
    } do
        local nv = assetmgr.patch(assert(u[k]), {})
        nv[1].v = v
        u[k] = nv
    end

    return eid
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
            create_pbr_entity(world, "sphere" .. row .. "x" .. col, 
            world.component:transform{
                srt = world.component:srt {s = {100, 100, 100, 0}, t = {x, 0.0, z, 1.0}}
            }, basecolor, metallic, roughness)

            z = z + movestep
        end
        x = x + movestep
    end
end

local entitydir = fs.path "/pkg/ant.test.features/assets/entities"
function pbr_test_sys:init()
    world:instance((entitydir / "DamagedHelmet.prefab"):string(), {})
    pbr_spheres()
end