local ecs = ...
local world = ecs.world

local init_sys   = ecs.system "init_system"
local iRmlUi     = world:interface "ant.rmlui|rmlui"
local irq        = world:interface "ant.render|irenderqueue"

local OpenDebugger  = false
local eventKeyboard = world:sub {"keyboard", "F8"}

function init_sys:post_init()
	local vr = irq.view_rect(world:singleton_entity_id "main_queue")
	iRmlUi.initialize(vr.w, vr.w)
	iRmlUi.preload_dir "/pkg/ant.test.rmlui/ui"
    local window = iRmlUi.open "start.rml"
    window.postMessage("hello")
    window.addEventListener("message", function(event)
        print(event.data)
    end)
end

function init_sys:ui_update()
    for _,_,press in eventKeyboard:unpack() do
        if press == 1 then
            OpenDebugger = not OpenDebugger
            iRmlUi.debugger(OpenDebugger)
        end
    end
end
