local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy     = require "hierarchy"
local BaseView      = require "widget.view_class".BaseView
local ColliderView  = require "widget.view_class".ColliderView
local world
local iom
local prefab_mgr
local collider_type = {"sphere", "box", "capsule"}
function ColliderView:_init()
    BaseView._init(self)
    self.radius = uiproperty.Float({label = "Radius", min = 0.001, speed = 0.01}, {})
    self.height = uiproperty.Float({label = "Height", min = 0.001, speed = 0.01}, {})
    self.half_size = uiproperty.Float({label = "HalfSize", dim = 3, min = 0.001, speed = 0.01}, {})
end
local redefine = false
function ColliderView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end
    local tp = hierarchy:get_template(eid)
    local collider = world[eid].collider
    if collider.sphere then
        self.radius:set_getter(function() return world[eid].collider.sphere[1].radius end)
        self.radius:set_setter(function(r)
            tp.template.data.collider.sphere[1].radius = r
            redefine = true
        end)
        
    elseif collider.capsule then
        self.radius:set_getter(function() return world[eid].collider.capsule[1].radius end)
        self.radius:set_setter(function(r)
            tp.template.data.collider.capsule[1].radius = r
            redefine = true
        end)
        self.height:set_getter(function() return world[eid].collider.capsule[1].height end)
        self.height:set_setter(function(h)
            tp.template.data.collider.capsule[1].height = h
            redefine = true
        end)
    elseif collider.box then
        self.half_size:set_getter(function() return world[eid].collider.box[1].size end)
        self.half_size:set_setter(function(sz)
            tp.template.data.collider.box[1].size = sz
            collider.box.size = sz
            redefine = true
        end)
    end
    self:update()
    return true
end

function ColliderView:has_scale()
    return false
end

function ColliderView:update()
    BaseView.update(self)
    if world[self.eid].collider.sphere then
        self.radius:update()
    elseif world[self.eid].collider.capsule then
        self.radius:update()
        self.height:update()
    elseif world[self.eid].collider.box then
        self.half_size:update()
    end
end

function ColliderView:show()
    if not world[self.eid] then return end
    
    if redefine then
        self:set_model(prefab_mgr:recreate_entity(self.eid))
        redefine = false
    end
    BaseView.show(self)
    if world[self.eid].collider.sphere then
        self.radius:show()
    elseif world[self.eid].collider.capsule then
        self.radius:show()
        self.height:show()
    elseif world[self.eid].collider.box then
        self.half_size:show()
    end
    local slot_list = hierarchy.slot_list
    local e = world[self.eid]
    if slot_list then
        imgui.widget.PropertyLabel("LinkSlot")
        if imgui.widget.BeginCombo("##LinkSlot", {e.slot_name or "None", flags = imgui.flags.Combo {}}) then
            for name, eid in pairs(slot_list) do
                if imgui.widget.Selectable(name, e.slot_name and e.slot_name == name) then
                    e.slot_name = name
                    world:pub {"EntityEvent", "parent", self.eid, eid}
                end
            end
            imgui.widget.EndCombo()
        end
    end
end

return function(w)
    world   = w
    prefab_mgr = require "prefab_manager"(world)
    require "widget.base_view"(world)
    return ColliderView
end