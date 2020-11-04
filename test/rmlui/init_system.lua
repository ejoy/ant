local ecs = ...
local world = ecs.world

local init_sys   = ecs.system "init_system"
local iRmlUi     = world:interface "ant.rmlui|rmlui"
local irq        = world:interface "ant.render|irenderqueue"

local OpenDebugger  = false
local eventKeyboard = world:sub {"keyboard", "F8"}

function init_sys:post_init()
    iRmlUi.preload_dir "/pkg/ant.test.rmlui/ui"
    local vr = irq.view_rect(world:singleton_entity_id "main_queue")
    iRmlUi.message("CreateContext", "main", vr.w, vr.h)
    iRmlUi.message("LoadDocument", "main", "fonttest.rml")
    iRmlUi.message("Debugger", OpenDebugger)
end

function init_sys:ui_update()
    for _,_,press in eventKeyboard:unpack() do
        if press == 1 then
            OpenDebugger = not OpenDebugger
            iRmlUi.message("Debugger", OpenDebugger)
        end
    end
end
