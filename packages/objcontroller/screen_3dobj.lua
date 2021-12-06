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

local mc_mb = world:sub{"main_queue", "camera_changed"}
local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local camera_mb
local dirty

function screen_3dobj_sys:entity_init()
    for e in w:select "INIT screen_3dobj:in render_object:in" do
        dirty = true
    end
end

function screen_3dobj_sys:init_world()
    camera_mb = world:sub{"scene_changed", irq.main_camera()}
end

function screen_3dobj_sys:data_changed()
    for _ in camera_mb:each() do
        dirty = true
    end

    for msg in mc_mb:each() do
        local c = msg[3]
        world:sub{"scene_changed", c}
        dirty = true
    end

    for _ in vr_mb:each() do
        dirty = true
    end
end

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
    if dirty then
        for e in w:select "screen_3dobj:in render_object:in" do
            local mcamera = irq.main_camera()
            w:sync("camera:in", mcamera)
            local vp = mcamera.camera.viewprojmat
            local vr = irq.view_rect "main_queue"

            local posScreen = calc_screen_pos(e.screen_3dobj, vr)
            local posNDC = iom.screen_to_ndc(posScreen, vr)
        
            local posWS = mu.ndc_to_world(vp, posNDC)
            w:sync("scene:in", e)
            local scene = e.scene
            assert(scene.parent == nil, "global_axes should not have any parent")
            local srt = scene.srt
            srt.t.v = posWS
            scene._worldmat = math3d.matrix(srt)
            w:sync("render_object:in", e)
            e.render_object.worldmat = scene._worldmat
        end

        dirty = nil
    end
end