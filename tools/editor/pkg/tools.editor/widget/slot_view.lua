local ecs = ...
local world = ecs.world
local w = world.w

local ImGui     = import_package "ant.imgui"
local joint_utils = require "widget.joint_utils"
local uiproperty = require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"

local follow_flag = {
    "pos",
    "scale|pos",
    "scale|rot|pos"
}

local SlotView = {}
function SlotView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.slot = uiproperty.Group({label="Slot", flags=ImGui.Flags.TreeNode{"DefaultOpen"}}, {
            uiproperty.Combo({label="FollowJoint", options={}}, {
                getter = function()
                    local info = hierarchy:get_node_info(self.eid)
                    return info.template.data.slot.joint_name or "(NONE)"
                end,
                setter = function(name)
                    local info = hierarchy:get_node_info(self.eid)
                    if info.template.data.slot.joint_name ~= name then
                        info.template.data.slot.joint_name = name
                        local e <close> = world:entity(self.eid, "slot:in")
                        e.slot.joint_name = name
                        e.slot.joint_index = nil
                        -- if name == "None" then
                        -- end
                    end
                end,
            }),
            uiproperty.Combo({label="FollowFlag", options={}}, {
                getter = function()
                    local info = hierarchy:get_node_info(self.eid)
                    return follow_flag[info.template.data.slot.follow_flag or 1]
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
                    local info = hierarchy:get_node_info(self.eid)
                    info.template.data.slot.follow_flag = flag
                    local e <close> = world:entity(self.eid, "slot:in")
                    e.slot.follow_flag = flag
                end,
            }),
        }
    )
end

local joint_name_list = {"None"}

function SlotView:set_eid(eid)
    if #joint_name_list < 2 then
        local _, joint_list = joint_utils:get_joints()
        if joint_list then
            for _, joint in ipairs(joint_list) do
                joint_name_list[#joint_name_list+1] = joint.name
            end
        end
    end

    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "slot?in")
    if not e.slot then
        self.eid = nil
        return
    end

    local fj = self.slot:find_property_by_label "FollowJoint"
    fj:set_options(joint_name_list)
    local ff = self.slot:find_property_by_label "FollowFlag"
    ff:set_options(follow_flag)
    self.eid = eid
    self:update()
end

function SlotView:update()
    if not self.eid then
        return
    end
    self.slot:update()
end

function SlotView:show()
    if not self.eid then
        return
    end
    self.slot:show()
end

return function ()
    SlotView:_init()
    return SlotView
end