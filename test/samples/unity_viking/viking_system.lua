local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local renderpkg = import_package 'ant.render'
local lu = renderpkg.light

local serialize = import_package "ant.serialize"

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
ecs.import 'ant.sky'
ecs.import 'ant.asset'
ecs.import "ant.image_effect"
--ecs.import "ant.camera_controller"

local fs = require "filesystem"
local vikingmap = fs.path "/pkg/unity_viking/Assets/viking.map"

local scene_walker = ecs.system 'scene_walker'

scene_walker.depend 	'timesystem'
scene_walker.depend 	"viewport_detect_system"
scene_walker.depend 	'render_system'
scene_walker.depend 	'primitive_filter_system'
scene_walker.depend     'procedural_sky_system'
scene_walker.depend     'cull_system'
scene_walker.depend     'asyn_asset_loader'
scene_walker.depend     'scene_space'
scene_walker.depend     'shadow_maker'
scene_walker.depend     'camera_controller'
scene_walker.depend     'steering_system'
--scene_walker.dependby 	'camera_controller_2'

local function load_world(mappath)
    if fs.exists(mappath) then
        local f = fs.open(mappath, "r")
        local c = f:read "a"
        f:close()
        serialize.load_world(world, c)
    else
        error("viking map not exist:" .. mappath:string())
    end
end

function scene_walker:init()
    do
        lu.create_directional_light_entity(world, 'directional_light', 
            {1,0.81,0.67,0}, 1.8, mu.to_radian {-220,-235,0,0})
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    load_world(vikingmap)
end