local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy"
local BaseView  = require "widget.view_class".BaseView
local world
local iom
local gizmo

function BaseView:_init()
    local base = {}
    base["prefab"]   = uiproperty.EditText({label = "Prefabe", readonly = true})
    base["name"]     = uiproperty.EditText({label = "Name"})
    base["position"] = uiproperty.Float({label = "Position", dim = 3, speed = 0.1})
    base["rotate"]   = uiproperty.Float({label = "Rotate", dim = 3})
    base["scale"]    = uiproperty.Float({label = "Scale", dim = 3, speed = 0.05})
    
    self.base        = base
    self.general_property = uiproperty.Group({label = "General"}, base)
    --
    self.base.prefab:set_getter(function() return self:on_get_prefab() end)
    self.base.name:set_setter(function(value) self:on_set_name(value) end)      
    self.base.name:set_getter(function() return self:on_get_name() end)
    self.base.position:set_setter(function(...) self:on_set_position(...) end)
    self.base.position:set_getter(function() return self:on_get_position() end)
    self.base.rotate:set_setter(function(...) self:on_set_rotate(...) end)
    self.base.rotate:set_getter(function() return self:on_get_rotate() end)
    self.base.scale:set_setter(function(...) self:on_set_scale(...) end)
    self.base.scale:set_getter(function() return self:on_get_scale() end)
end

function BaseView:set_model(eid)
    if self.eid == eid then return false end
    self.eid = eid
    self.is_prefab = false
    local template = hierarchy:get_template(eid)
    if template and template.filename then
        self.is_prefab = true
    end
    local transform = {}
    transform[#transform + 1] = self.base.position
    if self:has_rotate() then
        transform[#transform + 1] = self.base.rotate
    end
    if self:has_scale() then
        transform[#transform + 1] = self.base.scale
    end
    self.general_property:set_subproperty(transform)
    BaseView.update(self)
    return true
end

function BaseView:on_get_prefab()
    local template = hierarchy:get_template(self.eid)
    if template and template.filename then
        return template.filename
    end
end

function BaseView:on_set_name(value)
    world[self.eid].name = value
    world:pub {"EntityEvent", "name", self.eid, value}
end

function BaseView:on_get_name()
    return world[self.eid].name
end

function BaseView:on_set_position(...)
    world:pub {"EntityEvent", "move", self.eid, math3d.totable(iom.get_position(self.eid)), {...}}
end

function BaseView:on_get_position()
    return math3d.totable(iom.get_position(self.eid))
end

function BaseView:on_set_rotate(...)
    world:pub {"EntityEvent", "rotate", self.eid, math3d.totable(iom.get_rotation(self.eid)), {...}}
end

function BaseView:on_get_rotate()
    local r = iom.get_rotation(self.eid)
    local rad = math3d.totable(math3d.quat2euler(r))
    return { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
end

function BaseView:on_set_scale(...)
    world:pub {"EntityEvent", "scale", self.eid, math3d.totable(iom.get_scale(self.eid)), {...}}
end

function BaseView:on_get_scale()
    return math3d.totable(iom.get_scale(self.eid))
end

function BaseView:has_rotate()
    return true
end

function BaseView:has_scale()
    return true
end

function BaseView:update()
    if self.is_prefab then
        self.base.prefab:update()
    end
    self.general_property:update()
end

function BaseView:show()
    if self.is_prefab then
        self.base.prefab:show()
    end
    self.general_property:show()
end

return function(w)
    world   = w
    iom     = world:interface "ant.objcontroller|obj_motion"
    gizmo   = require "gizmo.gizmo"(world)
    return BaseView
end