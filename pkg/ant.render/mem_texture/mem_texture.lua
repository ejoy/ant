local ecs       = ...
local world     = ecs.world
local w         = world.w
local mt_sys   = ecs.system "mem_texture_system"
local ltask     = require "ltask"
local mtc       = ecs.require "ant.render|mem_texture.mem_texture_common"

function mt_sys:update_filter()
    mtc.copy_main_material()
end

function mt_sys:entity_init()
    mtc.get_camera_srt()
end

function mt_sys:data_changed()
    mtc.process_wait_queue()
end

local S = ltask.dispatch()

function mt_sys:init()
    mtc.register_new_rt()
end

function mt_sys:exit()
    mtc.clear_prefab_cache()
end

function S.get_portrait_handle(name, width, height)
    return mtc.get_portrait_handle(name, width, height)
end

function S.set_portrait_prefab(name, path, rotation, distance, type)
    mtc.create_prefab_entity(name, path, rotation, distance, type)
end

function S.parse_prefab_config(config)
    return mtc.parse_prefab_config(config)
end

function S.destroy_portrait_handle(handle)
    mtc.destroy_portrait_prefab(handle)
end

function S.render_portrait_prefab(name, prefab_rotation)
    mtc.add_wait_queue(name, prefab_rotation)
end