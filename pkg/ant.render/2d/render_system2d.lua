local ecs = ...
local world = ecs.world
local w = world.w

local render_sys2d = ecs.system "render_system2d"

function render_sys2d:component_init()
    for e in w:select "INIT viewrect:in simplemesh:out" do
        
    end
end


function render_sys2d:entity_init()
    for e in w:select "INIT viewrect:in render_object:update simplemesh:out" do
        
    end
end