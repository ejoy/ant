local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local iom   = ecs.require "ant.objcontroller|obj_motion"

--TODO: this file need skeleton component, should move to animation package to fix circle dependence

local r2l_mat<const> = mc.R2L_MAT

local sys = ecs.system "slot_system"

function sys:start_frame()
end

function sys:entity_init()
    for e in w:select "INIT slot:in skeleton:in" do
        local slot = e.slot
        local jn = slot.joint_name
        local ske = e.skeleton
        slot.joint_index = assert(ske:joint_index(jn))
    end
end

local function calc_pose_mat(pose_result, slot)
    local adjust_mat = math3d.mul(r2l_mat, pose_result.models:joint(slot.joint_index)) --pose_result.models:joint(slot.joint_index) --
    -- if slot.offset_srt then
    --     local offset_mat = math3d.matrix(slot.offset_srt)
    --     adjust_mat = math3d.mul(adjust_mat, offset_mat)
    -- end
    return adjust_mat
end

function sys:update_slot()
	for v in w:select "boneslot slot:in scene:update eid:in" do
        local slot = v.slot
        local pose_result = slot.pose and slot.pose.pose_result
        if pose_result then
            if not slot.joint_index and slot.joint_name then
                slot.joint_index = slot.pose.skeleton:joint_index(slot.joint_name)
            end
            local slot_matrix
            local follow_flag = assert(slot.follow_flag)
            if follow_flag == 1 or follow_flag == 2 then
                if slot.joint_index then
                    local adjust_mat = calc_pose_mat(pose_result, slot)
                    if follow_flag == 1 then
                        slot_matrix = math3d.set_index(mc.IDENTITY_MAT, 4, math3d.index(adjust_mat, 4))
                    else
                        local _, r, t = math3d.srt(adjust_mat)
                        slot_matrix = math3d.matrix{r=r, t=t}
                    end
                end
            elseif follow_flag == 3 then
                slot_matrix = calc_pose_mat(pose_result, slot)
            else
                error [[
                    "invalid slot, 'follow_flag' only 1/2/3 is valid
                    1: skip scale&rotation, base on parent
                    2: skip scale, base on parent
                    3: follow joint matrix. base on itself, it assume slot entity has 'pose_result' component"
                ]]
            end
            if slot_matrix then
                -- iom.set_srt_matrix(v, slot_matrix)
                iom.set_srt_offset_matrix(v, slot_matrix)
            end
        end
    end
end