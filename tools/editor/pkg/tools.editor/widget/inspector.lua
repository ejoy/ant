local ecs = ...
local world = ecs.world

local gizmo             = ecs.require "gizmo.gizmo"
local base_panel        = ecs.require "widget.base_view"()
local light_panel       = ecs.require "widget.light_view"()
local material_panel    = ecs.require "widget.material_view"()
local slot_panel        = ecs.require "widget.slot_view"()
local effect_panel      = ecs.require "widget.effect_view"()
local skybox_panel      = ecs.require "widget.skybox_view"()
local camera_panel      = ecs.require "widget.camera_view"()
local daynight_panel    = ecs.require "widget.daynight_view"()
local ImGui             = require "imgui"
local uiconfig          = require "widget.config"

local m = {}
local current_eid

local function update_eid()
    if current_eid == gizmo.target_eid then
        return
    end
    current_eid = gizmo.target_eid
    base_panel:reset_disable()
    camera_panel:set_eid(current_eid, base_panel)
    light_panel:set_eid(current_eid, base_panel)
    slot_panel:set_eid(current_eid)
    effect_panel:set_eid(current_eid)
    skybox_panel:set_eid(current_eid)
    material_panel:set_eid(current_eid)
    base_panel:set_eid(current_eid)
    daynight_panel:set_eid(current_eid)
end

local event_reset = world:sub {"ResetEditor"}

function m.get_title()
    return "Inspector"
end

function m.show()
    for _ in event_reset:unpack() do
        material_panel:clear()
    end
    update_eid()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x + viewport.WorkSize.x - uiconfig.PropertyWidgetWidth, viewport.WorkPos.y + uiconfig.ToolBarHeight, ImGui.Cond.FirstUseEver)
    ImGui.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize.y - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, ImGui.Cond.FirstUseEver)
    if ImGui.Begin("Inspector", nil, ImGui.WindowFlags "NoCollapse" ) then
        base_panel:show()
        camera_panel:show()
        light_panel:show()
        slot_panel:show()
        effect_panel:show()
        skybox_panel:show()
        material_panel:show()
        daynight_panel:show()
    end
    ImGui.End()
end

return m