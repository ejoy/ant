local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy     = require "hierarchy"
local effekseer = require "effekseer"
local BaseView      = require "widget.view_class".BaseView
local EffectView  = require "widget.view_class".EffectView
local ui_auto_play = {false}
local ui_loop = { true }
function EffectView:_init()
    BaseView._init(self)
    self.speed = uiproperty.Float({label = "Speed", min = 0.01, max = 10.0, speed = 0.01}, {})
end

function EffectView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end
    if world[eid].effect_instance then
        --local tp = hierarchy:get_template(eid)
        self.speed:set_getter(function() return world[eid].effect_instance.speed end)
        self.speed:set_setter(function(v) self:on_set_speed(v) end)
    end
    self:update()
    return true
end

function EffectView:update()
    BaseView.update(self)
    self.speed:update()
    ui_auto_play[1] = world[self.eid].effect_instance.auto_play
    ui_loop[1] = world[self.eid].effect_instance.loop
end

function EffectView:show()
    BaseView.show(self)
    self.speed:show()
    imgui.widget.PropertyLabel("auto_play")
    if imgui.widget.Checkbox("##auto_play", ui_auto_play) then
        self:on_set_auto_play(ui_auto_play[1])
    end
    imgui.widget.PropertyLabel("loop")
    if imgui.widget.Checkbox("##loop", ui_loop) then
        self:on_set_loop(ui_loop[1])
    end
end

function EffectView:on_set_speed(value)
    local instance = world[self.eid].effect_instance
    instance.speed = value
    effekseer.set_speed(instance.handle, value)
end

function EffectView:on_set_auto_play(value)
    world[self.eid].effect_instance.auto_play = value
end

function EffectView:on_set_loop(value)
    local instance = world[self.eid].effect_instance
    instance.loop = value
    effekseer.set_loop(instance.handle, value)
end

return function(w)
    world   = w
    require "widget.base_view"(world)
    return EffectView
end