local ecs = ...
local world = ecs.world
local w = world.w

local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local icamera       = ecs.import.interface "ant.camera|icamera"
local ilight        = ecs.import.interface "ant.render|ilight"
local camera_mgr    = ecs.require "camera_manager"
local gizmo         = ecs.require "gizmo.gizmo"
local light_gizmo   = ecs.require "gizmo.light"
local anim_view     = ecs.require "widget.animation_view"

local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy_edit"
local uiproperty = require "widget.uiproperty"

local m = {}
local light_panel
local camera_panel
local material_panel
local base_panel
local slot_panel
local collider_panel
local effect_panel
local current_panel
local skybox_panel
local current_eid

local camera_ui_data = {
    target          = {-1},
    dist            = {5, speed = 0.1},
    fov_axis        = {text = "vert"},
    field_of_view   = {30, speed = 0.5},
    near_plane      = {0.1},
    far_plane       = {300},
    current_frame   = 1,
    duration        = {}
}

local function update_ui_data(eid)
    if not current_panel or not eid then return end
    -- update transform
    -- if current_panel.super then
    --     -- BaseView
    --     current_panel.super.update(current_panel)
    -- else
        current_panel:update()
    --end
end

function m.update_template_tranform(e)
    if not e then return end
    
    local template = hierarchy:get_template(e)
    
    if not template or not template.template then return end

    local s, r, t = iom.get_scale(e), iom.get_rotation(e), iom.get_position(e)
    local srt = {
        r = {math3d.index(r, 1, 2, 3, 4)},
        s = {math3d.index(s, 1, 2, 3)},
        t = {math3d.index(t, 1, 2, 3)},
    }
    template.template.data.scene.srt = srt
    w:sync("collider?in", e)
    if e.collider then
        anim_view.record_collision(e)
    end
    w:sync("follow_joint?in follow_offset?in", e)
    if e.follow_joint then
        template.template.data.follow_offset = srt
        e.follow_offset = srt
        w:sync("follow_offset:out", e)
    end
end

function m.update_ui(ut)
    if not gizmo.target_eid then return end
    local e = gizmo.target_eid
    if ut then
        m.update_template_tranform(e)
    end
    update_ui_data(e)
end

local function get_camera_panel()
    if not camera_panel then
        camera_panel = ecs.require "widget.camera_view"()
    end
    return camera_panel
end

local function get_light_panel()
    if not light_panel then
        light_panel = ecs.require "widget.light_view"()
    end
    return light_panel
end

local function get_material_panel()
    if not material_panel then
        material_panel = ecs.require "widget.material_view"()
    end
    return material_panel
end

local function get_base_panel()
    if not base_panel then
        base_panel = ecs.require "widget.base_view"()
    end
    return base_panel
end

local function get_slot_panel()
    if not slot_panel then
        slot_panel = ecs.require "widget.slot_view"()
    end
    return slot_panel
end

local function get_collider_panel()
    if not collider_panel then
        collider_panel = ecs.require "widget.collider_view"()
    end
    return collider_panel
end
local function get_effect_panel()
    if not effect_panel then
        effect_panel = ecs.require "widget.effect_view"()
    end
    return effect_panel
end

local function get_skybox_panel()
    if not skybox_panel then
        skybox_panel = ecs.require "widget.skybox_view"()
    end
    return skybox_panel
end

local function update_current()
    if current_eid == gizmo.target_eid then return end
    current_eid = gizmo.target_eid
    if current_eid then
        local e = current_eid
        current_panel = nil
        w:sync("collider?in", e)
        if e.collider then
            current_panel = get_collider_panel()
        end
        if not current_panel then
            w:sync("camera?in", e)
            if e.camera then
                current_panel = get_camera_panel()
            end
        end
        if not current_panel then
            w:sync("effekseer?in", e)
            if e.effekseer then
                current_panel = get_effect_panel()
            end
        end
        if not current_panel then
            w:sync("light?in", e)
            if e.light then
                current_panel = get_light_panel()
            end
        end
        if not current_panel then
            w:sync("slot?in", e)
            if e.slot then
                current_panel = get_slot_panel()
            end
        end
        if not current_panel then
            w:sync("skybox?in", e)
            if e.skybox then
                current_panel = get_skybox_panel()
            end
        end
        if not current_panel then
            w:sync("material?in", e)
            if e.material then
                current_panel = get_material_panel()
            end
        end
        if not current_panel then
            current_panel = get_base_panel()
        end
        if current_panel.set_model then
            current_panel:set_model(current_eid)
        end
    else
        current_panel = nil
    end
end

function m.show()
    update_current()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    for _ in uiutils.imgui_windows("Inspector", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        
        if current_panel then
            current_panel:show()
        end
    end
end

return m