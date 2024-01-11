local ecs = ...

local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
local font = import_package "ant.font"
local platform = require "bee.platform"

local m = ecs.system "init_system"

if platform.os == "windows" then
    font.import "黑体"
elseif platform.os == "macos" then
    font.import "苹方-简"
elseif platform.os == "ios" then
    font.import "Heiti SC"
end


function m:init()
    iRmlUi.open "/pkg/ant.test.rmlui/start.html"
    iRmlUi.onMessage("click", function (msg)
        print(msg)
    end)
end
