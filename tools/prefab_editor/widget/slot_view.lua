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
            uiproperty.Int({label="FollowFlag"}, {
                getter = function()
                    local tp = hierarchy:get_template(self.eid)
                    return tp.template.data.slot.follow_flag
                end,
                setter = function(flag)
                    local tp = hierarchy:get_template(self.eid)
                    tp.template.data.follow_flag = flag
                    world:entity(self.eid).slot.follow_flag = flag
                end,
            })
        }
    )
end

local joint_name_list = {}

function SlotView:set_model(eid)
    if #joint_name_list < 1 then
        local joint_list = joint_utils:get_joints()
        for _, joint in ipairs(joint_list) do
            joint_name_list[#joint_name_list+1] = joint.name
        end
    end

    if not BaseView.set_model(self, eid) then return false end

    local fj = self.slot:find_property_by_label "FollowJoint"
    
    fj:set_options(joint_name_list)

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