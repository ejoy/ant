local ecs = ...
local world = ecs.world

local icompute = world:interface "ant.render|icompute"

local iibl = ecs.interface "iibl"

local function fitler_irradiance_map(cbhandle)
    local eid = icompute.create_compute_entity("irradiance_builder", "", {1, 1, 1})
    local e = world[eid]

end

function iibl.filter_all(cubemap)
    local cbhandle = cubemap.handle
    local irr_eid = fitler_irradiance_map(cbhandle)
    local mq = world:singleton_entity "main_queue"
    icompute.dispatch(mq.render_target.viewid, irr_eid)
end