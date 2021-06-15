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
                width = 64,
                height = 64,
                channels = 4,
            },
            transform = {},
            
            material = "/pkg/ant.tool.lightmap_baker/assets/example/materials/example.material",
            mesh = "/pkg/ant.tool.lightmap_baker/assets/example/meshes/gazebo.glb|meshes/Node-Mesh_P1.meshbin",
            name = "lightmap_example",
        }
        
    }

    local e = world[example_eid]
    local rc = e._rendercache
    rc.simple_mesh = "d:/work/ant/tools/lightmap_baker/assets/example/meshes/gazebo.obj"
    rc.eid = example_eid
    rc.worldmat = e._rendercache.srt
    rc.set_transform = function (rc)
        bgfx.set_transform(rc.worldmat)
    end

    local pf = {
        filter_order = {"opaticy"},
        result = {
            opaticy = {
                items = {rc},
                visible_set = {rc},
            }
        }
    }
    ilm.init_bake_context()
    ilm.bake_entity(example_eid, pf, true)

    local lm = e._lightmap.data
    local lm1 = e.lightmap

    lm:save "D:\\tmp\\abc.tga"

    local size = lm1.width * lm1.height * lm1.channels
    local mem = bgfx.memory_buffer(lm:data(), size, lm)

    local flags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local lm_handle = bgfx.create_texture2d(lm1.width, lm1.height, false, 1, "RGBA8", flags, mem)
    imaterial.set_property(example_eid, "s_lightmap", {
        stage = 0,
        texture = {
            handle = lm_handle
        }
    })

    rc.worldmat = nil
    rc.eid = nil
    rc.set_transform = nil
end

function example_sys:data_changed()

end