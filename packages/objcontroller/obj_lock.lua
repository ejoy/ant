local ecs = ...
local world = ecs.world

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

local camera_lock_p = ecs.policy "camera_lock"
camera_lock_p.require_component "lock_target"
camera_lock_p.require_component "camera"
camera_lock_p.require_transform "lock_target_transform"
