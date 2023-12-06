local ecs       = ...
local world     = ecs.world
local w         = world.w
local mt_sys   = ecs.system "mem_texture_system"
local ltask     = require "ltask"
local itimer	= ecs.require "ant.timer|timer_system"
local mtc       = ecs.require "ant.render|mem_texture.mem_texture_common"

function mt_sys:update_filter()
    mtc.copy_main_material()
end

function mt_sys:entity_init()
    mtc.adjust_camera_srt()
end

local timepassed = 0.0
local delta_radian = math.pi * 0.1

function mt_sys:data_changed()
    timepassed = timepassed + itimer.delta()
    local cur_time = timepassed * 0.001
    local cur_radian = delta_radian * cur_time
    mtc.adjust_prefab_rot("dynamic", cur_radian)
end

local S = ltask.dispatch()

function mt_sys:init()
    mtc.register_new_rt()
end

function mt_sys:exit()
    mtc.remove_portrait_queue()
end

function S.get_portrait_handle(width, height, type)
    mtc.resize_framebuffer(type, width, height)
    return mtc.get_portrait_handle(type)
end

function S.set_portrait_prefab(path, rotation, distance, type)
    mtc.set_prefab(type, path)
    mtc.adjust_camera_rotation(type, rotation)
    mtc.set_camera_distance_factor(type, distance) 
end

function S.parse_prefab_config(config)
    return mtc.parse_prefab_config(config)
end

function S.update_portrait_prefab(name)
    local path, type, _, rot, dis = mtc.parse_prefab_name(name)
    return S.set_portrait_prefab(path, rot, dis, type)
end
