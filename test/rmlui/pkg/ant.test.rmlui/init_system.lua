local ecs = ...

local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local font = import_package "ant.font"

local m = ecs.system "init_system"

font.import "宋体"

function m:init()
    iRmlUi.open "/pkg/ant.test.rmlui/start.html"
    iRmlUi.onMessage("click", function (msg)
        print(msg)
    end)
end
