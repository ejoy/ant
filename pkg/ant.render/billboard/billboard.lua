--[[ local ecs = ...
local world = ecs.world
local w = world.w

local bb_sys = ecs.system "billboard_system"

local math3d = require "math3d"

function bb_sys:camera_usage()
    for e in w:select "billboard render_object:update scene:update" do

        local mq = w:first("main_queue render_target:in camera_ref:in")
        local ce = world:entity(mq.camera_ref, "camera:in")
        local camera_world_mat=math3d.inverse(ce.camera.viewmat)
        local right=math3d.index(camera_world_mat,1)
        local up=math3d.index(camera_world_mat,2)
        local dir=math3d.index(camera_world_mat,3)
        local obj_t=e.scene.t
         local obj_world_nmat=math3d.matrix{
            math3d.index(right,1),math3d.index(right,2),math3d.index(right,3),math3d.index(right,4),
            math3d.index(up,1),math3d.index(up,2),math3d.index(up,3),math3d.index(up,4),
            math3d.index(dir,1),math3d.index(dir,2),math3d.index(dir,3),math3d.index(dir,4),
            math3d.index(obj_t,1),math3d.index(obj_t,2),math3d.index(obj_t,3),math3d.index(obj_t,4),
        } 

        math3d.unmark(e.scene.worldmat)
        e.scene.worldmat=math3d.mark(obj_world_nmat)

        local ro=e.render_object
        ro.worldmat=e.scene.worldmat
    end
end ]]