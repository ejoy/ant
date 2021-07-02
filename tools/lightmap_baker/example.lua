local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local example_sys = ecs.system "lightmap_example"
local ilm = world:interface "ant.bake|ilightmap"
local imaterial = world:interface "ant.asset|imaterial"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler

local example_eid
function example_sys:init()
    example_eid = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.bake|lightmap",
            "ant.render|render",
        },
        data = {
            scene_entity = true,
            lightmap = {
                size = 64
            },
            transform = {},
            
            material = "/pkg/ant.tool.lightmap_baker/assets/example/materials/example.material",
            mesh = "/pkg/ant.tool.lightmap_baker/assets/example/meshes/gazebo.glb|meshes/Node-Mesh_P1.meshbin",
            name = "lightmap_example",
            state = 1,
        }
        
    }

    local e = world[example_eid]
    local rc = e._rendercache
    rc.simple_mesh = "d:/work/ant/tools/lightmap_baker/assets/example/meshes/gazebo.obj"
    rc.eid = example_eid
    rc.worldmat = e._rendercache.srt

    local pf = {
        filter_order = {"opaticy"},
        result = {
            opaticy = {
                items = {rc},
                visible_set = {rc},
            }
        }
    }
    ilm.bake_entity(example_eid, pf, true)

    local lm = e._lightmap.data
    local lm1 = e.lightmap

    local s = lm1.size * lm1.size * 4
    local mem = bgfx.memory_buffer(lm:data(), s, lm)

    local flags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local lm_handle = bgfx.create_texture2d(lm1.size, lm1.size, false, 1, "RGBA8", flags, mem)
    imaterial.set_property(example_eid, "s_lightmap", {
        stage = 0,
        texture = {
            handle = lm_handle
        }
    })

    rc.worldmat = nil
    rc.eid = nil
end

function example_sys:data_changed()

end