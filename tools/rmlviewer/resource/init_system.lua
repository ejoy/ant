local ecs = ...
local world = ecs.world

local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.require "ant.rmlui|rmlui_system"
local bgfx     = require "bgfx"

local OpenDebugger  = false
local eventKeyboard = world:sub {"keyboard", "F8"}

function init_sys:post_init()
    bgfx.maxfps(60)
	iRmlUi.preload_dir "/pkg/ant.test.rmlui/ui"
    local window = iRmlUi.open "construct.html"
    window.postMessage("hello")
    window.addEventListener("message", function(data)
        print(data)
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
