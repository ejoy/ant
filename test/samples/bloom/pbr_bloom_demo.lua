local ecs = ...
local world = ecs.world

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

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

local renderpkg = import_package 'ant.render'
local lu        = renderpkg.light
local pbr_scene = require "pbr_scene"

local pbr_demo  = ecs.system 'pbr_bloom_demo'

pbr_demo.depend 'timesystem'
pbr_demo.depend "viewport_detect_system"
pbr_demo.depend 'render_system'
pbr_demo.depend 'primitive_filter_system'
pbr_demo.depend 'cull_system'
pbr_demo.depend  'asyn_asset_loader'

pbr_demo.dependby 	'camera_controller'

function pbr_demo:init()
    do
        local rotation = mu.to_radian({45,-90,0,0})
        lu.create_directional_light_entity(world, 'directional_light',{1,1,1,0}, 2, rotation )
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    pbr_scene.create_scene(world)

end