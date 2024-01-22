local ecs = ...
local world = ecs.world
local w = world.w
local iefk          = ecs.require "ant.efk|efk"
local ImGui         = import_package "ant.imgui"
local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local EffectView    = {}

function EffectView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.group_property = uiproperty.Group({label = "Effect"}, {
        uiproperty.EditText({label = "Path", readonly = true}, {
            getter = function() return self:on_get_path() end
        }),
        uiproperty.Float({label = "Speed", min = 0.01, max = 10.0, speed = 0.01}, {
            getter = function() return self:on_get_speed() end,
            setter = function(v) self:on_set_speed(v) end
        }),
        uiproperty.Bool({label = "Fadeout"}, {
            getter = function() return self:on_get_fadeout() end,
            setter = function(v) self:on_set_fadeout(v) end
        }),
        uiproperty.Bool({label = "AutoPlay"}, {
            getter = function() return self:on_get_auto_play() end,
            setter = function(v) self:on_set_auto_play(v) end
        }),
        uiproperty.Button({label = "Play", sameline = true}, {
            click = function() self:on_play() end
        }),
        uiproperty.Button({label = "Stop"}, {
            click = function() self:on_stop() end
        }),
    })
end

function EffectView:set_eid(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "efk?in")
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
    self.group_property:update()
end

function EffectView:show()
    if not self.eid then
        return
    end
    ImGui.Separator()
    self.group_property:show()
end

function EffectView:on_play()
    local e <close> = world:entity(self.eid, "efk:in")
    iefk.play(e)
end

function EffectView:on_stop()
    local e <close> = world:entity(self.eid, "efk:in")
    iefk.stop(e)
end

function EffectView:on_get_speed()
    local info = hierarchy:get_node_info(self.eid)
    return info.template.data.efk.speed or 1.0
end

function EffectView:on_get_path()
    local info = hierarchy:get_node_info(self.eid)
    return info.template.data.efk.path
end

function EffectView:on_set_speed(value)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.efk.speed = value
    local e <close> = world:entity(self.eid, "efk:in")
    iefk.set_speed(e, value)
    world:pub { "PatchEvent", self.eid, "/data/efk/speed", value }
end

function EffectView:on_get_fadeout()
    local info = hierarchy:get_node_info(self.eid)
    return info.template.data.efk.fadeout or false
end

function EffectView:on_set_fadeout(value)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.efk.fadeout = value
end

function EffectView:on_get_auto_play()
    local info = hierarchy:get_node_info(self.eid)
    return info.template.data.visible_state == "main_queue"
end

function EffectView:on_set_auto_play(value)
    local info = hierarchy:get_node_info(self.eid)
    info.template.data.visible_state = value and "main_queue" or ""
    world:pub { "PatchEvent", self.eid, "/data/visible_state", value and "main_queue" or "" }
end

return function ()
    EffectView:_init()
    return EffectView
end