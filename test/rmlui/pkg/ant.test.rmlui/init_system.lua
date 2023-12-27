local ecs = ...

local init_sys = ecs.system "init_system"
local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local font = import_package "ant.font"

font.import "/pkg/ant.resources.binary/ui/test/assets/font/simsun.ttc"

function init_sys:init()
    iRmlUi.open "/pkg/ant.test.rmlui/start.rml"
    iRmlUi.onMessage("click", function (msg)
        print(msg)
    end)
end
