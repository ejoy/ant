local ecs = ...
local world = ecs.world

local serializeutil = import_package "ant.serialize"

local pbrtest = ecs.system "pbr_test"

local function create_pbr_entity(world, name, transform, color, metallic, roughness)

	local material = ([[
---
/pkg/ant.test.features/assets/pbr_test.pbrm
---
op: replace
path: /basecolor/factor
value: {%f, %f, %f, %f}
---
op: replace
path: /metallic_roughness
value:
    roughness_factor: %f
    metallic_factor: %f
---
op: replace
path: /emissive/factor
value: {0, 0, 0, 0}
]]):format(
    color[1],color[2],color[3],color[4],
    roughness, metallic
)
    return world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            "ant.render|name",
            "ant.serialize|serialize",
            "ant.objcontroller|select",
        },
        data = {
            name = name,
            transform = transform,
            material = material,
            rendermesh = {},
            mesh = "/pkg/ant.test.features/assets/sphere.mesh",
            can_render = true,
            can_select = true,
            serialize = serializeutil.create(),
        }

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
            create_pbr_entity(world, "sphere", {srt = {t = {x, 0.0, z, 1.0}}}, basecolor, metallic, roughness)
            z = z + movestep
        end
        x = x + movestep
    end
end

function pbrtest:init()
    world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            "ant.render|shadow_cast",
            "ant.render|name",
        },
        data = {
            transform = {srt={t={3, 2, 0, 1}}},
            rendermesh = {},
            mesh = "/pkg/ant.test.features/assets/DamagedHelmet.mesh",
            material = "/pkg/ant.test.features/assets/DamagedHelmet.pbrm",
            can_render = true,
            can_cast = true,
            name = "Damaged Helmet"
        }

    }

    pbr_spheres()
end