local ecs = ...

local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local font = import_package "ant.font"

local m = ecs.system "init_system"

font.import "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf"

function m:init()
    iRmlUi.open "/pkg/ant.test.rmlui/start.html"
    iRmlUi.onMessage("click", function (msg)
        print(msg)
    end)
end
