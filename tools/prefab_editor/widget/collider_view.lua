local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy"
local BaseView = require "widget.view_class".BaseView
local ColliderView = require "widget.view_class".ColliderView
local world
local iom

function ColliderView:_init()
    BaseView._init(self)
    self.radius = uiproperty.Float({label = "Radius"}, {})
    self.height = uiproperty.Float({label = "Height"}, {})
    self.half_size = uiproperty.Float({label = "HalfSize", dim = 3}, {})    
end
local redefine = nil
local skeleton_entity
function ColliderView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end
    if not skeleton_entity and world[world[eid].parent].skeleton then
        skeleton_entity = world[eid].parent
    end
    local tp = hierarchy:get_template(eid)
    local collider = world[eid].collider
    if collider.sphere then
        self.radius:set_getter(function() return world[eid].collider.sphere.radius end)
        self.radius:set_setter(function(r)
            tp.template.data.collider.sphere.radius = r
            redefine = { origin = {0, 0, 0, 1}, radius = r }
        end)
    elseif collider.capsule then
        self.radius:set_getter(function() return world[eid].collider.capsule.radius end)
        self.radius:set_setter(function(r)
            tp.template.data.collider.capsule.radius = r
            redefine = { origin = {0, 0, 0, 1}, radius = r, height = tp.template.data.collider.capsule.height }
        end)
        self.height:set_getter(function() return world[eid].collider.capsule.height end)
        self.height:set_setter(function(h)
            tp.template.data.collider.capsule.height = h
            redefine = { origin = {0, 0, 0, 1}, radius = tp.template.data.collider.capsule.radius, height = h }
        end)
    elseif collider.box then
        self.half_size:set_getter(function() return world[eid].collider.box.size end)
        self.half_size:set_setter(function(sz)
            tp.template.data.collider.box.size = sz
            collider.box.size = sz
            redefine = {
                origin = {0, 0, 0, 1},
                size = {
                    sz[1],
                    sz[2],
                    sz[3]
                }
            }
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
local function recreate_collider(col, config)
    if config.type == "capsule" then return end
    prefab_mgr:remove_entity(col.eid)
    delete_collider(col.collider)
    col.shape = config
    col.eid = prefab_mgr:create("collider", config)
end
function ColliderView:show()
    if redefine then
        local shapeType
        if world[self.eid].collider.sphere then
            shapeType = "sphere"
        elseif world[self.eid].collider.box then
            shapeType = "box"
        end
        if shapeType then
            prefab_mgr:remove_entity(self.eid)
            self:set_model(prefab_mgr:create("collider", {type = shapeType, define = redefine}))
        end
        redefine = nil
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
    local slot_list = world[skeleton_entity].slot_list
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
    require "widget.base_view"(world)
    return ColliderView
end