local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local ientity = ecs.import.interface "ant.render|ientity"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local is = ecs.system "init_system"

local iblmb = world:sub {"ibl_updated"}
function is:init()
    ecs.create_instance "/pkg/ant.test.ibl/assets/skybox.prefab"
    ecs.create_instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
end

function is:data_changed()
    for _, eid in iblmb:unpack() do
        local ibl = world[eid]._ibl
        imaterial.set_property(eid, "s_skybox", {stage=0, texture={handle=ibl.irradiance.handle}})
    end
end