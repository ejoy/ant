local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"

local ui_rt_group<const> = 110000

function ui_rt_sys:entity_init()
    local g = ecs.group(ui_rt_group)
    g:enable "ui_rt_obj"   
    for e in w:select "INIT ui_rt_obj render_object" do
        w:extend(e, "ui_rt_queue_visible?out")
        e.ui_rt_queue_visible = true
    end
end


