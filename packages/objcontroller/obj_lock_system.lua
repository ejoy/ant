local ecs = ...
local world = ecs.world

local math3d = require "math3d"

ecs.component "lock_target"
	.type	"string"
	.target	"entityid"
    ["opt"].offset	"vector"

local lock_traget_trans = ecs.transform "lock_target_transform"
lock_traget_trans.output "lock_target"

function lock_traget_trans.process(e)
    if not (e.camera or e.transform) then
        error(string.format("'lock_target' component require 'camera'/'transform' component"))
    end

    if e.hierarchy then
        error(string.format("'hierarchy' entity should not as lock host"))
    end
end

local obj_lock_p = ecs.policy "obj_lock"
obj_lock_p.require_component "lock_target"
obj_lock_p.require_component "transform"
obj_lock_p.require_transform "lock_target_transform"

obj_lock_p.require_system "lock_target_system"

local camera_lock_p = ecs.policy "camera_lock"
camera_lock_p.require_component "lock_target"
camera_lock_p.require_component "camera"
camera_lock_p.require_transform "lock_target_transform"

camera_lock_p.require_system "lock_target_system"


local lock_target_sys = ecs.system "lock_target_system"

local iom = world:interface "ant.objcontroller|obj_motion"
local icm = world:interface "ant.objcontroller|camera_motion"

function lock_target_sys:lock_target()
	for _, eid in world:each "lock_target" do
		local e = world[eid]
        local lt = e.lock_target

        local im = e.camera and icm or iom

        local locktype = lt.type
        if locktype == "move" then
            local te = world[lt.target]
            local target_trans = te.transform
            local pos = math3d.index(target_trans.world, 4)
            if lt.offset then
                pos = math3d.add(pos, lt.offset)
            end
            im.set_position(e, pos)
            local trans = e.transform
            trans.world.m = trans.srt
        elseif locktype == "rotate" then
            local te = world[lt.target]
            local transform = te.transform

            local pos = im.get_position(e)
            local targetpos = math3d.index(transform.world, 4)
            im.set_direction(e, math3d.normalize(math3d.sub(targetpos, pos)))
            if lt.offset then
                im.set_position(e, math3d.add(pos, lt.offset))
            end
            local trans = e.transform
            trans.world.m = trans.srt
        elseif locktype == "ignore_scale" then
            local trans = e.transform
            if trans == nil then
                error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
            end

            local te = world[lt.target]
            local target_trans = te.transform

            local _, r, t = math3d.srt(target_trans)
            local m = math3d.matrix{s=1, r=r, t=t}
            trans.world.m = math3d.mul(m, trans.srt)
        else
            error(string.format("not support locktype:%s", locktype))
        end
	end
end
