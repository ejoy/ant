local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg       = import_package "ant.math"
local mu            = mathpkg.util

local ilight        = ecs.import.interface "ant.render|light"
local iom           = ecs.import.interface "ant.objcontroller|obj_motion"

local light_gizmo   = ecs.require "gizmo.light"
local gizmo         = ecs.require "gizmo.gizmo"
local comp_ui       = require "widget.component_ui"
local comp_defines  = require "widget.component_defines"

local utils     = require "common.utils"
local math3d    = require "math3d"

local light_view = {}
function light_view:update()
end

function light_view:show()
    local eid = gizmo.target_eid
    if eid == nil then 
        return
    end

    local function build_component_tree(l)
        return {
            name     = l.name,
            transform = {
                s = {math3d.index(iom.get_scale(eid), 1, 2, 3)},
                r = mu.to_angle{math3d.index(math3d.quat2euler(iom.get_rotation(eid)), 1, 2, 3)},
                t = {math3d.index(iom.get_position(eid), 1, 2, 3)},
            },
            light = {
                range       = ilight.range(eid),
                light_type  = ilight.which_type(eid),
                color       = ilight.color(eid),
                intensity   = ilight.intensity(eid),
                make_shadow = ilight.make_shadow(eid),
                motion_type = ilight.motion_type(eid),
                inner_cutoff= math.deg(ilight.inner_radian(eid)),
                outter_cutoff=math.deg(ilight.outter_radian(eid)),
                angular_radius=math.deg(ilight.angular_radius(eid)),
            },
        }
    end

    local function update_component(update_values)
        if update_values.name then
            world[eid].name = update_values.name
        end

        local trans = update_values.transform
        if trans then
            if trans.s then
                iom.set_scale(eid, trans.s)
            end
            if trans.r then
                iom.set_rotation(eid, math3d.quaternion(mu.to_radian(trans.r)))
            end
            if trans.t then
                iom.set_position(eid, trans.t)
            end
        end

        local light = update_values.light
        if light then
            if light.range then
                ilight.set_range(eid, light.range)
            end

            if light.light_type then
                log.warn("light_type should not modify")
            end
            if light.color then
                ilight.set_color(eid, light.color)
            end
            if light.intensity then
                ilight.set_intensity(eid, light.intensity)
            end
            if light.make_shadow then
                ilight.set_make_shadow(eid, light.make_shadow)
            end
            if light.motion_type then
                ilight.set_motion_type(eid, light.motion_type)
            end
            if light.inner_cutoff then
                ilight.set_inner_radian(eid, math.rad(light.inner_cutoff))
            end
            if light.outter_cutoff then
                ilight.set_outter_radian(eid, math.rad(light.outter_cutoff))
            end
            if light.angular_radius then
                ilight.set_angular_radius(eid, math.rad(light.angular_radius))
            end
            
        end
    end
    local update_values = {}
    comp_ui.build("Entity", build_component_tree(world[eid]), comp_defines.desc, update_values)
    if update_values.Entity then
        update_component(update_values.Entity)
        light_gizmo.update_gizmo()
    end
end

return light_view

-- function LightView:_init()
--     BaseView._init(self)
--     self.subproperty = {
--         color        = uiproperty.Color({label = "Color", dim = 4}, {
--             getter = function() return self:on_get_color() end,
--             setter = function(...) self:on_set_color(...) end,
--         }),
--         intensity    = uiproperty.Float({label = "Intensity", min = 0, max = 100}, {
--             getter = function() return self:on_get_intensity() end,
--             setter = function(value) self:on_set_intensity(value) end,
--         }),
--         range        = uiproperty.Float({label = "Range", min = 0, max = 500},{
--             getter = function() return self:on_get_range() end,
--             setter = function(value) self:on_set_range(value) end,
--         }),
--         inner_radian = uiproperty.Float({label = "InnerRadian", min = 0, max = 180},{
--             getter = function() return self:on_get_inner_radian() end,
--             setter = function(value) self:on_set_inner_radian(value) end,
--         }),
--         outter_radian= uiproperty.Float({label = "OutterRadian", min = 0, max = 180}, {
--             getter = function() return self:on_get_outter_radian() end,
--             setter = function(value) self:on_set_outter_radian(value) end,
--         }),
--     }

--     self.light_property= uiproperty.Group({label = "Light"}, {})
-- end

-- function LightView:set_model(eid)
--     if not BaseView.set_model(self, eid) then return false end

--     local subproperty = {}
--     subproperty[#subproperty + 1] = self.subproperty.color
--     subproperty[#subproperty + 1] = self.subproperty.intensity
--     if world[eid].light_type ~= "directional" then
--         subproperty[#subproperty + 1] = self.subproperty.range
--         if world[eid].light_type == "spot" then
--             subproperty[#subproperty + 1] = self.subproperty.inner_radian
--             subproperty[#subproperty + 1] = self.subproperty.outter_radian
--         end
--     end
--     self.light_property:set_subproperty(subproperty)
--     self:update()
--     return true
-- end

-- function LightView:on_set_color(...)
--     local template = hierarchy:get_template(self.eid)
--     template.template.data.color = ...
--     ilight.set_color(self.eid, ...)
-- end

-- function LightView:on_get_color()
--     return ilight.color(self.eid)
-- end

-- function LightView:on_set_intensity(value)
--     local template = hierarchy:get_template(self.eid)
--     template.template.data.intensity = value
--     ilight.set_intensity(self.eid, value)
--     light_gizmo.update_gizmo()
-- end

-- function LightView:on_get_intensity()
--     return ilight.intensity(self.eid)
-- end

-- function LightView:on_set_range(value)
--     local template = hierarchy:get_template(self.eid)
--     template.template.data.range = value
--     ilight.set_range(self.eid, value)
--     light_gizmo.update_gizmo()
-- end

-- function LightView:on_get_range()
--     return ilight.range(self.eid)
-- end

-- function LightView:on_set_inner_radian(value)
--     local template = hierarchy:get_template(self.eid)
--     local radian = math.rad(value)
--     template.template.data.inner_radian = radian
--     ilight.set_inner_radian(self.eid, radian)
--     light_gizmo.update_gizmo()
-- end

-- function LightView:on_get_inner_radian()
--     return math.deg(ilight.inner_radian(self.eid))
-- end

-- function LightView:on_set_outter_radian(value)
--     local template = hierarchy:get_template(self.eid)
--     local radian = math.rad(value)
--     if radian < template.template.data.inner_radian then
--         radian = template.template.data.inner_radian
--         self.subproperty.outter_radian:update()
--     end
--     template.template.data.outter_radian = radian
--     ilight.set_outter_radian(self.eid, radian)
--     light_gizmo.update_gizmo()
-- end

-- function LightView:on_get_outter_radian()
--     return math.deg(ilight.outter_radian(self.eid))
-- end

-- function LightView:update()
--     BaseView.update(self)
--     self.light_property:update() 
-- end

-- function LightView:show()
--     BaseView.show(self)
--     self.light_property:show()

--     local leid = gizmo.target_eid
--     if leid then
--         local t = hierarchy:get_template(leid)
--         local cb_flags = {ilight.make_shadow(leid)}

--         imgui.widget.LabelText("abc", "efg")
--         imgui.cursor.Indent();
--         imgui.widget.PropertyLabel("make_shadow");
--         if imgui.widget.Checkbox("##make_shadow", cb_flags) then
--             ilight.set_make_shadow(leid, cb_flags[1])
--             t.template.data.make_shadow = cb_flags[1]
--         end
--         local mt = ilight.motion_type(leid)
--         if imgui.widget.BeginCombo("motion_type", {mt, flags=imgui.flags.Combo{}}) then
--             for _, n in ipairs{"dynamic", "station", "static"} do
--                 if imgui.widget.Selectable(n, n == mt) then
--                     ilight.set_motion_type(gizmo.target_eid, n)
--                     t.template.data.motion_type = n
--                 end
--             end

--             imgui.widget.EndCombo()
--         end
--         imgui.cursor.Unindent();
--     end
-- end

-- function LightView:has_rotate()
--     return world[self.eid].light_type ~= "point"
-- end

-- function LightView:has_scale()
--     return false
-- end

-- return LightView
