local ecs = ...
local world = ecs.world
local w = world.w
local m = ecs.system "entity_state_system"
local ies = ecs.import.interface "ant.scene|ientity_state"
function m:entity_init()
    for e in w:select "INIT state:in render_object:in" do
        local s = e.state
        if type(s) == "string" then
            s = ies.filter_mask(s)
        end
        e.render_object.entity_state = s or 0
    end
end