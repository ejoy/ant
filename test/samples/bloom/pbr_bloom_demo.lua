local ecs = ...
local world = ecs.world

local fs = require 'filesystem'
local math3d = import_package "ant.math"
local ms = math3d.stack

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
ecs.import 'ant.asset'
ecs.import "ant.image_effect"
--import_package  "ant.image_effect"

local renderpkg = import_package 'ant.render'
local renderutil=renderpkg.util
local computil = renderpkg.components
local aniutil = import_package 'ant.animation'.util
local timer = import_package "ant.timer"

local lu = renderpkg.light
local pbr_scene = require "pbr_scene"
local pbr_demo = ecs.system 'pbr_bloom_demo'

pbr_demo.depend 	'timesystem'
pbr_demo.depend 	"viewport_detect_system"
pbr_demo.depend 	'render_system'
pbr_demo.depend 	'primitive_filter_system'
pbr_demo.depend     'cull_system'
pbr_demo.depend     'asyn_asset_loader'

pbr_demo.dependby 	'camera_controller'


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
    do
        local rotation = to_radian({45,-90,0,0})
        lu.create_directional_light_entity(world, 'directional_light',{1,1,1,0}, 2, rotation )
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    pbr_scene.create_scene(world)

   -- computil.create_grid_entity(world, 'grid', 64, 64, 1)

end

function pbr_demo:update()

end 