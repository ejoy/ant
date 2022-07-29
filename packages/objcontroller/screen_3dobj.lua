local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local ecs_intrf = ecs.import.interface

local irq = ecs_intrf "ant.render|irenderqueue"
local iom = ecs_intrf "ant.objcontroller|iobj_motion"

local math3d = require "math3d"

local screen_3dobj_sys = ecs.system "screen_3dobj_system"

local function calc_screen_pos(screen_3dobj, vr)
    local sp = screen_3dobj.screen_pos
    local sx, sy
    if screen_3dobj.type == "percent" then
        sx = vr.x+sp[1] * vr.w
        sy = vr.y+sp[2] * vr.h
    else
        sx, sy = sp[1], sp[2]
    end
    return {sx, sy, 0.5}
end

function screen_3dobj_sys:camera_usage()
    if w:singleton "scene_changed" then
        local mq = w:singleton("main_queue", "camera_ref:in")
        local ce = world:entity(mq.camera_ref)
        if ce.scene_changed then
            local camera = ce.camera
            for e in w:select "screen_3dobj:in render_object:update id:in scene:update" do
                local vp = camera.viewprojmat
                local vr = irq.view_rect "main_queue"
    
                local posScreen = calc_screen_pos(e.screen_3dobj, vr)
                local posNDC = iom.screen_to_ndc(posScreen, vr)
            
                local posWS = mu.ndc_to_world(vp, posNDC)
                local scene = e.scene
                assert(scene.parent == 0, "global_axes should not have any parent")
                iom.set_position(e, posWS)
                math3d.unmark(scene.worldmat)
                scene.worldmat = math3d.mark(math3d.matrix(scene))
                e.render_object.worldmat = scene.worldmat
            end
        end
    end
end