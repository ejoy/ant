local ecs = ...
local w = ecs.world.w
local math3d = require "math3d"

local sys = ecs.system "slot_system"

local r2l_mat<const> = math3d.ref(math3d.matrix{s={1.0, 1.0, -1.0}})
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
function sys:update_slot()
	for v in w:select "scene:in follow_joint:in follow_flag:in follow_offset:in" do
        if v.follow_joint ~= "None" then
            for e in w:select "scene:in skeleton:in pose_result:in" do
                if e.scene.id == v.scene.parent then
                    local ske = e.skeleton._handle
                    local joint_idx = ske:joint_index(v.follow_joint)
                    local adjust_mat = math3d.mul(r2l_mat, e.pose_result:joint(joint_idx))
					local offset_mat = math3d.matrix {
						s = math3d.vector(v.follow_offset.s or {1,1,1}),
						r = math3d.quaternion(v.follow_offset.r or {0,0,0,1}),
						t = math3d.vector(v.follow_offset.t or {0,0,0})
					}
					adjust_mat = math3d.mul(adjust_mat, offset_mat)
                    local scale, rotate, pos = math3d.srt(adjust_mat)
                    -- if v.follow_flag == 1 then
                    --     scale, rotate, pos = math3d.ref(math3d.vector({1, 1, 1})), math3d.ref(math3d.quaternion({0,0,0,1})), math3d.ref(pos)
                    -- elseif v.follow_flag == 2 then
					-- 	scale, rotate, pos = math3d.ref(math3d.vector({1, 1, 1})), math3d.ref(rotate), math3d.ref(pos)
                    -- end
					-- v.scene.srt = {
					-- 	s = scale,
					-- 	r = rotate,
					-- 	t = pos
					-- }
					if v.follow_flag == 1 then
                        scale, rotate, pos = {1, 1, 1}, {0,0,0,1}, {math3d.index(pos, 1, 2, 3)}
                    elseif v.follow_flag == 2 then
						scale, rotate, pos = {1, 1, 1}, {math3d.index(rotate, 1, 2, 3, 4)}, {math3d.index(pos, 1, 2, 3)}
                    end
					iom.set_scale(v, scale)
					iom.set_rotation(v, rotate)
					iom.set_position(v, pos)
                    --v.scene.srt = math3d.ref(math3d.mul(adjust_mat, v.scene.srt))
                end
            end
        end
    end
end