local ecs = ...
local w = ecs.world.w
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local r2l_mat<const> = math3d.ref(math3d.matrix{s={1.0, 1.0, -1.0}})
local sys = ecs.system "slot_system"
function sys:update_slot()
	for v in w:select "scene:in follow_joint:in follow_flag:in follow_offset:in" do
        if v.follow_joint ~= "None" then
            for e in w:select "scene:in skeleton:in pose_result:in" do
                if e.scene.id == v.scene.parent then
                    local ske = e.skeleton._handle
                    local joint_idx = ske:joint_index(v.follow_joint)
                    local adjust_mat = math3d.mul(r2l_mat, e.pose_result:joint(joint_idx))
                    local offset_mat = math3d.matrix(v.follow_offset)
                    adjust_mat = math3d.mul(adjust_mat, offset_mat)
                    local s, r, t
					if v.follow_flag == 1 then
                        s, r, t = mc.ONE, mc.IDENTITY_QUAT, math3d.index(adjust_mat, 4)
                    elseif v.follow_flag == 2 then
                        s, r, t = mc.ONE, math3d.index(adjust_mat, 3, 4)
                        r = math3d.torotation(r)
                    else
                        s, r, t = math3d.srt(adjust_mat)
                    end
                    iom.set_srt(v, s, r, t)
                end
            end
        end
    end
end