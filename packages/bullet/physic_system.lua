local ecs = ...
local world = ecs.world

local physicworld = world.args.Physic.world

local update_physic_obj_sys = ecs.system "update_physic_object_transform"
function update_physic_obj_sys:update()
    
    --btworld:update()
end

local physic_sys = ecs.system "physic_system"
physic_sys.depend "update_physic_object_transform"

function physic_sys:update()

end
