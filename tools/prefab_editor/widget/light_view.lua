local ecs = ...
local world = ecs.world
local w = world.w
local ilight    = ecs.import.interface "ant.render|light"
local light_gizmo = ecs.require "gizmo.light"
local gizmo = ecs.require "gizmo.gizmo"
ecs.require "widget.base_view"

local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty= require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"

local imgui     = require "imgui"

local BaseView  = require "widget.view_class".BaseView
local LightView = require "widget.view_class".LightView

function LightView:_init()
    BaseView._init(self)
    self.subproperty = {
        color        = uiproperty.Color({label = "Color", dim = 4}, {
            getter = function() return self:on_get_color() end,
            setter = function(...) self:on_set_color(...) end,
        }),
        intensity    = uiproperty.Float({label = "Intensity", min = 0, max = 100}, {
            getter = function() return self:on_get_intensity() end,
            setter = function(value) self:on_set_intensity(value) end,
        }),
        range        = uiproperty.Float({label = "Range", min = 0, max = 500},{
            getter = function() return self:on_get_range() end,
            setter = function(value) self:on_set_range(value) end,
        }),
        inner_radian = uiproperty.Float({label = "InnerRadian", min = 0, max = 180},{
            getter = function() return self:on_get_inner_radian() end,
            setter = function(value) self:on_set_inner_radian(value) end,
        }),
        outter_radian= uiproperty.Float({label = "OutterRadian", min = 0, max = 180}, {
            getter = function() return self:on_get_outter_radian() end,
            setter = function(value) self:on_set_outter_radian(value) end,
        }),
    }

    self.light_property= uiproperty.Group({label = "Light"}, {})
end

function LightView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end

    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity
    if not eid.light then
        w:sync("light:in", eid)
    end
    if eid.light.light_type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if eid.light.light_type == "spot" then
            subproperty[#subproperty + 1] = self.subproperty.inner_radian
            subproperty[#subproperty + 1] = self.subproperty.outter_radian
        end
    end
    self.light_property:set_subproperty(subproperty)
    self:update()
    return true
end

function LightView:on_set_color(...)
    local template = hierarchy:get_template(self.eid)
    template.template.data.color = ...
    ilight.set_color(self.eid, ...)
end

function LightView:on_get_color()
    return ilight.color(self.eid)
end

function LightView:on_set_intensity(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.intensity = value
    ilight.set_intensity(self.eid, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_intensity()
    return ilight.intensity(self.eid)
end

function LightView:on_set_range(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.range = value
    ilight.set_range(self.eid, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_range()
    return ilight.range(self.eid)
end

function LightView:on_set_inner_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    template.template.data.inner_radian = radian
    ilight.set_inner_radian(self.eid, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_inner_radian()
    return math.deg(ilight.inner_radian(self.eid))
end

function LightView:on_set_outter_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    if radian < template.template.data.inner_radian then
        radian = template.template.data.inner_radian
        self.subproperty.outter_radian:update()
    end
    template.template.data.outter_radian = radian
    ilight.set_outter_radian(self.eid, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_outter_radian()
    return math.deg(ilight.outter_radian(self.eid))
end

function LightView:update()
    BaseView.update(self)
    self.light_property:update() 
end

function LightView:show()
    BaseView.show(self)
    self.light_property:show()

    local leid = gizmo.target_eid
    if leid then
        local t = hierarchy:get_template(leid)
        local cb_flags = {ilight.make_shadow(leid)}

        imgui.widget.LabelText("abc", "efg")
        imgui.cursor.Indent();
        imgui.widget.PropertyLabel("make_shadow");
        if imgui.widget.Checkbox("##make_shadow", cb_flags) then
            ilight.set_make_shadow(leid, cb_flags[1])
            t.template.data.make_shadow = cb_flags[1]
        end
        local mt = ilight.motion_type(leid)
        if imgui.widget.BeginCombo("motion_type", {mt, flags=imgui.flags.Combo{}}) then
            for _, n in ipairs{"dynamic", "station", "static"} do
                if imgui.widget.Selectable(n, n == mt) then
                    ilight.set_motion_type(gizmo.target_eid, n)
                    t.template.data.motion_type = n
                end
            end

            imgui.widget.EndCombo()
        end
        imgui.cursor.Unindent();
    end
end

function LightView:has_rotate()
    if not self.eid.light then
        w:sync("light:in", self.eid)
    end
    return self.eid.light.light_type ~= "point"
end

function LightView:has_scale()
    return false
end

return LightView