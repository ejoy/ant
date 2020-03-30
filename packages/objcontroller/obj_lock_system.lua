local ecs = ...
local world = ecs.world

local math3d = require "math3d"

ecs.component "lock_target"
	.type	"string"
	.target	"entityid"
	["opt"].offset	"vector"

local obj_lock_p = ecs.policy "obj_lock_policy"
obj_lock_p.require_component "lock_target"
obj_lock_p.require_component "transform"

obj_lock_p.require_system "lock_target_system"

local camera_lock_p = ecs.policy "camera_lock_policy"
camera_lock_p.require_component "lock_target"
camera_lock_p.require_component "camera"

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
            if lt.offset then
                local te = world[lt.target]
                local transform = te.transform
                local pos = math3d.index(transform.srt, 3)
                im.set_position(math3d.add(pos, lt.offset))
            end
        elseif locktype == "rotate" then
            local te = world[lt.target]
            local transform = te.transform

            local eyepos = im.get_position(e)
            local targetpos = math3d.index(transform.srt, 3)
            im.set_direction(e, math3d.normalize(math3d.sub(targetpos, eyepos)))
            if lt.offset then
                im.set_position(math3d.add(targetpos, lt.offset))
            end
        elseif locktype == "ignore_scale" then
            local trans = e.transform
            if trans == nil then
                error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
            end

            local te = world[lt.target]
            local target_trans = te.transform

            local _, r, t = math3d.srt(target_trans)
            local m = math3d.matrix{s=1, r=r, t=t}
            trans.srt.m = math3d.mul(m, trans.srt)

            if e.hierarchy then
                world:pub {"component_changed", "transform", "srt"}
            end
        else
            error(string.format("not support locktype:%s", locktype))
        end
	end
end
