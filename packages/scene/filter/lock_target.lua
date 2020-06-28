local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local lt_sys = ecs.system "lock_target_system"

local itransform = world:interface "ant.scene|itransform"
local iom = world:interface "ant.objcontroller|obj_motion"

function lt_sys:refine_entity_transform()
    for _, eid in world:each "lock_target" do
        local e = world[eid]
        local trans = e.transform
        if trans == nil then
            error("lock target need, but transform not provide")
        end
    
        local lt = e.lock_target
        local rc = e._rendercache
    
        local locktype = lt.type
        local target = e.parent
    
        if locktype == "move" then
            local worldmat = itransform.worldmat(eid)
            local pos = math3d.index(worldmat, 4)
            if lt.offset then
                pos = math3d.add(pos, lt.offset)
            end
            iom.set_position(eid, pos)
            rc.worldmat = math3d.matrix(trans)
        elseif locktype == "rotate" then
            local worldmat = itransform.worldmat(eid)
    
            local pos = iom.get_position(eid)
            local targetpos = math3d.index(worldmat, 4)
            iom.set_direction(eid, math3d.normalize(math3d.sub(targetpos, pos)))
            if lt.offset then
                iom.set_position(eid, math3d.add(pos, lt.offset))
            end
            rc.worldmat = math3d.matrix(trans)
        elseif locktype == "ignore_scale" then
            if trans == nil then
                error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
            end
    
            local te = world[target]
            local target_trans = te.transform
    
            local _, r, t = math3d.srt(target_trans)
            local m = math3d.matrix{s=1, r=r, t=t}
            rc.worldmat = math3d.mul(m, trans)
        else
            error(("not support locktype:%s"):format(locktype))
        end
    end
end