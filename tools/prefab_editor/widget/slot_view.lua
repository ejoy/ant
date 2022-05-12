local ecs = ...
local world = ecs.world
local w = world.w
ecs.require "widget.base_view"

local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local joint_utils = require "widget.joint_utils"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"
local BaseView = require "widget.view_class".BaseView
local SlotView = require "widget.view_class".SlotView

local follow_flag = {
    "pos",
    "scale|pos",
    "scale|rot|pos"
}

function SlotView:_init()
    BaseView._init(self)
    self.slot = uiproperty.Group({label="Slot", flags=imgui.flags.TreeNode{"DefaultOpen"}}, {
            uiproperty.Combo({label="FollowJoint", options={}}, {
                getter = function()
                    local tp = hierarchy:get_template(self.eid)
                    return tp.template.data.slot.joint_name or "(NONE)"
                end,
                setter = function(name)
                    local tp = hierarchy:get_template(self.eid)
                    tp.template.data.slot.joint_name = name
                    world:entity(self.eid).slot.joint_name = name
                end,
            }),
            uiproperty.Combo({label="FollowFlag", options={}}, {
                getter = function()
                    local tp = hierarchy:get_template(self.eid)
                    return follow_flag[tp.template.data.slot.follow_flag or 1]
                end,
                setter = function(flag_name)
                    local flag = 1
                    if flag_name == follow_flag[1] then
                        flag = 1
                    elseif flag_name == follow_flag[2] then
                        flag = 2
                    elseif flag_name == follow_flag[3] then
                        flag = 3
                    end
                    local tp = hierarchy:get_template(self.eid)
                    tp.template.data.slot.follow_flag = flag
                    world:entity(self.eid).slot.follow_flag = flag
                end,
            }),
        }
    )
end

local joint_name_list = {}

function SlotView:set_model(eid)
    if #joint_name_list < 1 then
        local _, joint_list = joint_utils:get_joints()
        if joint_list then
            for _, joint in ipairs(joint_list) do
                joint_name_list[#joint_name_list+1] = joint.name
            end
        end
    end

    if not BaseView.set_model(self, eid) then return false end

    local fj = self.slot:find_property_by_label "FollowJoint"
    fj:set_options(joint_name_list)

    local ff = self.slot:find_property_by_label "FollowFlag"
    ff:set_options(follow_flag)

    self:update()
    return true
end

-- function SlotView:has_scale()
--     return false
-- end

function SlotView:update()
    BaseView.update(self)
    self.slot:update()
end

function SlotView:show()
    BaseView.show(self)
    self.slot:show()
end

return SlotView