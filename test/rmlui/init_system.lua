local ecs = ...
local world = ecs.world

local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|rmlui"

local OpenDebugger  = false
local eventKeyboard = world:sub {"keyboard", "F8"}

function init_sys:post_init()
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
