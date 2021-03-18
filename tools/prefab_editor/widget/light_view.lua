local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty    = require "widget.uiproperty"
local world
local ilight
local light_gizmo

local BaseView = require "widget.view_class".BaseView
local LightView = require "widget.view_class".LightView

function LightView:_init()
    BaseView._init(self)
    local subproperty = {}
    subproperty["color"]        = uiproperty.Color({label = "Color", dim = 4})
    subproperty["intensity"]    = uiproperty.Float({label = "Intensity"})
    subproperty["range"]        = uiproperty.Float({label = "Range"})
    subproperty["radian"]       = uiproperty.Float({label = "Radian"})
    self.subproperty            = subproperty
    self.light_property         = uiproperty.Group({label = "Light"}, {})
    --
    self.subproperty.color:set_getter(function() return self:on_get_color() end)
    self.subproperty.color:set_setter(function(...) self:on_set_color(...) end)
    self.subproperty.intensity:set_getter(function() return self:on_get_intensity() end)
    self.subproperty.intensity:set_setter(function(...) self:on_set_intensity(...) end)
    self.subproperty.range:set_getter(function() return self:on_get_range() end)
    self.subproperty.range:set_setter(function(value) self:on_set_range(value) end)
    self.subproperty.radian:set_getter(function() return self:on_get_radian() end)
    self.subproperty.radian:set_setter(function(value) self:on_set_radian(value) end)
end

function LightView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end

    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity
    if world[eid].light_type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if world[eid].light_type == "spot" then
            subproperty[#subproperty + 1] = self.subproperty.radian
        end
    end
    self.light_property:set_subproperty(subproperty)
    self:update()
    return true
end

function LightView:on_set_color(...)
    ilight.set_color(self.eid, ...)
    ilight.update_light_buffers()
end

function LightView:on_get_color()
    return ilight.color(self.eid)
end

function LightView:on_set_intensity(...)
    ilight.set_intensity(self.eid, ...)
    light_gizmo.update_gizmo()
    ilight.update_light_buffers()
end

function LightView:on_get_intensity()
    return ilight.intensity(self.eid)
end

function LightView:on_set_range(value)
    ilight.set_range(self.eid, value)
    light_gizmo.update_gizmo()
    ilight.update_light_buffers()
end

function LightView:on_get_range()
    return ilight.range(self.eid)
end

function LightView:on_set_radian(value)
    ilight.set_radian(self.eid, math.rad(value))
    light_gizmo.update_gizmo()
    ilight.update_light_buffers()
end

function LightView:on_get_radian()
    return math.deg(ilight.radian(self.eid))
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

return function(w)
    world   = w
    ilight  = world:interface "ant.render|light"
    light_gizmo = require "gizmo.light"(world)
    require "widget.base_view"(world)
    return LightView
end