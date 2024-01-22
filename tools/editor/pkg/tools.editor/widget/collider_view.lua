local ecs = ...
local world = ecs.world
local w = world.w
local iom           = ecs.require "ant.objcontroller|obj_motion"
local imaterial     = ecs.require "ant.asset|material"
local anim_view     = ecs.require "widget.animation_view"
local ImGui     = import_package "ant.imgui"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"
local collider_type = {"sphere", "box", "capsule"}
local ColliderView = {}
function ColliderView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.radius = uiproperty.Float({label = "Radius", min = 0.01, max = 10.0, speed = 0.01}, {
        getter = function()
            local e <close> = world:entity(self.eid, "collider:in")
            if e.collider.capsule then
                return e.collider.capsule[1].radius
            else
                local scale = math3d.totable(iom.get_scale(self.eid))
                return scale[1] / 100
            end
        end,
        setter = function(r)
            local ce <close> = world:entity(self.eid)
            iom.set_scale(ce, r * 100)
            --prefab_mgr:update_current_aabb(self.e)
            world:pub {"UpdateAABB", self.eid}
            anim_view.record_collision(self.eid)
        end
    })
    self.height = uiproperty.Float({label = "Height", min = 0.01, max = 10.0, speed = 0.01}, {
        getter = function()
            local e <close> = world:entity(self.eid, "collider:in")
            return e.collider.capsule[1].height
        end
    })
    self.half_size  = uiproperty.Float({label = "HalfSize", min = 0.01, max = 10.0, speed = 0.01, dim = 3}, {
        getter = function()
            local scale = math3d.totable(iom.get_scale(self.eid))
            return {scale[1] / 200, scale[2] / 200, scale[3] / 200}
        end,
        setter = function(sz)
            local ce <close> = world:entity(self.eid)
            iom.set_scale(ce, {sz[1] * 200, sz[2] * 200, sz[3] * 200})
            --prefab_mgr:update_current_aabb(self.e)
            world:pub {"UpdateAABB", self.eid}
            anim_view.record_collision(self.eid)
        end
    })
    self.color = uiproperty.Color({label = "Color", dim = 4}, {
        getter = function() return self:on_get_color() end,
        setter = function(...) self:on_set_color(...) end
    })
end

function ColliderView:set_eid(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "collider?in")
    if not e.collider then
        self.eid = nil
        return
    end
    self.eid = eid
    self:update()
end

function ColliderView:has_scale()
    return false
end

function ColliderView:on_set_color(...)
    local e <close> = world:entity(self.eid)
    imaterial.set_property(e, "u_color", ...)
end

function ColliderView:on_get_color()
    log.warn("should not call imaterial.get_property, matieral properties should edit from material view")
    -- local color = math3d.totable(rc.value)
    return {0.0, 0.0, 0.0, 0.0}--{color[1], color[2], color[3], color[4]}
end

function ColliderView:update()
    if not self.eid then
        return
    end
    local e <close> = world:entity(self.eid, "collider:in")
    if e.collider.sphere then
        self.radius:update()
    elseif e.collider.capsule then
        self.radius:update()
        self.height:update()
    elseif e.collider.box then
        self.half_size:update()
    end
    self.color:update()
end

function ColliderView:show()
    if not self.eid then
        return
    end
    local e <close> = world:entity(self.eid, "collider:in")
    if e.collider.sphere then
        self.radius:show()
    elseif e.collider.capsule then
        self.radius:show()
        self.height:show()
    elseif e.collider.box then
        self.half_size:show()
    end
    local slot_list = hierarchy.slot_list
    if slot_list then
        ImGui.PropertyLabel("LinkSlot")
        if ImGui.BeginCombo("##LinkSlot", {e.slot_name or "None", flags = ImGui.Flags.Combo {}}) then
            for name, eid in pairs(slot_list) do
                if ImGui.Selectable(name, e.slot_name and e.slot_name == name) then
                    e.slot_name = name
                    world:pub {"EntityEvent", "parent", self.eid, eid}
                end
            end
            ImGui.EndCombo()
        end
    end
    self.color:show()
end

return function ()
    ColliderView:_init()
    return ColliderView
end