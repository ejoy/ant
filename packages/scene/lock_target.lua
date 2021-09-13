local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local lt_sys = ecs.system "lock_target_system"

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
            local pos = math3d.index(world[target]._rendercache.worldmat, 4)
            if lt.offset then
                pos = math3d.add(pos, lt.offset)
            end
            local s, r = math3d.srt(rc.worldmat)
            rc.worldmat = math3d.matrix{s=s, r=r, t=pos}
        elseif locktype == "rotate" then
            local worldmat = rc.worldmat
            local pos = math3d.index(worldmat, 4)
            local targetpos = math3d.index(world[target]._rendercache.worldmat, 4)
            local viewdir = math3d.normalize(math3d.sub(targetpos, pos))

            if lt.offset then
                pos = math3d.add(pos, lt.offset)
            end
            local s = math3d.srt(worldmat)
            rc.worldmat = math3d.matrix{s=s, r=math3d.torotation(viewdir), t=pos}
        elseif locktype == "ignore_scale" then
            if trans == nil then
                error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
            end

            local ps = math3d.tovalue(world[target]._rendercache.srt.s)
            local inv_scalemat = math3d.matrix{s={1.0/ps[1], 1.0/ps[2], 1.0/ps[3]}}
            rc.worldmat = math3d.mul(inv_scalemat, rc.worldmat)
        else
            error(("not support locktype:%s"):format(locktype))
        end
    end
end