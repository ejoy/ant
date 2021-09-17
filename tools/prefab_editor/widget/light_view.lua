local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty    = require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"
local world
local ilight
local light_gizmo

local BaseView = require "widget.view_class".BaseView
local LightView = require "widget.view_class".LightView

function LightView:_init()
    BaseView._init(self)
    local subproperty = {}
    subproperty["color"]        = uiproperty.Color({label = "Color", dim = 4})
    subproperty["intensity"]    = uiproperty.Float({label = "Intensity", min = 0, max = 100})
    subproperty["range"]        = uiproperty.Float({label = "Range", min = 0, max = 500})
    subproperty["inner_radian"]       = uiproperty.Float({label = "InnerRadian", min = 0, max = 180})
    subproperty["outter_radian"]       = uiproperty.Float({label = "OutterRadian", min = 0, max = 180})
    self.subproperty            = subproperty
    self.light_property         = uiproperty.Group({label = "Light"}, {})
    --
    self.subproperty.color:set_getter(function() return self:on_get_color() end)
    self.subproperty.color:set_setter(function(...) self:on_set_color(...) end)
    self.subproperty.intensity:set_getter(function() return self:on_get_intensity() end)
    self.subproperty.intensity:set_setter(function(value) self:on_set_intensity(value) end)
    self.subproperty.range:set_getter(function() return self:on_get_range() end)
    self.subproperty.range:set_setter(function(value) self:on_set_range(value) end)
    self.subproperty.inner_radian:set_getter(function() return self:on_get_inner_radian() end)
    self.subproperty.inner_radian:set_setter(function(value) self:on_set_inner_radian(value) end)
    self.subproperty.outter_radian:set_getter(function() return self:on_get_outter_radian() end)
    self.subproperty.outter_radian:set_setter(function(value) self:on_set_outter_radian(value) end)
end

function LightView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end

    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity
    if world[eid].light_type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if world[eid].light_type == "spot" then
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
end

function LightView:has_rotate()
    return world[self.eid].light_type ~= "point"
end

function LightView:has_scale()
    return false
end

return function(ecs, w)
    world   = w
    ilight  = ecs.import.interface "ant.render|light"
    light_gizmo = require "gizmo.light"(ecs, world)
    require "widget.base_view"(ecs, world)
    return LightView
end