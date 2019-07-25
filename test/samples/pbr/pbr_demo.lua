local ecs = ...
local world = ecs.world

local fs = require 'filesystem'
local math3d = import_package "ant.math"
local ms = math3d.stack

ecs.import 'ant.basic_components'
ecs.import 'ant.render'
ecs.import 'ant.editor'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.event'
ecs.import 'ant.objcontroller'
ecs.import 'ant.math.adapter'

local renderpkg = import_package 'ant.render'
local renderutil=renderpkg.util
local computil = renderpkg.components
local aniutil = import_package 'ant.animation'.util
local timer = import_package "ant.timer"

local lu = renderpkg.light

local pbr_scene = require "pbr_scene"

local pbr_demo = ecs.system 'pbr_demo'

--pbr_demo.depend 'transparency_filter_system'
--pbr_demo.depend 'entity_rendering'
pbr_demo.dependby 'render_system'
pbr_demo.dependby 'primitive_filter_system'
pbr_demo.dependby 'camera_controller'
pbr_demo.depend 'timesystem'
--pbr_demo.depend 'math_adapter'

-- move it to common math utils
local function to_radian(angles)
    local function radian(angle)
        return (math.pi / 180) * angle
    end

    local radians = {}
    for i=1, #angles do
        radians[i] = radian(angles[i])
    end
    return radians
end

local function to_angle(rad)
    local function angle(rad)
        return (180/math.pi)*rad
    end 
    local angles = {}
    for i=1,#rad do 
        angles[i] = angle(rad[i])
    end 
    return angles
end 

function pbr_demo:init()
	renderutil.create_main_queue(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 25, 5})
    --renderutil.create_render_queue_entity(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 5, -5}, "main_view")
    do
        local rotation = to_radian({45,-90,0,0})
        lu.create_directional_light_entity(world, 'directional_light',{1,1,1,0}, 1, rotation )
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    pbr_scene.create_scene(world)

    computil.create_grid_entity(world, 'grid', 64, 64, 1)

end

function pbr_demo:update()

    -- local deltaTime =  timer.deltatime
    -- print("deltaTime",deltaTime)

	-- local camera_entity = world:first_entity("main_queue")
	-- local camera = camera_entity.camera

    -- local pos = ms(camera.eyepos,"T")
    -- print("camera :",string.format("%08.4f",pos[1]), string.format("%08.4f",pos[2]),string.format("%08.4f",pos[3]) )

end 