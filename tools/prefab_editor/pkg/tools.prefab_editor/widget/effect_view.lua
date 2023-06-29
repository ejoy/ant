local ecs = ...
local world = ecs.world
local w = world.w
local iefk          = ecs.import.interface "ant.efk|iefk"
local imgui         = require "imgui"
local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local EffectView    = {}
local ui_auto_play  = {false}
local ui_loop       = {false}

function EffectView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.speed = uiproperty.Float({label = "Speed", min = 0.01, max = 10.0, speed = 0.01}, {
        getter = function() return self:on_get_speed() end,
        setter = function(v) self:on_set_speed(v) end
    })
    self.path = uiproperty.EditText({label = "path", readonly = true}, {
        getter = function() return self:on_get_path() end
    })
end

function EffectView:set_model(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then
        self.eid = nil
        return
    end
    self.eid = eid
    self:update()
end

function EffectView:update()
    if not self.eid then
        return
    end
    self.path:update()
    self.speed:update()
    local template = hierarchy:get_template(self.eid)
    ui_auto_play[1] = template.template.data.efk.auto_play or false
    ui_loop[1] = template.template.data.efk.loop or false
end

function EffectView:show()
    if not self.eid then
        return
    end
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
        iefk.play(self.eid)
    end
    imgui.cursor.SameLine()
    if imgui.widget.Button("Stop") then
        iefk.stop(self.eid)
    end
end

function EffectView:on_get_speed()
    local tpl = hierarchy:get_template(self.eid)
    return tpl.template.data.efk.speed or 1.0
end

function EffectView:on_get_path()
    local tpl = hierarchy:get_template(self.eid)
    return tpl.template.data.efk.path
end

function EffectView:on_set_speed(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.speed = value
    iefk.set_speed(self.eid, value)
end

function EffectView:on_set_auto_play(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.auto_play = value
end

function EffectView:on_set_loop(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.efk.loop = value
    iefk.set_loop(self.eid, value)
end

return function ()
    EffectView:_init()
    return EffectView
end