local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty    = require "widget.uiproperty"
local class     = utils.class
local world
local ilight
local light_gizmo

local light_view = class("LightView")
local visitor = {
    color       = {setter = function() end, getter = function() end},
    intensity   = {setter = function() end, getter = function() end},
    range       = {setter = function() end, getter = function() end},
    radian      = {setter = function() end, getter = function() end}
}

function light_view:_init()
    local subproperty = {}
    subproperty["color"]        = uiproperty.Color({label = "color", dim = 4}, visitor.color)
    subproperty["intensity"]    = uiproperty.Float({label = "intensity"}, visitor.intensity)
    subproperty["range"]        = uiproperty.Float({label = "range"}, visitor.range)
    subproperty["radian"]       = uiproperty.Float({label = "radian"}, visitor.radian)
    self.subproperty            = subproperty
    self.property               = uiproperty.Group({label = "light"}, {})
end

function light_view:set_model(eid)
    if self.eid == eid then return end
    self.eid = eid

    local subproperty = {}
    visitor.color.setter = function(...) ilight.set_color(eid, {...}) end
    visitor.color.getter = function() return math3d.totable(ilight.color(eid)) end
    subproperty[#subproperty + 1] = self.subproperty.color

    visitor.intensity.setter = function(...)
        ilight.set_intensity(eid, ...)
        light_gizmo.update_gizmo()
    end
    visitor.intensity.getter = function() return math3d.totable(ilight.intensity(eid)) end
    subproperty[#subproperty + 1] = self.subproperty.intensity

    if world[eid].light_type ~= "directional" then
        visitor.range.setter = function(...)
            ilight.set_range(eid, ...)
            light_gizmo.update_gizmo()
        end
        visitor.range.getter = function() return ilight.range(eid) end
        subproperty[#subproperty + 1] = self.subproperty.range

        if world[eid].light_type == "spot" then
            visitor.radian.setter = function(...)
                ilight.set_radian(eid, math.rad(...))
                light_gizmo.update_gizmo()
            end
            visitor.radian.getter = function() return math.deg(ilight.radian(eid)) end
            subproperty[#subproperty + 1] = self.subproperty.radian
        end
    end
    self.property:set_subproperty(subproperty)
end

function light_view:show()
    self.property:show()
end

return function(w)
    world   = w
    ilight  = world:interface "ant.render|light"
    light_gizmo = require "gizmo.light"(world)
    return light_view
end