local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"

local m = {}

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    for _ in uiutils.imgui_windows("ParticleEmitter", imgui.flags.Window { "NoCollapse", "NoClosed" }) do

    end
end

return function(w)

    return m
end