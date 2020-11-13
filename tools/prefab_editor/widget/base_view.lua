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
    self.base        = base
    self.base_property = uiproperty.Group({label = "BaseInfo"}, base)

    local transform = {}
    transform["position"] = uiproperty.Float({label = "Position", dim = 3, speed = 0.1})
    transform["rotate"]   = uiproperty.Float({label = "Rotate", dim = 3})
    transform["scale"]    = uiproperty.Float({label = "Scale", dim = 3, speed = 0.05})
    
    self.transform        = transform
    self.transform_property = uiproperty.Group({label = "Transform"}, transform)
    --
    self.base.prefab:set_getter(function() return self:on_get_prefab() end)
    self.base.name:set_setter(function(value) self:on_set_name(value) end)      
    self.base.name:set_getter(function() return self:on_get_name() end)
    self.transform.position:set_setter(function(...) self:on_set_position(...) end)
    self.transform.position:set_getter(function() return self:on_get_position() end)
    self.transform.rotate:set_setter(function(...) self:on_set_rotate(...) end)
    self.transform.rotate:set_getter(function() return self:on_get_rotate() end)
    self.transform.scale:set_setter(function(...) self:on_set_scale(...) end)
    self.transform.scale:set_getter(function() return self:on_get_scale() end)
end

function BaseView:set_model(eid)
    if self.eid == eid then return false end
    self.eid = eid
    local template = hierarchy:get_template(eid)
    if template and template.filename then
        self.is_prefab = true
    end
    local transform = {}
    transform[#transform + 1] = self.transform.position
    if self:has_rotate() then
        transform[#transform + 1] = self.transform.rotate
    end
    if self:has_scale() then
        transform[#transform + 1] = self.transform.scale
    end
    self.transform_property:set_subproperty(transform)
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
    self.base.name:update()
    self.transform_property:update()
end

function BaseView:show()
    if self.is_prefab then
        self.base.prefab:show()
    end
    self.base.name:show()
    self.transform_property:show()
end

return function(w)
    world   = w
    iom     = world:interface "ant.objcontroller|obj_motion"
    gizmo   = require "gizmo.gizmo"(world)
    return BaseView
end