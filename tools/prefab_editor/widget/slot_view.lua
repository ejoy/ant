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
    if not joint_name_list[eid] then
        local name_list = {}
        local parent = world:entity(eid).scene.parent
        if parent then
            -- local jlist = world[parent].joint_list
            for e in w:select "scene:in _animation:in" do
                if e.scene.id == parent then
                    for _, joints in pairs(e._animation.joint_list) do
                        for _, joint in ipairs(joints) do
                            name_list[#name_list+1] = joint.name
                        end
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

    local fj = self.slot:find_property_by_label "FollowJoint"
    fj:set_options(joint_name_list[eid])

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