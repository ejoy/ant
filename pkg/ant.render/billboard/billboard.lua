local ecs = ...
local world = ecs.world
local w = world.w

local bb_sys = ecs.system "billboard_system"

local math3d = require "math3d"

function bb_sys:camera_usage()
    for e in w:select "billboard render_object:update scene:update" do
        local mq = w:first("main_queue render_target:in camera_ref:in")
        local ce = world:entity(mq.camera_ref, "camera:in")
        local obj_world_nmat = math3d.set_index(math3d.inverse(ce.camera.viewmat), 4, math3d.index(e.scene.worldmat, 4))

        math3d.unmark(e.scene.worldmat)
        e.scene.worldmat=math3d.mark(obj_world_nmat)

        local ro=e.render_object
        ro.worldmat=e.scene.worldmat
    end
end