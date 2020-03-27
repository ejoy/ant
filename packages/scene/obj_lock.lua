local ecs = ...
local world = ecs.world


ecs.component "lock_target"
	.type "string"
	.target "entityid"
    ["opt"].offset "vector"


local obj_lock_p = ecs.policy "obj_lock_policy"
obj_lock_p.require_component "lock_target"
obj_lock_p.require_component "transform"

obj_lock_p.require_system "lock_target_system"

local camera_lock_p = ecs.policy "camera_lock_policy"
camera_lock_p.require_component "lock_target"
camera_lock_p.require_component "camera"

camera_lock_p.require_system "lock_target_system"


local lock_target_sys = ecs.system "lock_target_system"

function lock_target_sys:lock_target()
    
end
