local ecs = ...
local world = ecs.world
local fs = require 'filesystem'
local math3d = import_package 'ant.math'
local ms = math3d.stack

ecs.import 'ant.render'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.event'
ecs.import 'ant.objcontroller'

local renderpkg = import_package 'ant.render'
local renderutil = renderpkg.util
local computil = renderpkg.components
local timer = import_package "ant.timer"

local lu = renderpkg.light

local sky_system = ecs.system "sky_system"

sky_system.dependby 'render_system'
sky_system.dependby 'primitive_filter_system'
sky_system.dependby 'camera_controller'
sky_system.depend 'timesystem'

function sky_system:init()
    renderutil.create_render_queue_entity(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 5, -5}, "main_view")
    do
        lu.create_directional_light_entity(world, 'directional_light')
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    computil.create_grid_entity(world, 'grid', 64, 64, 1)
    
end 