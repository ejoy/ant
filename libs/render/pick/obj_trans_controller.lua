local ecs = ...
local world = ecs.world

ecs.component "pos_transform"
ecs.conponent "scale_transform"
ecs.component "rotator_transform"

ecs.component "object_transform"


local obj_trans_sys = ecs.system "obj_transform_system"
obj_trans_sys.singleton "object_transform"
obj_trans_sys.singleton "math3d"

local function add_trans_entity()
    local entity = world:new_entity("position", "scale", "direction", "render")

    entity.render.visible = false
    return entity
end

function obj_trans_sys:init()
    local ot = self.object_transform
    ot.obj_entity = entity 
    ot.selected_mode = "pos_transform"
end

function obj_trans_sys:update()
    local pu_entity = world:first_entity("pickup")
    if pu_entity then
        local pu = pu_entity.pickup
        if pu.last_eid_hit ~= 0 then
            -- found hit transform controller
            local selected_entity = assert(world[pu.last_eid_hit])
            self.math_stack(ot.obj_entity.position.v, selected_entity.position.v, "=")
            self.math_stack(ot.obj_entity.direction.v, selected_entity.direction.v, "=")
        end         
    end   
end

-- controller system
local obj_controller_sys = ecs.system "obj_controller"
obj_controller_sys.singleton "message_component"
obj_controller_sys.singleton "object_transform"

obj_controller_sys.depend "obj_transform_system"

function obj_controller_sys:init()
    local message = {}
    function message:button(btn, p, x, y)

    end
    function message:motion(x, y)

    end

    local observers = self.message_component.msg_observers
    observers:add(message)
end

function obj_controller_sys:update()
    local ot = self.object_transform
    if ot.selected_mode ~= "" then
        local controller = assert(world:first_entity(ot.selected_mode))

    end
end
