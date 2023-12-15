local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local iom = ecs.require "ant.objcontroller|obj_motion"

local r2l_mat<const> = mc.R2L_MAT

local m = ecs.system "slot_system"

function m:entity_init()
    for e in w:select "INIT slot:in animation:in" do
        local slot = e.slot
        slot.joint_index = e.animation.skeleton:joint_index(slot.joint_name)
    end
end

function m:update_slot()
    for e in w:select "slot:in animation:in scene:update" do
        local slot = e.slot
        local follow_flag = slot.follow_flag
        local matrix = math3d.mul(r2l_mat, e.animation.models:joint(slot.joint_index))
        if follow_flag == 1 then
            matrix = math3d.set_index(mc.IDENTITY_MAT, 4, math3d.index(matrix, 4))
        elseif follow_flag == 2 then
            local _, r, t = math3d.srt(matrix)
            matrix = math3d.matrix{r=r, t=t}
        elseif follow_flag == 3 then
        else
            error [[
                "invalid slot, 'follow_flag' only 1/2/3 is valid
                1: skip scale&rotation, base on parent
                2: skip scale, base on parent
                3: follow joint matrix. base on itself, it assume slot entity has 'pose_result' component"
            ]]
        end
        iom.set_srt_offset_matrix(e, matrix)
    end
end
