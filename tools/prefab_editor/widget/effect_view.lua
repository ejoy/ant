local ecs = ...
local world = ecs.world
local w = world.w
ecs.require "widget.base_view"
local iefk          = ecs.import.interface "ant.efk|iefk"
local imgui         = require "imgui"
local utils         = require "common.utils"
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local BaseView      = require "widget.view_class".BaseView
local EffectView    = require "widget.view_class".EffectView
local ui_auto_play  = {false}
local ui_loop  = {false}
function EffectView:_init()
    BaseView._init(self)
    self.speed = uiproperty.Float({label = "Speed", min = 0.01, max = 10.0, speed = 0.01}, {})
    self.path = uiproperty.EditText({label = "path", readonly = true})
    self.path:set_getter(function() return self:on_get_path() end)
end

function EffectView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end
    self.speed:set_getter(function() return self:on_get_speed() end)
    self.speed:set_setter(function(v) self:on_set_speed(v) end)
    self:update()
    return true
end

function EffectView:update()
    BaseView.update(self)
    self.path:update()
    self.speed:update()
    local template = hierarchy:get_template(self.eid)
    ui_auto_play[1] = template.template.data.efk.auto_play or false
    ui_loop[1] = template.template.data.efk.loop or false
end

function EffectView:show()
    BaseView.show(self)
    imgui.cursor.Separator()
    self.path:show()
    self.speed:show()
    imgui.widget.PropertyLabel("auto_play")
    if imgui.widget.Checkbox("##auto_play", ui_auto_play) then
        self:on_set_auto_play(ui_auto_play[1])
    end
    imgui.widget.PropertyLabel("loop")
    if imgui.widget.Checkbox("##loop", ui_loop) then
        self:on_set_loop(ui_loop[1])
    end
    imgui.cursor.Separator()
    if imgui.widget.Button("Play") then
        local e <close> = w:entity(self.eid)
        iefk.play(e)
    end
    imgui.cursor.SameLine()
    if imgui.widget.Button("Stop") then
        local e <close> = w:entity(self.eid)
        iefk.stop(e)
    end
end

function EffectView:on_get_speed()
    local tpl = hierarchy:get_template(self.eid)
    return tpl.template.data.efk.speed or 1.0
end

function BaseView:on_get_path()
    local tpl = hierarchy:get_template(self.eid)
    return tpl.template.data.efk.path
end

function EffectView:on_set_speed(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.speed = value
    local e <close> = w:entity(self.eid)
    iefk.set_speed(e, value)
end

function EffectView:on_set_auto_play(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.auto_play = value
end

function EffectView:on_set_loop(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.loop = value
    local e <close> = w:entity(self.eid)
    iefk.set_loop(e, value)
end

return EffectView