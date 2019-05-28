local ecs = ...
local world = ecs.world

local Statics = require("statics")

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
ecs.import 'ant.animation'
ecs.import 'ant.event'
ecs.import 'ant.objcontroller'
ecs.import 'ant.math.adapter'

local renderpkg = import_package 'ant.render'
local renderutil=renderpkg.util
local computil = renderpkg.components
local aniutil = import_package 'ant.animation'.util
local timer = import_package "ant.timer"

local lu = renderpkg.light
 

local helpTool = require "helptool"
local unitySceneMaker = require "unitySceneMaker"

local scene_walker = ecs.system 'scene_walker'

--scene_walker.depend 'shadow_primitive_filter_system'
--scene_walker.depend 'transparency_filter_system'
scene_walker.dependby 'render_system'
scene_walker.depend 'primitive_filter_system'
scene_walker.dependby 'camera_controller'
scene_walker.depend 'timesystem'
--scene_walker.depend 'math_adapter'




function scene_walker:init()
    renderutil.create_render_queue_entity(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 350, 5}, "main_view")

    do
        local rotation = helpTool.to_radian({75,-75,0,0})
        lu.create_directional_light_entity(world, 'directional_light',{1,1,1,0}, 1, rotation )
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end
   
    -- allscene.lua 13500000
    -- spaceship_a_crashed.lua    90000
    -- spaceship_background_a.lua 10000
    -- fpsscene.lua 280000
    -- buildingc_scene.lua
    -- sample.lua
    unitySceneMaker.create(world,"//unity_demo/assets/scene/scene.lua") 

    --computil.create_grid_entity(world, 'grid', 64, 64, 1)

end

function scene_walker:update()

    -- local deltaTime =  timer.deltatime
    -- print("deltaTime",deltaTime)

	-- local camera_entity = world:first_entity("main_queue")
	-- local camera = camera_entity.camera

    -- local pos = ms(camera.eyepos,"T")
    -- print("camera :",string.format("%08.4f",pos[1]), string.format("%08.4f",pos[2]),string.format("%08.4f",pos[3]) )

    -- 注意屏蔽，简单统计测试函数，影响效率
    -- Statics.reset()
    -- Statics.collect(world)
    -- Statics.print()

end 