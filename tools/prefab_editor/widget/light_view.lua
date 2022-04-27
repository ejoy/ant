local ecs = ...
local world = ecs.world
local w = world.w
local ilight    = ecs.import.interface "ant.render|ilight"
local light_gizmo = ecs.require "gizmo.light"
local gizmo = ecs.require "gizmo.gizmo"
ecs.require "widget.base_view"

local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty= require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"

local imgui     = require "imgui"

local view_class = require "widget.view_class"
local BaseView, LightView  = view_class.BaseView, view_class.LightView

local MOTION_TYPE_options<const> = {
    "dynamic", "station", "static"
}

function LightView:_init()
    BaseView._init(self)
    self.subproperty = {
        color        = uiproperty.Color({label = "Color", dim = 4}, {
            getter = function() return self:on_get_color() end,
            setter = function(...) self:on_set_color(...) end,
        }),
        intensity    = uiproperty.Float({label = "Intensity", min = 0, max = 500}, {
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
        type  = uiproperty.EditText({label = "LightType", readonly=true}, {
            getter = function () return ilight.which_type(world:entity(self.eid)) end,
            --no setter
        }),
        make_shadow = uiproperty.Bool({label = "MakeShadow"},{
            getter = function () return ilight.make_shadow(world:entity(self.eid)) end,
            setter = function (value) world:entity(self.eid).make_shadow = value end,
        }),
        bake        = uiproperty.Bool({label = "Bake", disable=true}, {
            getter = function () return false end,
            setter = function (value) end,
        }),
        motion_type = uiproperty.Combo({label = "motion_type", options=MOTION_TYPE_options}, {
            getter = function () return ilight.motion_type(world:entity(self.eid)) end,
            setter = function (value) ilight.set_motion_type(world:entity(self.eid), value) end,
        }),
        angular_radius= uiproperty.Float({label="AngularRadius", disable=true,}, {
            getter = function() return math.deg(ilight.angular_radius(world:entity(self.eid))) end,
            setter = function(value) ilight.set_angular_radius(world:entity(self.eid), math.rad(value)) end,
        }),
    }

    self.light_property= uiproperty.Group({label = "Light"}, {})
end

function LightView:set_model(e)
    if not BaseView.set_model(self, e) then return false end
    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity

    subproperty[#subproperty + 1] = self.subproperty.motion_type
    subproperty[#subproperty + 1] = self.subproperty.make_shadow
    subproperty[#subproperty + 1] = self.subproperty.bake
    subproperty[#subproperty + 1] = self.subproperty.angular_radius

    if world:entity(e).light.type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if world:entity(e).light.type == "spot" then
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
    ilight.set_color(world:entity(self.eid), ...)
end

function LightView:on_get_color()
    return ilight.color(world:entity(self.eid))
end

function LightView:on_set_intensity(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.intensity = value
    ilight.set_intensity(world:entity(self.eid), value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_intensity()
    return ilight.intensity(world:entity(self.eid))
end

function LightView:on_set_range(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.range = value
    ilight.set_range(world:entity(self.eid), value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_range()
    return ilight.range(world:entity(self.eid))
end

function LightView:on_set_inner_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    template.template.data.inner_radian = radian
    ilight.set_inner_radian(world:entity(self.eid), radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_inner_radian()
    return math.deg(ilight.inner_radian(world:entity(self.eid)))
end

function LightView:on_set_outter_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    if radian < template.template.data.inner_radian then
        radian = template.template.data.inner_radian
        self.subproperty.outter_radian:update()
    end
    template.template.data.outter_radian = radian
    ilight.set_outter_radian(world:entity(self.eid), radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_outter_radian()
    return math.deg(ilight.outter_radian(world:entity(self.eid)))
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
    return world:entity(self.eid).light.type ~= "point"
end

function LightView:has_scale()
    return false
end

return LightView