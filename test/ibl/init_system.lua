local ecs = ...
local world = ecs.world

local ientity = world:interface "ant.render|entity"
local imaterial = world:interface "ant.asset|imaterial"

local is = ecs.system "init_system"

local iblmb = world:sub {"ibl_updated"}
function is:init()
    --world:instance "/pkg/ant.test.ibl/assets/skybox.prefab"
    --world:instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
end

function is:data_changed()
    -- for _, eid in iblmb:unpack() do
    --     local ibl = world[eid]._ibl
    --     imaterial.set_property(eid, "s_skybox", {stage=0, texture={handle=ibl.irradiance.handle}})
    -- end

    local m = ientity.create_mesh{"p3", {
        -1, 0, 1,
         1, 0, 1,
         1, 0,-1,
        -1, 0,-1,
    }}

    world:luaecs_create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            name = "test_luaecs",
            render_object = {},
            transform = {
                t = {0, 1, 0},
            },
            material = "/pkg/ant.resources/materials/singlecolor.material",
            state = 7,
            mesh = m,
        }
    }
end