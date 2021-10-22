local ecs = ...
local world = ecs.world
local w = world.w
ecs.require "widget.base_view"

local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"
local BaseView = require "widget.view_class".BaseView
local SlotView = require "widget.view_class".SlotView

function SlotView:_init()
    BaseView._init(self)
    self.follow_joint = uiproperty.Combo({label = "FollowJoint", options = {}}, {})
    self.follow_flag = uiproperty.Int({label = "FollowFlag"}, {})
end

local joint_name_list = {}

function SlotView:set_model(eid)
    if not joint_name_list[eid] then
        local name_list = {}
        local parent = eid.scene.parent
        if parent then
            -- local jlist = world[parent].joint_list
            for e in w:select "scene:in _animation:in" do
                if e.scene.id == parent then
                    for _, joint in ipairs(e._animation.joint_list) do
                        name_list[joint.index] = joint.name
                    end
                end
            end
            -- if jlist then
            --     for _, joint in ipairs(jlist) do
            --         name_list[joint.index] = joint.name
            --     end
            -- end
        end
        joint_name_list[eid] = name_list
    end

    if not BaseView.set_model(self, eid) then return false end
    self.follow_joint:set_options(joint_name_list[eid])
    self.follow_joint:set_getter(function()
        local tp = hierarchy:get_template(self.eid)
        return tp.template.data.follow_joint or "None"
    end)
    self.follow_joint:set_setter(function(name)
        local tp = hierarchy:get_template(self.eid)
        local joint_name = (name ~= "None") and name or nil
        tp.template.data.follow_joint = joint_name
        for v in w:select "scene:in _animation:in" do
            if v.scene.id == eid.scene.id then
                v._animation.follow_joint = joint_name
            end
        end
        --world[eid].follow_joint = joint_name
    end)
    self.follow_flag:set_getter(function()
        --return world[eid].follow_flag
        local tp = hierarchy:get_template(self.eid)
        return tp.template.data.follow_flag
    end)
    self.follow_flag:set_setter(function(flag)
        local tp = hierarchy:get_template(self.eid)
        tp.template.data.follow_flag = flag
        for v in w:select "scene:in _animation:in" do
            if v.scene.id == eid.scene.id then
                v._animation.follow_flag = flag
            end
        end
        --world[eid].follow_flag = flag
    end)
    self:update()
    return true
end

-- function SlotView:has_scale()
--     return false
-- end

function SlotView:update()
    BaseView.update(self)
    self.follow_joint:update()
    self.follow_flag:update()
end

function SlotView:show()
    BaseView.show(self)
    self.follow_joint:show()
    self.follow_flag:show()
end

return SlotView