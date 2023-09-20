local ecs = ...
local world = ecs.world
local w = world.w
local ilight        = ecs.require "ant.render|light.light"
local light_gizmo   = ecs.require "gizmo.light"
local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local MOTION_TYPE_options<const> = { "dynamic", "station", "static" }
local LightView = {}
function LightView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.subproperty = {
        color        = uiproperty.Color({label = "Color", dim = 4}, {
            getter = function() return self:on_get_color() end,
            setter = function(...) self:on_set_color(...) end,
        }),
        intensity    = uiproperty.Float({label = "Intensity", min = 0, max = 250000}, {
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
            getter = function ()
                local e <close> = world:entity(self.eid, "light:in")
                return ilight.which_type(e)
            end,
            --no setter
        }),
        make_shadow = uiproperty.Bool({label = "MakeShadow"},{
            getter = function ()
                local e <close> = world:entity(self.eid, "light:in")
                return ilight.make_shadow(e)
            end,
            setter = function (value)
                local e <close> = world:entity(self.eid, "make_shadow:out")
                e.make_shadow = value
            end,
        }),
        bake        = uiproperty.Bool({label = "Bake", disable=true}, {
            getter = function () return false end,
            setter = function (value) end,
        }),
        motion_type = uiproperty.Combo({label = "motion_type", options=MOTION_TYPE_options}, {
            getter = function ()
                local e <close> = world:entity(self.eid, "light:in")
                return ilight.motion_type(e)
            end,
            setter = function (value)
                local e <close> = world:entity(self.eid, "light:in")
                ilight.set_motion_type(e, value)
             end,
        }),
        angular_radius = uiproperty.Float({label="AngularRadius", disable=true,}, {
            getter = function()
                local e <close> = world:entity(self.eid, "light:in")
                return math.deg(ilight.angular_radius(e))
            end,
            setter = function(value)
                local e <close> = world:entity(self.eid, "light:in")
                ilight.set_angular_radius(e, math.rad(value))
            end,
        }),
    }

    self.light_property= uiproperty.Group({label = "Light"}, {})
end

function LightView:set_eid(eid, base_panel)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "light?in")
    if not e.light then
        self.eid = nil
        return
    end
    self.eid = eid
    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity
    subproperty[#subproperty + 1] = self.subproperty.motion_type
    subproperty[#subproperty + 1] = self.subproperty.make_shadow
    subproperty[#subproperty + 1] = self.subproperty.bake
    subproperty[#subproperty + 1] = self.subproperty.angular_radius
    if e.light.type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if e.light.type == "spot" then
            subproperty[#subproperty + 1] = self.subproperty.inner_radian
            subproperty[#subproperty + 1] = self.subproperty.outter_radian
        end
    end
    self.light_property:set_subproperty(subproperty)
    self:update()
    if e.light.type ~= "point" then
        base_panel:disable_rotate()
    end
end

function LightView:on_set_color(...)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.light.color = ...
    local e <close> = world:entity(self.eid, "light:in")
    ilight.set_color(e, ...)
end

function LightView:on_get_color()
    local e <close> = world:entity(self.eid, "light:in")
    return ilight.color(e)
end

function LightView:on_set_intensity(value)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.light.intensity = value
    local e <close> = world:entity(self.eid, "light:in")
    ilight.set_intensity(e, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_intensity()
    local e <close> = world:entity(self.eid, "light:in")
    return ilight.intensity(e)
end

function LightView:on_set_range(value)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.light.range = value
    local e <close> = world:entity(self.eid, "light:in")
    ilight.set_range(e, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_range()
    local e <close> = world:entity(self.eid, "light:in")
    return ilight.range(e)
end

function LightView:on_set_inner_radian(value)
    local info = hierarchy:get_node_info(self.eid)
    local radian = math.rad(value)
    info.template.data.light.inner_radian = radian
    local e <close> = world:entity(self.eid, "light:in")
    ilight.set_inner_radian(e, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_inner_radian()
    local e <close> = world:entity(self.eid, "light:in")
    return math.deg(ilight.inner_radian(e))
end

function LightView:on_set_outter_radian(value)
    local info = hierarchy:get_node_info(self.eid)
    local radian = math.rad(value)
    if radian < info.template.data.light.inner_radian then
        radian = info.template.data.light.inner_radian
        self.subproperty.outter_radian:update()
    end
    info.template.data.light.outter_radian = radian
    local e <close> = world:entity(self.eid, "light:in")
    ilight.set_outter_radian(e, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_outter_radian()
    local e <close> = world:entity(self.eid, "light:in")
    return math.deg(ilight.outter_radian(e))
end

function LightView:update()
    if not self.eid then
        return
    end
    self.light_property:update()
end

function LightView:show()
    if not self.eid then
        return
    end
    self.light_property:show()
end

function LightView:has_scale()
    return false
end

return function ()
    LightView:_init()
    return LightView
end