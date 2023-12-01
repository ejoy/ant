local ecs       = ...
local world     = ecs.world
local w         = world.w
local mts_sys   = ecs.system "mem_texture_static_system"
local ltask     = require "ltask"
local mtc       = ecs.require "ant.render|mem_texture.mem_texture_common"
local params    = mtc.params

function mts_sys:init()
    mtc.register_new_rt(params.MEM_TEXTURE_STATIC_VIEWID, params.STATIC_OBJ_NAME, params.STATIC_QUEUE_NAME)
end

function mts_sys:update_filter()
    mtc.copy_main_material(params.STATIC_OBJ_NAME, params.STATIC_QUEUE_NAME)
end

function mts_sys:entity_init()
    mtc.adjust_camera_srt(params.STATIC_OBJ_NAME, params.STATIC_QUEUE_NAME, true)
    for e in w:select "INIT clear_smt_prefab eid:in" do
        w:remove(e.eid) 
    end
end

function mts_sys:entity_remove()
    for e in w:select "REMOVED clear_smt_prefab" do
        mtc.recreate_framebuffer(params.STATIC_QUEUE_NAME)
    end
end

local S = ltask.dispatch()

function S.create_mem_texture_static_prefab(prefab_path, width, height, rotation, distance)
    return mtc.create_prefab(prefab_path, width, height, rotation, distance, params.STATIC_OBJ_NAME, params.STATIC_QUEUE_NAME)
end

