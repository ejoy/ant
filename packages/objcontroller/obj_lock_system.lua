local ecs = ...
local world = ecs.world

local math3d = require "math3d"

ecs.component "lock_target"
	.type	"string"
	.target	"entityid"
	.offset	"vector"

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
            local targetentity = world[lt.target]
            local transform = targetentity.transform
            im.set_position(math3d.add(transform.srt.t, lt.offset))
        elseif locktype == "rotate" then
            local targetentity = world[lt.target]
            local transform = targetentity.transform

            local eyepos = im.get_position(e)
            local targetpos = transform.srt.t
            im.set_direction(e, math3d.normalize(math3d.sub(targetpos, eyepos)))
        else
            error(string.format("not support locktype:%s", locktype))
        end
	end
end
