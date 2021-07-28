local ecs = ...
local world = ecs.world
local w = world.w
local m = ecs.system "entity_state_system"
function m:entity_init()
    for v in w:select "INIT state:in render_object:in" do
        v.render_object.entity_state = v.state or 0
    end
end